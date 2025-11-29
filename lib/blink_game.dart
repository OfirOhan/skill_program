// lib/blink_game.dart
import 'dart:async';
import 'dart:math';
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
      } else {
        falseAlarms++;
        currentStreak = 0;
        _flashFeedback(Colors.red.withOpacity(0.3));
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

  // --- GRADING LOGIC (Mapped to your 10 Skills) ---
  Map<String, double> _calculateScores() {
    int totalTrials = seq.length;
    if (totalTrials == 0) return {};

    int totalTargets = hits + misses;
    int nonTargets = totalTrials - totalTargets;

    // Base Metrics
    double precision = hits / max(1, hits + falseAlarms);
    double recall = hits / max(1, totalTargets);
    double f1Score = (2 * precision * recall) / max(0.001, precision + recall);

    // RT Metrics
    hitReactionTimes.sort();
    double medianRt = hitReactionTimes.isEmpty ? 1000 : hitReactionTimes[hitReactionTimes.length ~/ 2].toDouble();
    double speedScore = (1.0 - ((medianRt - 400) / 800)).clamp(0.0, 1.0); // 400ms=1.0, 1200ms=0.0

    // Attention Span (Decay check)
    double firstHalfAcc = firstHalfTrials == 0 ? 0 : firstHalfHits / max(1, firstHalfTrials);
    double secondHalfAcc = secondHalfTrials == 0 ? 0 : secondHalfHits / max(1, secondHalfTrials);
    double decayScore = (secondHalfAcc / max(0.1, firstHalfAcc)).clamp(0.0, 1.0);
    if (firstHalfAcc == 0 && secondHalfAcc > 0) decayScore = 1.0; // Started bad, got better

    // False Alarm Rate
    double falseAlarmRate = falseAlarms / max(1, nonTargets);

    return {
      "Working Memory": f1Score,
      "Short-Term Memory": f1Score * 0.95, // Highly correlated
      "Information Processing Speed": speedScore,
      "Selective Attention": (1.0 - falseAlarmRate).clamp(0.0, 1.0),
      "Sustained Attention": (maxStreak / max(5, totalTrials / 2)).clamp(0.0, 1.0),
      "Attention Span": decayScore,
      "Multi-tasking Ability": f1Score * speedScore, // Ability to process Position+Color fast
      "Pattern Recognition": precision, // Ability to recognize the 'Match' pattern correctly
      "Reaction Time": speedScore, // Raw speed metric
      "Visual Perception Accuracy": (1.0 - (falseAlarms / max(1, totalTrials))).clamp(0.0, 1.0), // Precision of visual discrimination
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("1. Blink & Match"),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
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
                  onPressed: () => Navigator.of(context).pop(_calculateScores()),
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