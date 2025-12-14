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
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    final int totalTrials = seq.length;
    if (totalTrials < widget.nBack + 1) {
      return {
        "Working Memory": 0.0,
        "Response Inhibition": 0.0,
        "Reaction Time (Choice)": 0.0,
        "Observation / Vigilance": 0.0,
      };
    }

    // ---- Recompute outcomes from direct behavioral evidence ----
    int targets = 0, distractors = 0;
    int nHits = 0, nMisses = 0, nFalseAlarms = 0, nCorrectRejections = 0;

    for (int i = 0; i < totalTrials; i++) {
      final bool isTarget = _isMatch(i);
      final bool claimed = seq[i].userClaimed;

      if (isTarget) {
        targets++;
        if (claimed) {
          nHits++;
        } else {
          nMisses++;
        }
      } else {
        distractors++;
        if (claimed) {
          nFalseAlarms++;
        } else {
          nCorrectRejections++;
        }
      }
    }

    // If a class is missing, we cannot defensibly score discrimination components.
    if (targets == 0 || distractors == 0) {
      return {
        "Working Memory": 0.0,
        "Response Inhibition": 0.0,
        "Reaction Time (Choice)": 0.0,
        "Observation / Vigilance": 0.0,
      };
    }

    // ---- Intermediate metrics (transparent) ----
    final double hitRate = nHits / targets;
    final double specificity = nCorrectRejections / distractors;
    final double falseAlarmRate = nFalseAlarms / distractors;

    final double balancedAcc = (hitRate + specificity) / 2.0;

    // ---- Skill scores ----

    // Working Memory: catch n-back targets, gated by not mashing (specificity).
    final double workingMemory = clamp01(hitRate * specificity);

    // Response Inhibition: resist pressing on non-targets (false alarms are direct failures).
    final double responseInhibition = clamp01(1.0 - falseAlarmRate);

    // Observation / Vigilance: stable discrimination quality across time, gated by competence.
    double observationVigilance = 0.0;
    {
      final int split = totalTrials ~/ 2;

      int t1 = 0, d1 = 0, h1 = 0, cr1 = 0;
      int t2 = 0, d2 = 0, h2 = 0, cr2 = 0;

      for (int i = 0; i < totalTrials; i++) {
        final bool isTarget = _isMatch(i);
        final bool claimed = seq[i].userClaimed;
        final bool firstHalf = i < split;

        if (firstHalf) {
          if (isTarget) { t1++; if (claimed) h1++; }
          else { d1++; if (!claimed) cr1++; }
        } else {
          if (isTarget) { t2++; if (claimed) h2++; }
          else { d2++; if (!claimed) cr2++; }
        }
      }

      // Need evidence in BOTH halves; otherwise no vigilance claim.
      if (t1 > 0 && d1 > 0 && t2 > 0 && d2 > 0) {
        final double ba1 = ((h1 / t1) + (cr1 / d1)) / 2.0;
        final double ba2 = ((h2 / t2) + (cr2 / d2)) / 2.0;

        final double stability = clamp01(1.0 - (ba1 - ba2).abs());
        observationVigilance = clamp01(stability * balancedAcc);
      } else {
        observationVigilance = 0.0;
      }
    }

    // Reaction Time (Choice): median RT on correct “match” decisions, gated by discrimination quality.
    double reactionTimeChoice = 0.0;
    {
      if (hitReactionTimes.length >= 3 && balancedAcc > 0.0) {
        final sorted = List<int>.from(hitReactionTimes)..sort();
        final int mid = sorted.length ~/ 2;
        final double medianMs = (sorted.length.isOdd)
            ? sorted[mid].toDouble()
            : ((sorted[mid - 1] + sorted[mid]) / 2.0);

        const double bestMs = 250.0;
        const double worstMs = 1200.0; // matches the stimulus interval scale
        final double raw = clamp01(1.0 - ((medianMs - bestMs) / (worstMs - bestMs)));

        reactionTimeChoice = clamp01(raw * balancedAcc);
      } else {
        reactionTimeChoice = 0.0;
      }
    }

    return {
      "Working Memory": workingMemory,
      "Response Inhibition": responseInhibition,
      "Reaction Time (Choice)": reactionTimeChoice,
      "Observation / Vigilance": observationVigilance,
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