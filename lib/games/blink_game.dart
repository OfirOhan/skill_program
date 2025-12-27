// lib/blink_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../grading/blink_grading.dart';

class BlinkMatchWidget extends StatefulWidget {
  final int nBack;
  final int durationSeconds;

  const BlinkMatchWidget({
    this.nBack = 2,
    this.durationSeconds = 25,
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

  // Fairness Logic
  List<bool> _targetPlan = [];
  int _turnIndex = 0;

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
    _turnIndex = 0;
    seq.clear();

    // 1. Calculate Total Turns based on Duration
    // Interval is 1200ms
    int totalTurns = (widget.durationSeconds * 1000) ~/ 1200;

    // 2. Calculate how many "playable" turns we have
    // (We can't have matches in the first nBack turns)
    int playableTurns = totalTurns - widget.nBack;
    if (playableTurns < 0) playableTurns = 0;

    // 3. Determine exact number of Targets (35%)
    int targetCount = (playableTurns * 0.35).ceil();
    int distractorCount = playableTurns - targetCount;

    // 4. Build the "Fair Deck"
    _targetPlan = List<bool>.filled(targetCount, true) +
        List<bool>.filled(distractorCount, false);
    _targetPlan.shuffle(rand);

    // Stimulus interval: 1200ms
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
      if (_turnIndex >= totalTurns) {
        _finishGame();
        return;
      }
      _nextTurn();
    });

    // Trigger first turn immediately
    _nextTurn();
  }

  void _nextTurn() {
    // 1. Check for Misses from PREVIOUS turn
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
        HapticFeedback.vibrate();
      }
    }

    // 2. Generate Next Stimulus based on THE PLAN
    int nextCell;
    Color nextColor;

    if (seq.length < widget.nBack) {
      // Setup Phase: Just random, cannot be a match yet
      nextCell = rand.nextInt(9);
      nextColor = rand.nextBool() ? Colors.blue : Colors.redAccent;
    } else {
      // Play Phase: Follow the shuffled plan
      // We look at _targetPlan index [seq.length - nBack]
      int planIndex = seq.length - widget.nBack;

      // Safety check if time runs slightly over
      bool forceMatch = (planIndex < _targetPlan.length) && _targetPlan[planIndex];

      if (forceMatch) {
        // FORCE MATCH: Copy the n-back stimulus
        final target = seq[seq.length - widget.nBack];
        nextCell = target.cell;
        nextColor = target.color;
      } else {
        // FORCE DISTRACTOR: Ensure it does NOT match
        final target = seq[seq.length - widget.nBack];
        do {
          nextCell = rand.nextInt(9);
          nextColor = rand.nextBool() ? Colors.blue : Colors.redAccent;
        } while (nextCell == target.cell && nextColor == target.color);
      }
    }

    seq.add(_Stim(nextCell, nextColor));
    _turnIndex++;

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
    HapticFeedback.lightImpact();
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
        HapticFeedback.mediumImpact();
      } else {
        falseAlarms++;
        currentStreak = 0;
        _flashFeedback(Colors.red.withOpacity(0.3));
        HapticFeedback.heavyImpact();
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

  // --- GRADING (Updated with Metric Purity Logic) ---
  Map<String, double> grade() {
    final int totalTrials = seq.length;

    // 1. Safety Check (Not enough data)
    if (totalTrials < widget.nBack + 1) {
      return gradeBlinkFromStats(
        isTarget: [],
        userClaimed: [],
        hitReactionTimesMs: [],
      );
    }

    // 2. Prepare Raw Data
    final List<bool> isTargetList = List.generate(totalTrials, (i) => _isMatch(i));
    final List<bool> userClaimedList = seq.map((s) => s.userClaimed).toList();

    // 3. Delegate to The Brain (blink_grading.dart)
    final scores = gradeBlinkFromStats(
      isTarget: isTargetList,
      userClaimed: userClaimedList,
      hitReactionTimesMs: hitReactionTimes,
    );

    // Optional: Print to console for debugging
    print("Scores Calculated: $scores");

    return scores;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blink & Match"), backgroundColor: Colors.transparent, foregroundColor: const Color(0xFF2D3436), elevation: 0, centerTitle: true),
      body: Stack(
        children: [
          if (feedbackOverlay != null) Positioned.fill(child: Container(color: feedbackOverlay)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text("Tap MATCH if the Square AND Color\nare the same as 2 steps ago.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey))),
              Center(
                child: SizedBox(
                  width: 300, height: 300,
                  child: GridView.count(
                    crossAxisCount: 3, padding: const EdgeInsets.all(10), crossAxisSpacing: 8, mainAxisSpacing: 8,
                    children: List.generate(9, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(color: i == currentCell ? currentColor : Colors.grey[200], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                    )),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (!isGameOver)
                ElevatedButton(
                  onPressed: _handleInput,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20)),
                  child: const Text("MATCH!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (isGameOver)
            Container(color: Colors.black87, child: Center(child: ElevatedButton.icon(onPressed: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(grade()); }, icon: const Icon(Icons.arrow_forward), label: const Text("NEXT GAME"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20))))),
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