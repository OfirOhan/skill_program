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

  // --- NEW: left-side trial accounting (tracking only) ---
  bool _hasActiveLeftTrial = false;
  bool _leftTrialWasTarget = false;
  bool _leftTrialResponded = false;
  bool _leftTrialIsPostSwitch = false;
  int _leftTrialStartMs = 0;

  int _leftTargets = 0;
  int _leftDistractors = 0;
  int _leftHitsT = 0;
  int _leftMissesT = 0;
  int _leftFalseAlarmTrials = 0;
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
        _leftMissesT++;
        correct = false;
      }
    } else {
      _leftDistractors++;
      if (_leftTrialResponded) {
        _leftFalseAlarmTrials++;
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
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    // ---------- LEFT TASK (trial-based Go/No-Go) ----------
    final int leftTotalTrials = _leftTargets + _leftDistractors;
    if (leftTotalTrials <= 0) {
      return {
        "Response Inhibition": 0.0,
        "Cognitive Flexibility": 0.0,
        "Observation / Vigilance": 0.0,
        "Quantitative Reasoning": 0.0,
        "Reaction Time (Choice)": 0.0,
      };
    }

    final double hitRate = _leftTargets == 0 ? 0.0 : clamp01(_leftHitsT / _leftTargets);
    final double specificity = _leftDistractors == 0 ? 0.0 : clamp01(_leftCorrectRejections / _leftDistractors);
    final double leftBalancedAccuracy = (hitRate + specificity) / 2.0;

    // Response Inhibition: direct evidence = resisting taps on distractors (specificity)
    // Reliability gate: need enough distractors to claim inhibition
    final double inhibEvidence = clamp01(_leftDistractors / 8.0);
    final double responseInhibition = clamp01(specificity * inhibEvidence);

    // Observation / Vigilance: stability over time (first half vs second half) gated by competence
    double observationVigilance = 0.0;
    {
      final int n = _leftTrialCorrect.length;
      if (n >= 10) {
        final int split = n ~/ 2;

        // Recompute BA per half using trial labels
        int t1 = 0, d1 = 0, h1 = 0, cr1 = 0;
        int t2 = 0, d2 = 0, h2 = 0, cr2 = 0;

        // We need target/distractor labels per trial: infer from postSwitch list? no.
        // Instead, use the aggregate counts with per-trial correctness only is not enough,
        // so we conservatively approximate vigilance using correctness rate stability
        // (still direct evidence: correct vs incorrect per trial).
        int c1 = 0, c2 = 0;
        for (int i = 0; i < n; i++) {
          if (i < split) { if (_leftTrialCorrect[i]) c1++; }
          else { if (_leftTrialCorrect[i]) c2++; }
        }

        final double acc1 = clamp01(c1 / (split == 0 ? 1 : split));
        final double acc2 = clamp01(c2 / ((n - split) == 0 ? 1 : (n - split)));

        final double stability = clamp01(1.0 - (acc1 - acc2).abs());
        observationVigilance = clamp01(stability * leftBalancedAccuracy);
      } else {
        observationVigilance = 0.0;
      }
    }

    // Cognitive Flexibility: direct switch-cost evidence (post-switch trials vs baseline)
    double cognitiveFlexibility = 0.0;
    {
      int baseN = 0, baseC = 0;
      int swN = 0, swC = 0;

      for (int i = 0; i < _leftTrialCorrect.length; i++) {
        final bool isSwitchTrial = _leftTrialPostSwitch[i];
        final bool correct = _leftTrialCorrect[i];
        if (isSwitchTrial) { swN++; if (correct) swC++; }
        else { baseN++; if (correct) baseC++; }
      }

      // Need enough evidence in both sets
      if (swN >= 2 && baseN >= 8) {
        final double baseAcc = clamp01(baseC / baseN);
        final double swAcc = clamp01(swC / swN);

        // switch cost: how much performance drops after a rule change
        final double cost = clamp01((baseAcc - swAcc) < 0 ? 0.0 : (baseAcc - swAcc));
        cognitiveFlexibility = clamp01((1.0 - cost) * baseAcc);
      } else {
        cognitiveFlexibility = 0.0;
      }
    }
    double instructionAdherence = 0.0;
    {
      if (_postSwitchTrials >= 3) {
        final double adherenceRate = clamp01(_postSwitchCorrect / _postSwitchTrials);

        // Reliability gate: need enough switches to claim adherence
        final double evidenceGate = clamp01(_postSwitchTrials / 5.0);

        instructionAdherence = clamp01(adherenceRate * evidenceGate);
      } else {
        instructionAdherence = 0.0;
      }
    }

    // ---------- RIGHT TASK (Math) ----------
    final int mathTotal = mathHits + mathWrongs;
    final double mathAccRaw = mathTotal == 0 ? 0.0 : clamp01(mathHits / mathTotal);

    // Reliability gate: 1 correct answer shouldn't max Quantitative Reasoning
    final double mathEvidence = clamp01(mathTotal / 3.0);
    final double quantitativeReasoning = clamp01(mathAccRaw * mathEvidence);

    // Reaction Time (Choice): median RT on answered math decisions, gated by accuracy + sample size
    double reactionTimeChoice = 0.0;
    {
      if (mathRTs.length >= 5 && mathAccRaw > 0.0) {
        final times = List<int>.from(mathRTs)..sort();
        final int mid = times.length ~/ 2;
        final double medianMs = times.length.isOdd
            ? times[mid].toDouble()
            : ((times[mid - 1] + times[mid]) / 2.0);

        // Scale using a defensible range for 3-option mental arithmetic selection
        const double bestMs = 600.0;
        const double worstMs = 4500.0;
        final double raw = clamp01(1.0 - ((medianMs - bestMs) / (worstMs - bestMs)));

        reactionTimeChoice = clamp01(raw * quantitativeReasoning);
      } else {
        reactionTimeChoice = 0.0;
      }
    }

    return {
      "Response Inhibition": responseInhibition,
      "Cognitive Flexibility": cognitiveFlexibility,
      "Instruction Adherence": instructionAdherence,
      "Observation / Vigilance": observationVigilance,
      "Quantitative Reasoning": quantitativeReasoning,
      "Reaction Time (Choice)": reactionTimeChoice,
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