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
  bool isGameOver = false;
  String instruction = "";

  // Feedback State (New)
  String? feedbackMessage;
  Color? feedbackColor;

  // Round Config
  static const int totalRounds = 5;
  int roundsPlayed = 0;

  // Per-Round Timer
  Timer? _roundTimer;
  Timer? _memoTimer;
  int roundSeconds = 15;
  int startInputMs = 0;

  // Metrics
  int correctRecall = 0;
  int correctProcess = 0;
  int totalProcessTime = 0;

  // Skill tracking
  int recallTrials = 0;
  int processTrials = 0;
  int mathTrials = 0;
  int mathCorrect = 0;

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

  void _finishGame() {
    _roundTimer?.cancel();
    _memoTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _startRound() {
    if (roundsPlayed >= totalRounds) {
      _finishGame();
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
      if (!mounted || isGameOver) return;

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
    if (isGameOver || isMemorizing || feedbackMessage != null) return;
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
    bool isCorrect = listEquals(userAnswer, expected);
    _processResult(isCorrect);
  }

  void _submitAnswer() {
    _roundTimer?.cancel();
    bool isCorrect = listEquals(userAnswer, expected);
    _processResult(isCorrect);
  }

  void _processResult(bool isCorrect) {
    // 1. Record Stats
    if (isCorrect) {
      final rt = DateTime.now().millisecondsSinceEpoch - startInputMs;
      totalProcessTime += rt;

      if (instruction.contains("Recall")) correctRecall++;
      else correctProcess++;

      if (instruction.contains("Add")) mathCorrect++;
    }

    // 2. Show Feedback Overlay
    setState(() {
      feedbackMessage = isCorrect ? "CORRECT!" : "WRONG!";
      feedbackColor = isCorrect ? Colors.green : Colors.red;
    });
    
    if (isCorrect) {
       HapticFeedback.mediumImpact();
    } else {
       HapticFeedback.heavyImpact();
    }

    // 3. Delay before next round
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        feedbackMessage = null; // Hide overlay
      });
      roundsPlayed++;
      _startRound();
    });
  }

  Map<String, double> grade() {
    double stm = recallTrials == 0 ? 0.0 : correctRecall / recallTrials;
    if (recallTrials == 0 && roundsPlayed > 0) stm = 1.0;

    double wm = processTrials == 0 ? 0.0 : correctProcess / processTrials;
    if (processTrials == 0 && roundsPlayed > 0) wm = stm;

    double avgTime = roundsPlayed == 0 ? 2000 : totalProcessTime / roundsPlayed;
    double speedScore = (1.0 - ((avgTime - 2000) / 8000)).clamp(0.0, 1.0);

    double numReason = mathTrials == 0 ? 0.0 : mathCorrect / mathTrials;
    if (mathTrials == 0) numReason = wm;

    double ltm = (wm * 0.7 + speedScore * 0.3).clamp(0.0, 1.0);
    double totalAcc = roundsPlayed == 0 ? 0.0 : (correctRecall + correctProcess) / roundsPlayed;

    return {
      "Short-Term Memory": stm,
      "Working Memory": wm,
      "Long-Term Recall": ltm,
      "Information Processing Speed": speedScore,
      "Problem Decomposition": wm,
      "Numerical Reasoning": numReason,
      "Attention to Detail": totalAcc,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        appBar: AppBar(title: const Text("3. Digit Shuffle"), automaticallyImplyLeading: false),
        body: Container(
          width: double.infinity,
          color: Colors.black87,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text("Section Complete!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Score: ${(correctRecall + correctProcess)} / $totalRounds", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                   HapticFeedback.lightImpact();
                   Navigator.of(context).pop(grade());
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
      body: Stack(
        children: [
          Column(
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

          // --- FEEDBACK OVERLAY ---
          if (feedbackMessage != null)
            Container(
              color: feedbackColor!.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        feedbackColor == Colors.green ? Icons.check_circle_outline : Icons.cancel_outlined,
                        color: Colors.white, size: 100
                    ),
                    const SizedBox(height: 20),
                    Text(feedbackMessage!, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (feedbackColor == Colors.red)
                      Text("Answer: ${expected.join(' ')}", style: const TextStyle(color: Colors.white, fontSize: 20)),
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