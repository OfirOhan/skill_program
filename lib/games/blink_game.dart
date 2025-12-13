// lib/blink_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class BlinkMatchWidget extends StatefulWidget {
  final int nBack;
  final int durationSeconds;

  const BlinkMatchWidget({
    this.nBack = 2,
    this.durationSeconds = 25, // Updated to 25s per new spec
    Key? key
  }) : super(key: key);

  @override
  _BlinkMatchWidgetState createState() => _BlinkMatchWidgetState();
}

class _BlinkMatchWidgetState extends State<BlinkMatchWidget> {
  final rand = Random();
  final List<_Stim> seq = [];
  Timer? _timer;
  bool running = false;
  bool isGameOver = false;

  // Game Elements
  int? currentCell;
  Color currentColor = Colors.blue;

  // Metrics for Grading
  int hits = 0;
  int misses = 0;
  int falseAlarms = 0;
  List<int> hitReactionTimes = [];
  int currentStreak = 0;
  int maxStreak = 0;

  // For Attention Span (Splitting performance)
  int firstHalfHits = 0;
  int firstHalfTrials = 0;
  int secondHalfHits = 0;
  int secondHalfTrials = 0;

  // Internal State
  int lastStimTime = 0;
  int startTime = 0;
  Color? feedbackOverlay;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    running = true;
    lastStimTime = DateTime.now().millisecondsSinceEpoch;
    startTime = lastStimTime;

