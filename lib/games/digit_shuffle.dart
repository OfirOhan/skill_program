// lib/digit_shuffle.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../grading/digit_shuffle_grading.dart';

class DigitShuffleWidget extends StatefulWidget {
  const DigitShuffleWidget({Key? key}) : super(key: key);

  @override
  _DigitShuffleWidgetState createState() => _DigitShuffleWidgetState();
}

class _DigitShuffleWidgetState extends State<DigitShuffleWidget> {
  final rand = Random();
  List<int> _preGeneratedTaskTypes = []; // NEW: Pre-generated task types

  // Game State
  List<int> sequence = [];
  List<int> expected = [];
  List<int> userAnswer = [];

  bool isMemorizing = true;
  String instruction = "";

  // Round Config
  static const int totalRounds = 5;
  int roundsPlayed = 0;

  // Per-Round Timer
  Timer? _roundTimer;
  Timer? _memoTimer;
  int roundSeconds = 15;
  int startInputMs = 0;

  // --- METRICS (Partial Credit) ---
  double sumRecallAccuracy = 0.0;
  double sumProcessAccuracy = 0.0;
  double sumMathAccuracy = 0.0;
  double sumTotalAccuracy = 0.0;
  int totalProcessTime = 0;

  // Skill tracking (Denominators)
  int recallTrials = 0;
  int processTrials = 0;
  int mathTrials = 0;

  int currentTaskType = 0; // 0=Recall, 1=Sort, 2=Add
  int currentAddVal = 0;

  final List<int> roundTaskTypes = [];
  final List<int> roundTimesMs = [];
  final List<double> roundAccuracies = [];

  @override
  void initState() {
    super.initState();
    _generateTaskSequence(); // NEW: Pre-generate all task types
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _memoTimer?.cancel();
    super.dispose();
  }

  // NEW: Pre-generate task types with guaranteed coverage
  void _generateTaskSequence() {
    // Round 0 is ALWAYS Recall (task type 0)
    _preGeneratedTaskTypes = [0];

    // Rounds 1-4: Must contain at least one Sort (1) and one Add (2)
    final remainingTasks = <int>[1, 2]; // Guarantee at least one Sort and one Add

    // Fill remaining slots with random tasks (0,1,2)
    while (remainingTasks.length < 4) {
      remainingTasks.add(rand.nextInt(3));
    }

    // Shuffle the remaining tasks
    remainingTasks.shuffle(rand);
    _preGeneratedTaskTypes.addAll(remainingTasks);

    // Final sequence has 5 rounds: [0, ...4 shuffled tasks with at least one 1 and one 2]
    assert(_preGeneratedTaskTypes.length == 5);
    assert(_preGeneratedTaskTypes[0] == 0);
    assert(_preGeneratedTaskTypes.contains(1)); // At least one Sort
    assert(_preGeneratedTaskTypes.contains(2)); // At least one Add
  }

