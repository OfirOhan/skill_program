// lib/stress_sprint_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

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
  double timeLimit = 5.0; // Starts at 5 seconds per question

  // Metrics
  int maxLevelReached = 0;
  bool panicFailure = false; // Did they crash?

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
      // Escalating Difficulty: Time gets shorter every level
      // Lvl 1: 5.0s, Lvl 10: 2.0s
      timeLimit = max(1.5, 5.0 - (level * 0.3));

      _generateMathProblem();

      // Reset Timer
      _progressController.duration = Duration(milliseconds: (timeLimit * 1000).toInt());
      _progressController.reset();
      _progressController.forward();
    });
  }

  void _generateMathProblem() {
    final rand = Random();
    int a = rand.nextInt(10) + (level * 2);
    int b = rand.nextInt(10) + (level * 2);

    // Randomize Operation based on level
    if (level < 3) { // Add
      question = "$a + $b";
      correctAnswer = a + b;
    } else if (level < 6) { // Sub
      // Ensure positive result
      int large = max(a, b);
      int small = min(a, b);
      question = "$large - $small";
      correctAnswer = large - small;
    } else { // Mix or Mult
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

    // Options
    Set<int> opts = {correctAnswer};
    while(opts.length < 3) {
      opts.add(correctAnswer + (rand.nextInt(10) - 5)); // +/- 5 error margin
    }
    // Remove accidental duplicates if rand(0) happened, though Set handles it.
    // Ensure distinct:
    while(opts.length < 3) opts.add(rand.nextInt(100));

    options = opts.toList()..shuffle();
  }

  void _onOptionSelected(int selected) {
    if (isGameOver) return;

    if (selected == correctAnswer) {
      // Success! Add to pot
      setState(() {
        currentPot += (level * 10); // Higher levels = More points
        level++;
        maxLevelReached = level;
      });
      _nextPuzzle();
    } else {
      // Wrong Answer = CRASH
      _handleCrash("Wrong Answer!");
    }
  }

  void _handleTimeout() {
    _handleCrash("Time's Up!");
  }

  void _handleCrash(String reason) {
    _progressController.stop();
    setState(() {
      isGameOver = true;
      panicFailure = true;
      currentPot = 0; // LOST EVERYTHING
    });
  }

  void _cashOut() {
    _progressController.stop();
    setState(() {
      isGameOver = true;
      hasCashedOut = true;
      bankedScore = currentPot; // SECURED
    });
  }

  Map<String, double> grade() {
    // 1. Risk Assessment (Did they cash out?)
    double riskScore = hasCashedOut ? 1.0 : 0.0;

    // 2. Stress Tolerance (How far did they get before stopping/crashing?)
    // Level 10 is considered high stress tolerance
    double stress = (maxLevelReached / 10.0).clamp(0.0, 1.0);

    // 3. Emotional Regulation (Did they panic-click wrong?)
    // If they crashed due to wrong answer vs timeout implies panic
    double regulation = panicFailure ? 0.2 : 1.0;

    return {
      "Stress Tolerance": stress,
      "Frustration Handling": regulation,
      "Persistence": stress,
      "Resilience": hasCashedOut ? 0.8 : 0.2, // Ability to recognize limit
      "Decision Making Under Pressure": (riskScore * 0.6 + stress * 0.4).clamp(0.0, 1.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: panicFailure ? Colors.red[900] : Colors.green[900],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  panicFailure ? Icons.warning : Icons.lock,
                  color: Colors.white, size: 80
              ),
              const SizedBox(height: 20),
              Text(
                  panicFailure ? "CRASHED!" : "SECURED!",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              Text(
                  panicFailure ? "You lost the pot." : "Banked: $bankedScore",
                  style: const TextStyle(color: Colors.white70, fontSize: 18)
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(grade()),
                icon: const Icon(Icons.check),
                label: const Text("FINISH ASSESSMENT"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("15. Stress Sprint (Lvl $level)"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- HUD ---
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("POT AT RISK", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    Text("$currentPot", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  onPressed: _cashOut,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                  ),
                  child: const Text("CASH OUT"),
                )
              ],
            ),
          ),

          // --- TIMER BAR ---
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _progressController.value,
                backgroundColor: Colors.red[100],
                valueColor: AlwaysStoppedAnimation<Color>(
                    _progressController.value > 0.7 ? Colors.red : Colors.blue
                ),
                minHeight: 10,
              );
            },
          ),

          // --- PUZZLE AREA ---
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(question, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.indigo[50]
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