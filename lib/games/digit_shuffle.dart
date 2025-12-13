// lib/digit_shuffle.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DigitShuffleWidget extends StatefulWidget {
  const DigitShuffleWidget({Key? key}) : super(key: key);

  @override
  _DigitShuffleWidgetState createState() => _DigitShuffleWidgetState();
}

class _DigitShuffleWidgetState extends State<DigitShuffleWidget> {
  final rand = Random();

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

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _memoTimer?.cancel();
    super.dispose();
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

    int taskType = 0;
    if (roundsPlayed == 0) taskType = 0;
    else taskType = rand.nextInt(3);

    int addVal = 0;
    if (taskType == 2) addVal = rand.nextInt(3) + 1;

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
    if (roundsPlayed == 0) {
      return {
        "Rote Memorization": 0.0,
        "Working Memory": 0.0,
        "Quantitative Reasoning": 0.0,
        "Information Processing Speed": 0.0,
        "Cognitive Flexibility": 0.0,
      };
    }

    // --- Core Accuracies (no guessing / no imputation) ---
    double roteMem = recallTrials > 0
        ? (sumRecallAccuracy / recallTrials).clamp(0.0, 1.0)
        : 0.0;

    double workingMem = processTrials > 0
        ? (sumProcessAccuracy / processTrials).clamp(0.0, 1.0)
        : 0.0;

    double quantitative = mathTrials > 0
        ? (sumMathAccuracy / mathTrials).clamp(0.0, 1.0)
        : 0.0;

    // --- Information Processing Speed (earned, not raw) ---
    double totalAccuracy = (sumTotalAccuracy / roundsPlayed).clamp(0.0, 1.0);
    double avgTimeMs = totalProcessTime / roundsPlayed;

    // 4s = excellent, 15s = slow/timeout range
    double rawSpeed = (1.0 - ((avgTimeMs - 4000) / 11000)).clamp(0.0, 1.0);

    // Speed only counts if you're accurate
    double processingSpeed = (rawSpeed * totalAccuracy).clamp(0.0, 1.0);

    // --- Cognitive Flexibility (only if 2+ task types occurred) ---
    final List<double> modes = [];
    if (recallTrials > 0) modes.add(roteMem);
    if (processTrials > 0) modes.add(workingMem);
    if (mathTrials > 0) modes.add(quantitative);

    double cognitiveFlexibility = 0.0;
    if (modes.length >= 2) {
      double mean = modes.reduce((a, b) => a + b) / modes.length;

      double variance = 0.0;
      for (final v in modes) {
        variance += pow(v - mean, 2).toDouble();
      }
      variance /= modes.length;

      double stdDev = sqrt(variance);

      // Lower variance across modes = better flexibility
      cognitiveFlexibility = (1.0 - stdDev).clamp(0.0, 1.0);
    } else {
      // Not enough evidence of switching
      cognitiveFlexibility = 0.0;
    }

    return {
      "Rote Memorization": roteMem,
      "Working Memory": workingMem,
      "Quantitative Reasoning": quantitative,
      "Information Processing Speed": processingSpeed,
      "Cognitive Flexibility": cognitiveFlexibility,
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("3. Digit Shuffle (${roundsPlayed + 1}/$totalRounds)"),
        automaticallyImplyLeading: false,
        actions: [
          if (!isMemorizing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: Text("${roundSeconds}s", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange))),
            ),
          TextButton(onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(null);
          }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
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