    // Stimulus interval: 1200ms
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
      if (t.tick > widget.durationSeconds * 1000 ~/ 1200) {
        _finishGame();
        return;
      }
      _nextTurn();
    });
  }

  void _nextTurn() {
    // 1. Check for Misses (if previous was a match and user did nothing)
    if (seq.isNotEmpty) {
      final prevStim = seq.last;
      bool wasMatch = _isMatch(seq.length - 1);

      // Track splits for Attention Span calculation
      bool isFirstHalf = (DateTime.now().millisecondsSinceEpoch - startTime) < (widget.durationSeconds * 500);
      if (isFirstHalf) firstHalfTrials++; else secondHalfTrials++;

      if (wasMatch && !prevStim.userClaimed) {
        misses++;
        currentStreak = 0;
        _flashFeedback(Colors.orange.withOpacity(0.2));
        HapticFeedback.vibrate(); // Missed match
      }
    }

    // 2. Generate Next Stimulus
    // Force match ~35% of the time
    bool forceMatch = (seq.length >= widget.nBack) && (rand.nextDouble() < 0.35);
    int nextCell;
    Color nextColor;

    if (forceMatch) {
      final target = seq[seq.length - widget.nBack];
      nextCell = target.cell;
      nextColor = target.color;
    } else {
      nextCell = rand.nextInt(9);
      nextColor = rand.nextBool() ? Colors.blue : Colors.redAccent;
    }

    seq.add(_Stim(nextCell, nextColor));

    setState(() {
      currentCell = nextCell;
      currentColor = nextColor;
      lastStimTime = DateTime.now().millisecondsSinceEpoch;
    });

    // Blink effect (hide after 800ms)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && running) setState(() => currentCell = null);
    });
  }

  bool _isMatch(int index) {
    if (index < widget.nBack) return false;
    final current = seq[index];
    final target = seq[index - widget.nBack];
    // Dual Stream: Must match Position AND Color
    return current.cell == target.cell && current.color == target.color;
  }

  void _handleInput() {
    HapticFeedback.lightImpact(); // Input feedback
    if (!running || isGameOver || seq.isEmpty) return;

    final currentIndex = seq.length - 1;
    final currentStim = seq[currentIndex];

    if (currentStim.userClaimed) return;
    currentStim.userClaimed = true;

    final rt = DateTime.now().millisecondsSinceEpoch - lastStimTime;
    bool isTarget = _isMatch(currentIndex);

    bool isFirstHalf = (DateTime.now().millisecondsSinceEpoch - startTime) < (widget.durationSeconds * 500);

    setState(() {
      if (isTarget) {
        hits++;
        hitReactionTimes.add(rt);
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;

        if (isFirstHalf) firstHalfHits++; else secondHalfHits++;

        _flashFeedback(Colors.green.withOpacity(0.3));
        HapticFeedback.mediumImpact(); // Correct match
      } else {
        falseAlarms++;
        currentStreak = 0;
        _flashFeedback(Colors.red.withOpacity(0.3));
        HapticFeedback.heavyImpact(); // Wrong match
      }
    });
  }

  void _flashFeedback(Color color) {
    setState(() => feedbackOverlay = color);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => feedbackOverlay = null);
    });
  }

  void _finishGame() {
    _timer?.cancel();
    setState(() {
      running = false;
      isGameOver = true;
    });
  }

  Map<String, double> grade() {
    final int totalTrials = seq.length;
    if (totalTrials < widget.nBack) {
      return {
        "Working Memory": 0.0,
        "Associative Memory": 0.0,
        "Response Inhibition": 0.0,
        "Information Processing Speed": 0.0,
        "Observation / Vigilance": 0.0,
      };
    }

    int totalTargets = hits + misses;                 // match trials
    int totalDistractors = totalTrials - totalTargets; // non-match trials

    // Avoid divide-by-zero (no imputation: if a class truly doesn't exist, score becomes 0)
    if (totalTargets <= 0) totalTargets = 0;
    if (totalDistractors <= 0) totalDistractors = 0;

    // --- Accuracy components ---
    // Precision: when you claim match, how often correct?
    final double precision = (hits + falseAlarms) == 0 ? 0.0 : (hits / (hits + falseAlarms));

    // Recall/Sensitivity: out of true matches, how many caught?
    final double recall = totalTargets == 0 ? 0.0 : (hits / totalTargets);

    // Specificity/Inhibition: out of non-matches, how many correctly ignored?
    final double inhibition = totalDistractors == 0 ? 0.0 : ((totalDistractors - falseAlarms) / totalDistractors);

    // Working memory: balanced “hit targets without hallucinating”
    final double f1 = (precision + recall) == 0 ? 0.0 : (2 * precision * recall) / (precision + recall);

    // Associative binding (pos+color): balanced accuracy handles class imbalance
    final double assoc = ((recall + inhibition) / 2).clamp(0.0, 1.0);

    // --- Vigilance / stability over time (only if both halves have evidence) ---
    final double firstHalfAcc = firstHalfTrials == 0 ? 0.0 : (firstHalfHits / firstHalfTrials);
    final double secondHalfAcc = secondHalfTrials == 0 ? 0.0 : (secondHalfHits / secondHalfTrials);

    double vigilance = 0.0;
    if (firstHalfTrials > 0 && secondHalfTrials > 0) {
      vigilance = (1.0 - (firstHalfAcc - secondHalfAcc).abs()).clamp(0.0, 1.0);
    } else {
      vigilance = 0.0; // no evidence to claim stability
    }

    // --- Speed (earned: gated by accuracy) ---
    final double avgMs = hitReactionTimes.isEmpty
        ? 1000.0
        : hitReactionTimes.reduce((a, b) => a + b) / hitReactionTimes.length;

    // 350ms fast .. 1000ms slow
    final double rawSpeed = (1.0 - ((avgMs - 350.0) / 650.0)).clamp(0.0, 1.0);

    // Gate speed by correctness: fast but wrong should not score high
    final double speed = (rawSpeed * f1).clamp(0.0, 1.0);

    return {
      "Working Memory": f1.clamp(0.0, 1.0),
      "Associative Memory": assoc,
      "Response Inhibition": inhibition.clamp(0.0, 1.0),
      "Information Processing Speed": speed,
      "Observation / Vigilance": vigilance,
    };
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("1. Blink & Match"),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () {
             HapticFeedback.lightImpact(); 
             Navigator.of(context).pop(null);
          }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
      body: Stack(
        children: [
          if (feedbackOverlay != null) Positioned.fill(child: Container(color: feedbackOverlay)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Tap MATCH if the Square AND Color\nare the same as 2 steps ago.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
              Center(
                child: SizedBox(
                  width: 300, height: 300,
                  child: GridView.count(
                    crossAxisCount: 3, padding: const EdgeInsets.all(10), crossAxisSpacing: 8, mainAxisSpacing: 8,
                    children: List.generate(9, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(
                          color: i == currentCell ? currentColor : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12)
                      ),
                    )),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (!isGameOver)
                ElevatedButton(
                  onPressed: _handleInput,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20)
                  ),
                  child: const Text("MATCH!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (isGameOver)
            Container(
              color: Colors.black87,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () { 
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(grade());
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("NEXT GAME"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stim {
  final int cell;
  final Color color;
  bool userClaimed = false;
  _Stim(this.cell, this.color);
}