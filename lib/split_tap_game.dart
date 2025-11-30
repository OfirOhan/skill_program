// lib/split_tap_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class SplitTapGame extends StatefulWidget {
  const SplitTapGame({Key? key}) : super(key: key);

  @override
  _SplitTapGameState createState() => _SplitTapGameState();
}

class _SplitTapGameState extends State<SplitTapGame> {
  final rand = Random();
  bool isGameOver = false;

  // -- TIMERS --
  Timer? _gameTimer;
  Timer? _leftSideTimer;
  int remainingSeconds = 30;

  // -- LEFT SIDE (Visual Logic) --
  Color currentStimulusColor = Colors.grey[200]!;
  Color targetColor = Colors.green;
  String targetName = "GREEN";

  int leftHits = 0;
  int leftFalseAlarms = 0;
  int leftMisses = 0;
  bool isTargetActive = false;

  // Rule Switching Counters
  int flashesSeen = 0;
  int flashesUntilRuleChange = 0; // Will be 4-7

  // -- RIGHT SIDE (Math) --
  String mathQuestion = "";
  int mathAnswer = 0;
  List<int> mathOptions = [];
  int mathHits = 0;
  int mathWrongs = 0;
  int lastMathChange = 0;
  List<int> mathRTs = [];

  final List<Map<String, dynamic>> colorPalette = [
    {"name": "GREEN", "color": Colors.green},
    {"name": "RED", "color": Colors.red},
    {"name": "BLUE", "color": Colors.blue},
    {"name": "ORANGE", "color": Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize first rule switch target (4 to 7 flashes)
    flashesUntilRuleChange = 4 + rand.nextInt(4);
    _startGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _leftSideTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) _finishGame();
    });

    _scheduleNextLeftColor();
    _nextMathProblem();
  }

  void _finishGame() {
    _gameTimer?.cancel();
    _leftSideTimer?.cancel();
    setState(() => isGameOver = true);
  }

  // --- SYNCHRONIZED FLASH LOOP ---
  void _scheduleNextLeftColor() {
    if (isGameOver) return;

    // Fast intervals (600ms - 900ms)
    int nextDelay = 600 + rand.nextInt(300);
    _leftSideTimer = Timer(Duration(milliseconds: nextDelay), _executeFlashCycle);
  }

  void _executeFlashCycle() {
    if (isGameOver) return;

    setState(() {
      // 1. Record Miss from PREVIOUS cycle (if valid)
      // If the light was Target Color, and user didn't tap, it's a miss.
      if (isTargetActive) {
        leftMisses++;
      }

      // 2. CHECK RULE SWITCH
      // Before showing the NEW color, check if we need to change the rule
      flashesSeen++;
      if (flashesSeen >= flashesUntilRuleChange) {
        _switchRule();
        flashesSeen = 0;
        flashesUntilRuleChange = 4 + rand.nextInt(4); // Reset counter (4-7)
      }

      // 3. Determine Next Stimulus
      // 30% chance it matches the (possibly new) Target Rule
      bool showTarget = rand.nextDouble() < 0.3;

      if (showTarget) {
        currentStimulusColor = targetColor;
        isTargetActive = true;
      } else {
        // Distractor: Pick a color that is NOT the target
        var distractor = colorPalette[rand.nextInt(colorPalette.length)];
        while (distractor['color'] == targetColor) {
          distractor = colorPalette[rand.nextInt(colorPalette.length)];
        }
        currentStimulusColor = distractor['color'];
        isTargetActive = false;
      }
    });

    // Schedule next
    _scheduleNextLeftColor();
  }

  void _switchRule() {
    // Pick a NEW target color
    var newTarget = colorPalette[rand.nextInt(colorPalette.length)];
    while (newTarget['color'] == targetColor) {
      newTarget = colorPalette[rand.nextInt(colorPalette.length)];
    }
    targetColor = newTarget['color'];
    targetName = newTarget['name'];
    // The UI banner updates immediately because we are inside setState()
  }

  void _onLeftTap() {
    if (isGameOver) return;

    setState(() {
      if (isTargetActive) {
        leftHits++;
        isTargetActive = false;
        currentStimulusColor = Colors.grey[300]!; // Feedback: Light off immediately
      } else {
        leftFalseAlarms++;
      }
    });
  }

  // --- RIGHT TASK: MATH ---
  void _nextMathProblem() {
    int op = rand.nextInt(3); // 0: Add, 1: Sub, 2: Mult
    int a, b, correct;
    String sign;

    if (op == 0) {
      a = rand.nextInt(20) + 5; b = rand.nextInt(20) + 5;
      correct = a + b; sign = "+";
    } else if (op == 1) {
      a = rand.nextInt(20) + 10; b = rand.nextInt(a - 1) + 1;
      correct = a - b; sign = "-";
    } else {
      a = rand.nextInt(9) + 2; b = rand.nextInt(9) + 2;
      correct = a * b; sign = "×";
    }

    Set<int> opts = {correct};
    while (opts.length < 3) {
      int offset = rand.nextInt(5) + 1;
      opts.add(rand.nextBool() ? correct + offset : correct - offset);
    }

    setState(() {
      mathQuestion = "$a $sign $b";
      mathAnswer = correct;
      mathOptions = opts.toList()..shuffle();
      lastMathChange = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _onRightTap(int selection) {
    if (isGameOver) return;
    final rt = DateTime.now().millisecondsSinceEpoch - lastMathChange;
    mathRTs.add(rt);

    setState(() {
      if (selection == mathAnswer) mathHits++; else mathWrongs++;
    });
    _nextMathProblem();
  }

  // --- GRADING ---
  Map<String, double> grade() {
    int totalLeftEvents = leftHits + leftMisses + leftFalseAlarms;
    double leftAcc = totalLeftEvents == 0 ? 0.0 : leftHits / max(1, totalLeftEvents);

    int totalMathEvents = mathHits + mathWrongs;
    double rightAcc = totalMathEvents == 0 ? 0.0 : mathHits / max(1, totalMathEvents);

    double multiTasking = (leftAcc * 0.5 + rightAcc * 0.5).clamp(0.0, 1.0);
    double selectivity = (1.0 - (leftFalseAlarms / max(1, leftHits + leftFalseAlarms + 5))).clamp(0.0, 1.0);

    double avgRt = mathRTs.isEmpty ? 2000 : mathRTs.reduce((a,b)=>a+b) / mathRTs.length;
    double speedScore = (1.0 - ((avgRt - 800) / 1200)).clamp(0.0, 1.0);

    return {
      "Multi-tasking Ability": multiTasking,
      "Selective Attention": selectivity,
      "Sustained Attention": multiTasking * 0.9,
      "Information Processing Speed": speedScore,
      "Numerical Reasoning": rightAcc,
      "Reaction Time": speedScore,
      "Rule Following Accuracy": (1.0 - (leftFalseAlarms + mathWrongs) / 15.0).clamp(0.0, 1.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.splitscreen, color: Colors.blue, size: 80),
              const SizedBox(height: 20),
              const Text("Split Stream Done!", style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 10),
              Text("Visual Hits: $leftHits  |  Math Solved: $mathHits", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(grade()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("6. Split Tap ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
      ),
      body: Row(
        children: [
          // --- LEFT SIDE: VISUAL MONITOR ---
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: _onLeftTap,
              child: Container(
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("TAP ON:", style: TextStyle(fontSize: 16, color: Colors.black54)),
                    const SizedBox(height: 10),
                    // DYNAMIC INSTRUCTION BANNER (Updates synced with flash)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                          color: targetColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))]
                      ),
                      child: Text(
                          targetName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)
                      ),
                    ),
                    const SizedBox(height: 40),
                    // THE STIMULUS LIGHT
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                          color: currentStimulusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: currentStimulusColor == Colors.grey[200] ? Colors.transparent : currentStimulusColor.withOpacity(0.6),
                                blurRadius: 20, spreadRadius: 5
                            )
                          ]
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(width: 2, color: Colors.black12),

          // --- RIGHT SIDE: MATH SPRINT ---
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("SOLVE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  FittedBox(
                    child: Text(mathQuestion, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 30),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: mathOptions.map((opt) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ElevatedButton(
                          onPressed: () => _onRightTap(opt),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Colors.indigo[50],
                            foregroundColor: Colors.indigo,
                            elevation: 0,
                            side: BorderSide(color: Colors.indigo[100]!),
                          ),
                          child: Text("$opt", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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