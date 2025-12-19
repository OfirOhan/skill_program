// lib/stress_sprint_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StressSprintGame extends StatefulWidget {
  const StressSprintGame({Key? key}) : super(key: key);

  @override
  _StressSprintGameState createState() => _StressSprintGameState();
}

class _StressSprintGameState extends State<StressSprintGame> with TickerProviderStateMixin {
  // Game State
  bool isGameOver = false;
  bool hasCashedOut = false;

  // Puzzle Data
  int level = 1;
  String question = "";
  int correctAnswer = 0;
  List<int> options = [];

  // Bank Data
  int currentPot = 0; // Points at risk
  int bankedScore = 0; // Safe points

  // Timers
  late AnimationController _progressController;
  double timeLimit = 5.0;

  // Metrics
  int maxLevelReached = 0;
  bool panicFailure = false;

  // --- NEW: measurable metrics ---
  int solvedCount = 0;               // how many puzzles solved correctly
  int crashCount = 0;               // 0 or 1 (because game ends on crash)
  bool crashedByTimeout = false;

  int roundStartMs = 0;
  int roundLimitMs = 0;             // current time limit in ms
  final List<double> timeFractions = []; // elapsed/limit per answered puzzle (0..1)

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleTimeout();
      }
    });

    _nextPuzzle();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _nextPuzzle() {
    if (isGameOver) return;

    setState(() {
      timeLimit = max(1.5, 5.0 - (level * 0.3));

      _generateMathProblem();

      roundStartMs = DateTime.now().millisecondsSinceEpoch;
      roundLimitMs = (timeLimit * 1000).toInt();

      _progressController.duration = Duration(milliseconds: roundLimitMs);
      _progressController.reset();
      _progressController.forward();
    });
  }


  void _generateMathProblem() {
    final rand = Random();
    int a = rand.nextInt(10) + (level * 2);
    int b = rand.nextInt(10) + (level * 2);

    if (level < 3) {
      question = "$a + $b";
      correctAnswer = a + b;
    } else if (level < 6) {
      int large = max(a, b);
      int small = min(a, b);
      question = "$large - $small";
      correctAnswer = large - small;
    } else {
      if (rand.nextBool()) {
        int smallA = rand.nextInt(5)+2;
        int smallB = rand.nextInt(5)+2;
        question = "$smallA × $smallB";
        correctAnswer = smallA * smallB;
      } else {
        question = "$a + $b";
        correctAnswer = a + b;
      }
    }

    Set<int> opts = {correctAnswer};
    while (opts.length < 3) {
      int delta = (rand.nextInt(9) + 1) * (rand.nextBool() ? 1 : -1);
      int cand = correctAnswer + delta;
      if (cand >= 0) opts.add(cand);
    }
    options = opts.toList()..shuffle();

  }

  void _onOptionSelected(int selected) {
    if (isGameOver) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - roundStartMs).clamp(0, max(1, roundLimitMs));
    final frac = (elapsed / max(1, roundLimitMs)).clamp(0.0, 1.0);
    timeFractions.add(frac);

    if (selected == correctAnswer) {
      setState(() {
        solvedCount++; // NEW
        currentPot += (level * 10);
        level++;
        maxLevelReached = max(maxLevelReached, level); // safer than overwrite
      });
      HapticFeedback.mediumImpact();
      _nextPuzzle();
    } else {
      HapticFeedback.heavyImpact();
      crashedByTimeout = false; // NEW
      _handleCrash("Wrong Answer!");
    }
  }


  void _handleTimeout() {
    HapticFeedback.vibrate();
    crashedByTimeout = true; // NEW
    _handleCrash("Time's Up!");
  }

  void _handleCrash(String reason) {
    _progressController.stop();
    setState(() {
      isGameOver = true;
      panicFailure = true;
      crashCount = 1;     // NEW
      currentPot = 0;
    });
  }


  void _cashOut() {
    _progressController.stop();
    HapticFeedback.mediumImpact();
    setState(() {
      isGameOver = true;
      hasCashedOut = true;
      bankedScore = currentPot;
    });
  }

  Map<String, double> grade() {
    // Performance (how far you got) — cap at 10 solves for normalization
    final double levelScore = (solvedCount / 10.0).clamp(0.0, 1.0);

    // Speed: based on how much of the time window you used (lower fraction = faster)
    // Convert fraction to speed: 0.0 used -> 1.0 speed, 1.0 used -> 0.0 speed
    final double avgFrac = timeFractions.isEmpty
        ? 1.0
        : (timeFractions.reduce((a, b) => a + b) / timeFractions.length).clamp(0.0, 1.0);

    final double rawSpeed = (1.0 - avgFrac).clamp(0.0, 1.0);

    // Quantitative Reasoning: difficulty progression is the strongest evidence here
    final double quantitative = levelScore;

    // Information Processing Speed: speed only “counts” if you actually solved things
    final double infoSpeed = (rawSpeed * levelScore).clamp(0.0, 1.0);

    // Decision Under Pressure: mix of progression + speed, with extra penalty if you timed out
    final double timeoutPenalty = crashedByTimeout ? 0.20 : 0.0;
    final double decisionUnderPressure =
    (0.75 * levelScore + 0.25 * rawSpeed - timeoutPenalty).clamp(0.0, 1.0);

    // Risk Management: only direct signal available is whether they used CASH OUT.
    // (Coarse by design: the game ends immediately after cashout.)
    final double riskManagement =
    hasCashedOut ? (0.6 + 0.4 * levelScore).clamp(0.0, 1.0) : (0.15 * levelScore).clamp(0.0, 1.0);

    return {
      "Quantitative Reasoning": quantitative,
      "Information Processing Speed": infoSpeed,
      "Decision Under Pressure": decisionUnderPressure,
      "Risk Management": riskManagement,
    };
  }


  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.white, // Clean End Screen
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  panicFailure ? Icons.warning_amber_rounded : Icons.lock_outline,
                  color: panicFailure ? Colors.red : Colors.green,
                  size: 80
              ),
              const SizedBox(height: 20),
              Text(
                  panicFailure ? "CRASHED!" : "SECURED!",
                  style: TextStyle(
                      color: panicFailure ? Colors.red : Colors.green[800],
                      fontSize: 32,
                      fontWeight: FontWeight.bold
                  )
              ),
              const SizedBox(height: 10),
              Text(
                  panicFailure ? "Pot lost." : "Banked: $bankedScore",
                  style: const TextStyle(color: Colors.grey, fontSize: 18)
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                   HapticFeedback.lightImpact();
                   Navigator.of(context).pop(grade());
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("FINISH ASSESSMENT"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("15. Stress Sprint"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Skip Button logic is handled by "Finishing" with 0 score here usually,
          // but to keep consistency let's add a standard Skip
          TextButton(
              onPressed: () { 
                 HapticFeedback.lightImpact();
                 Navigator.of(context).pop(null);
              },
              child: const Text("SKIP", style: TextStyle(color: Colors.redAccent))
          )
        ],
      ),
      body: Column(
        children: [
          // --- HUD (Indigo Theme) ---
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.indigo[50], // Soft Indigo
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withOpacity(0.1))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("POT AT RISK", style: TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text("$currentPot", style: const TextStyle(color: Colors.indigo, fontSize: 32, fontWeight: FontWeight.w900)),
                  ],
                ),
                ElevatedButton(
                  onPressed: _cashOut,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Keep Green for Action
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text("CASH OUT", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),

          // --- TIMER BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                // Color shifts from Indigo -> Red as time runs out
                Color barColor = Color.lerp(Colors.indigo, Colors.red, _progressController.value)!;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 1.0 - _progressController.value,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 12,
                  ),
                );
              },
            ),
          ),

          // --- PUZZLE AREA ---
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      question,
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.black87)
                  ),
                  const SizedBox(height: 50),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: options.map((opt) {
                      return SizedBox(
                        width: 100, height: 80,
                        child: ElevatedButton(
                          onPressed: () => _onOptionSelected(opt),
                          style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              side: BorderSide(color: Colors.grey[300]!)
                          ),
                          child: Text("$opt", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}