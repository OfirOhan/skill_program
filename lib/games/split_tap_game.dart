// lib/split_tap_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../grading/split_tap_grading.dart';

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

  // --- NEW: left-side trial accounting (tracking only) ---
  bool _hasActiveLeftTrial = false;
  bool _leftTrialWasTarget = false;
  bool _leftTrialResponded = false;
  bool _leftTrialIsPostSwitch = false;
  int _leftTrialStartMs = 0;

  int _leftTargets = 0;
  int _leftDistractors = 0;
  int _leftHitsT = 0;       // target hits
  int _leftCorrectRejections = 0;

  // --- Instruction Adherence tracking ---
  int _postSwitchTrials = 0;
  int _postSwitchCorrect = 0;

  final List<bool> _leftTrialCorrect = [];
  final List<bool> _leftTrialPostSwitch = [];
  final List<int> _leftHitRTs = []; // optional, not scored here


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

    // finalize the last left trial so it isn't dropped
    _finalizeLeftTrial();

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
      // Finalize the previous flash as a completed trial
      _finalizeLeftTrial();

      // CHECK RULE SWITCH before showing the new flash
      flashesSeen++;
      bool didSwitch = false;
      if (flashesSeen >= flashesUntilRuleChange) {
        _switchRule();
        didSwitch = true;
        flashesSeen = 0;
        flashesUntilRuleChange = 4 + rand.nextInt(4);
      }

      // Determine next stimulus (same as your logic)
      bool showTarget = rand.nextDouble() < 0.3;

      if (showTarget) {
        currentStimulusColor = targetColor;
        isTargetActive = true;
      } else {
        var distractor = colorPalette[rand.nextInt(colorPalette.length)];
        while (distractor['color'] == targetColor) {
          distractor = colorPalette[rand.nextInt(colorPalette.length)];
        }
        currentStimulusColor = distractor['color'];
        isTargetActive = false;
      }

      // Start a new trial (tracking only)
      _hasActiveLeftTrial = true;
      _leftTrialWasTarget = showTarget;
      _leftTrialResponded = false;
      _leftTrialIsPostSwitch = didSwitch;
      _leftTrialStartMs = DateTime.now().millisecondsSinceEpoch;
    });

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

  void _finalizeLeftTrial() {
    if (!_hasActiveLeftTrial) return;

    // Correctness for this trial (target: hit=correct, miss=wrong; distractor: no-tap=correct, tap=wrong)
    bool correct;

    if (_leftTrialWasTarget) {
      _leftTargets++;
      if (_leftTrialResponded) {
        _leftHitsT++;
        correct = true;
      } else {
        correct = false;
      }
    } else {
      _leftDistractors++;
      if (_leftTrialResponded) {
        correct = false;
      } else {
        _leftCorrectRejections++;
        correct = true;
      }
    }
    if (_leftTrialIsPostSwitch) {
      _postSwitchTrials++;
      if (correct) {
        _postSwitchCorrect++;
      }
    }
    _leftTrialCorrect.add(correct);
    _leftTrialPostSwitch.add(_leftTrialIsPostSwitch);

    _hasActiveLeftTrial = false;
  }

  void _onLeftTap() {
    if (isGameOver) return;

    setState(() {
      // tracking: mark that a response occurred on this flash (once)
      if (_hasActiveLeftTrial && !_leftTrialResponded) {
        _leftTrialResponded = true;

        if (_leftTrialWasTarget) {
          final rt = DateTime.now().millisecondsSinceEpoch - _leftTrialStartMs;
          _leftHitRTs.add(rt);
        }
      }

      // keep your original visible/game counters & feedback unchanged
      if (isTargetActive) {
        leftHits++;
        isTargetActive = false;
        HapticFeedback.mediumImpact();
        currentStimulusColor = Colors.grey[300]!;
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
    return SplitTapGrading.grade(
      leftTargets: _leftTargets,
      leftDistractors: _leftDistractors,
      leftHitsT: _leftHitsT,
      leftCorrectRejections: _leftCorrectRejections,
      leftTrialCorrect: _leftTrialCorrect,
      leftTrialPostSwitch: _leftTrialPostSwitch,
      postSwitchTrials: _postSwitchTrials,
      postSwitchCorrect: _postSwitchCorrect,
      mathHits: mathHits,
      mathWrongs: mathWrongs,
      mathRTs: mathRTs,
    );
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
        title: const Text("Split Tap"),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                "${remainingSeconds.toInt()} s",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: remainingSeconds <= 5 ? Colors.red : Colors.indigo
                )
              ),
            ),
          ),
        ],
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