  void _startRoundTimer() {
    roundSeconds = 15;
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => roundSeconds--);
      if (roundSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _startRound() {
    // Game Over Check -> Immediate Exit
    if (roundsPlayed >= totalRounds) {
      _roundTimer?.cancel();
      _memoTimer?.cancel();
      // Return the grade immediately without a summary screen
      Navigator.of(context).pop(grade());
      return;
    }

    int count = 5 + (roundsPlayed >= 2 ? 1 : 0) + (roundsPlayed >= 4 ? 1 : 0);

    // FIXED: Use pre-generated task type
    final taskType = _preGeneratedTaskTypes[roundsPlayed];

    int addVal = 0;
    if (taskType == 2) addVal = rand.nextInt(3) + 1;

    currentTaskType = taskType;
    currentAddVal = addVal;

    setState(() {
      isMemorizing = true;
      userAnswer = [];
      sequence = List.generate(count, (_) => rand.nextInt(10 - addVal));
    });

    _memoTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;

      setState(() {
        isMemorizing = false;
        startInputMs = DateTime.now().millisecondsSinceEpoch;

        if (taskType == 0) {
          instruction = "Recall Sequence";
          expected = List.from(sequence);
          recallTrials++;
        } else if (taskType == 1) {
          instruction = "Sort: Low to High";
          expected = List.from(sequence)..sort();
          processTrials++;
        } else {
          instruction = "Add $addVal to each!";
          expected = sequence.map((e) => e + addVal).toList();
          processTrials++;
          mathTrials++;
        }
      });

      _startRoundTimer();
    });
  }

  void onKeyTap(String value) {
    if (isMemorizing) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (value == "DEL") {
        HapticFeedback.mediumImpact();
        if (userAnswer.isNotEmpty) userAnswer.removeLast();
      } else if (value == "GO") {
        HapticFeedback.mediumImpact();
        _submitAnswer();
      } else {
        if (userAnswer.length < expected.length) {
          userAnswer.add(int.parse(value));
        }
      }
    });
  }

  void _handleTimeout() {
    _roundTimer?.cancel();
    _processResult();
  }

  void _submitAnswer() {
    _roundTimer?.cancel();
    _processResult();
  }

  void _processResult() {
    // 1. Calculate Accuracy (Partial Credit)
    int matches = 0;
    int len = expected.length;

    // Compare digit by digit up to the shortest length
    int checkLen = userAnswer.length < len ? userAnswer.length : len;
    for (int i = 0; i < checkLen; i++) {
      if (userAnswer[i] == expected[i]) {
        matches++;
      }
    }

    // Calculate 0.0 - 1.0 score for this specific round
    double roundAccuracy = len == 0 ? 0.0 : matches / len;

    // 2. Record Stats
    final rt = DateTime.now().millisecondsSinceEpoch - startInputMs;
    totalProcessTime += rt;

    roundTaskTypes.add(currentTaskType);
    roundTimesMs.add(rt.clamp(0, 15000)); // bounded by the round limit; no free speed artifacts
    roundAccuracies.add(roundAccuracy);

    if (instruction.contains("Recall")) {
      sumRecallAccuracy += roundAccuracy;
    } else {
      sumProcessAccuracy += roundAccuracy;
    }

    if (instruction.contains("Add")) {
      sumMathAccuracy += roundAccuracy;
    }

    sumTotalAccuracy += roundAccuracy;

    // 3. IMMEDIATE NEXT ROUND (No feedback delay)
    roundsPlayed++;
    _startRound();
  }

  Map<String, double> grade() {
    return DigitShuffleGrading.grade(
      roundAccuracies: roundAccuracies,
      roundTimesMs: roundTimesMs,
      roundTaskTypes: roundTaskTypes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Digit Shuffle"),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!isMemorizing)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Text(
                    "$roundSeconds s",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: roundSeconds <= 5 ? Colors.red : Colors.indigo)
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // --- DISPLAY AREA ---
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: Colors.grey[50],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isMemorizing) ...[
                    const Text("MEMORIZE", style: TextStyle(color: Colors.grey, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text(
                        sequence.join(' '),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black87)
                    ),
                  ] else ...[
                    Text(
                        instruction,
                        style: const TextStyle(fontSize: 24, color: Colors.indigo, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 30),
                    Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[400]!, width: 2))
                      ),
                      alignment: Alignment.center,
                      child: Text(
                          userAnswer.join(' '),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 4)
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),

          // --- KEYPAD ---
          if (!isMemorizing)
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKey("1"), _buildKey("2"), _buildKey("3"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKey("4"), _buildKey("5"), _buildKey("6"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKey("7"), _buildKey("8"), _buildKey("9"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildActionKey("DEL", Colors.red[50]!, Colors.red),
                          _buildKey("0"),
                          _buildActionKey("GO", Colors.green[50]!, Colors.green),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKey(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: () => onKeyTap(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, Color bg, Color text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: () => onKeyTap(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: text,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}