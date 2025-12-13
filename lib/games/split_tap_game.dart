// lib/split_tap_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    // Slower intervals (1000ms - 1500ms) - Adjusted for user preference
    int nextDelay = 800 + rand.nextInt(400);
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
        HapticFeedback.mediumImpact();
        currentStimulusColor = Colors.grey[300]!; // Feedback: Light off immediately
      } else {
        HapticFeedback.heavyImpact();
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
      if (selection == mathAnswer) {
        mathHits++;
        HapticFeedback.mediumImpact();
      } else {
        mathWrongs++;
        HapticFeedback.heavyImpact();
      }
    });
    _nextMathProblem();
  }

  Map<String, double> grade() {
    // ---------- LEFT TASK METRICS (Go/No-Go) ----------
    final int leftTargets = leftHits + leftMisses;             // times target appeared
    final int leftResponses = leftHits + leftFalseAlarms;      // taps made
    final int leftTotalEvents = leftHits + leftMisses + leftFalseAlarms;

    // Sensitivity (hit rate) and precision (tap correctness)
    final double leftRecall = leftTargets == 0 ? 0.0 : (leftHits / leftTargets).clamp(0.0, 1.0);
    final double leftPrecision = leftResponses == 0 ? 0.0 : (leftHits / leftResponses).clamp(0.0, 1.0);

    // Inhibition = resisting taps on non-targets (approximated via false alarms)
    // We don't know true distractor count directly, so we approximate specificity using penalties.
    final double inhibition = (1.0 - (leftFalseAlarms / max(1, leftFalseAlarms + leftHits))).clamp(0.0, 1.0);

    // Left performance: balanced (don’t reward conservative or spam tapping)
    final double leftF1 = (leftPrecision + leftRecall) == 0
        ? 0.0
        : (2 * leftPrecision * leftRecall) / (leftPrecision + leftRecall);

    // ---------- RIGHT TASK METRICS (Math) ----------
    final int mathTotal = mathHits + mathWrongs;
    final double mathAccuracy = mathTotal == 0 ? 0.0 : (mathHits / mathTotal).clamp(0.0, 1.0);

    final double avgMathRt = mathRTs.isEmpty
        ? 2000.0
        : mathRTs.reduce((a, b) => a + b) / mathRTs.length;

    // Raw speed benchmark: 700ms = very fast, 2200ms = very slow
    final double rawSpeed = (1.0 - ((avgMathRt - 700.0) / 1500.0)).clamp(0.0, 1.0);

    // Earned speed: fast only counts if you're correct
    final double infoSpeed = (rawSpeed * mathAccuracy).clamp(0.0, 1.0);

    // ---------- DUAL-TASK LOAD (Working Memory) ----------
    // Working memory here = doing both tasks well simultaneously:
    // math accuracy + left accuracy (F1), plus slight penalty if either collapses.
    final double workingMemory = (
        0.55 * mathAccuracy +
            0.45 * leftF1
    ).clamp(0.0, 1.0);

    // ---------- COGNITIVE FLEXIBILITY (Rule switching) ----------
    // We don’t track per-switch performance directly, so we use a conservative proxy:
    // If false alarms are high OR recall is low, it indicates difficulty adapting to rule changes.
    // Penalize instability via false alarms + missed targets.
    final double instability = (
        (leftFalseAlarms / max(1, leftTotalEvents)) +
            (leftMisses / max(1, leftTargets))
    ).clamp(0.0, 1.0);

    final double cognitiveFlexibility = (1.0 - instability).clamp(0.0, 1.0);

    // ---------- RESPONSE INHIBITION ----------
    // Directly from inhibition score (don’t tap on non-target)
    final double responseInhibition = inhibition;

    // ---------- QUANTITATIVE REASONING ----------
    // Directly from math accuracy
    final double quantitativeReasoning = mathAccuracy;

    // ---------- DECISION UNDER PRESSURE ----------
    // Overall quality under timer: accuracy-dominant, with small speed component
    final double overallAccuracy = (0.5 * mathAccuracy + 0.5 * leftF1).clamp(0.0, 1.0);
    final double decisionUnderPressure = (0.75 * overallAccuracy + 0.25 * rawSpeed).clamp(0.0, 1.0);

    return {
      "Working Memory": workingMemory,
      "Cognitive Flexibility": cognitiveFlexibility,
      "Response Inhibition": responseInhibition,
      "Quantitative Reasoning": quantitativeReasoning,
      "Information Processing Speed": infoSpeed,
      "Decision Under Pressure": decisionUnderPressure,
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
                onPressed: () { 
                   HapticFeedback.lightImpact(); 
                   Navigator.of(context).pop(grade());
                },
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
        actions: [TextButton(onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(null);
        }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, // MAXIMIZE TOUCH AREA
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
                    const Text("TAP ON:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
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