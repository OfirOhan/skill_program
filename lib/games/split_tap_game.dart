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

  // --- TRIAL PLAN CONFIG ---
  static const int _totalTrials = 30;       // total blinks per game
  static const int _trialDurationMs = 1000; // 1 second per blink
  static const double _targetRatio = 0.3;   // 30% targets, 70% distractors

  // Extra time ONLY on the first blink after a rule switch.
  static const int _postSwitchExtraMs = 300; // +0.3s on post-switch trials

  late List<bool> _leftTrialPlan; // true = target, false = distractor
  int _trialIndex = 0;

  // Precomputed rule-switch schedule: which trial indices start with a new rule
  List<int> _switchIndices = [];

  // Displayed "time" – trials left (≈ seconds)
  int remainingSeconds = _totalTrials;

  Timer? _leftTimer;

  // -- LEFT SIDE (Visual Logic) --
  Color currentStimulusColor = Colors.grey[200]!;
  Color targetColor = Colors.green;
  late Color _prevTargetColor; // for rule-conflict detection
  String targetName = "GREEN";

  int leftHits = 0;
  int leftFalseAlarms = 0;
  int leftMisses = 0;

  bool isTargetActive = false; // currently visual-only flag

  // -- RIGHT SIDE (Math) --
  String mathQuestion = "";
  int mathAnswer = 0;
  List<int> mathOptions = [];
  int mathHits = 0;
  int mathWrongs = 0;

  // --- LEFT-SIDE TRIAL ACCOUNTING (for grading) ---
  bool _hasActiveLeftTrial = false;
  bool _leftTrialWasTarget = false;
  bool _leftTrialResponded = false;
  bool _leftTrialIsPostSwitch = false;
  bool _leftTrialIsRuleConflict = false;

  int _leftTargets = 0;
  int _leftDistractors = 0;
  int _leftHitsT = 0;
  int _leftCorrectRejections = 0;

  final List<bool> _leftTrialCorrect = [];
  final List<bool> _leftTrialPostSwitch = [];
  final List<bool> _leftTrialRuleConflict = [];

  // Tap feedback overlay
  bool _tapFeedbackActive = false;
  Color _tapFeedbackColor = Colors.transparent;

  final List<Map<String, dynamic>> colorPalette = [
    {"name": "GREEN", "color": Colors.green},
    {"name": "RED", "color": Colors.red},
    {"name": "BLUE", "color": Colors.blue},
    {"name": "ORANGE", "color": Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _buildLeftTrialPlan();
    _buildSwitchSchedule();
    _enforceAtLeastOneConflictTarget();
    _prevTargetColor = targetColor; // initial "old" rule same as current
    _startGame();
  }

  void _buildLeftTrialPlan() {
    int numTargets = (_totalTrials * _targetRatio).round();
    if (numTargets < 1) numTargets = 1;
    if (numTargets > _totalTrials - 1) {
      numTargets = _totalTrials - 1;
    }
    final int numDistractors = _totalTrials - numTargets;

    _leftTrialPlan = [
      ...List<bool>.filled(numTargets, true),
      ...List<bool>.filled(numDistractors, false),
    ];
    _leftTrialPlan.shuffle(rand);
  }

  void _buildSwitchSchedule() {
    _switchIndices = [];

    // First switch not too early: somewhere between trials 4–6.
    int idx = 4 + rand.nextInt(3); // 4,5,6
    while (idx < _totalTrials) {
      _switchIndices.add(idx);
      // Next switches 4–7 trials apart
      idx += 4 + rand.nextInt(4); // +4..+7
    }

    // Safety: if somehow empty, force one switch near the middle
    if (_switchIndices.isEmpty) {
      _switchIndices.add(_totalTrials ~/ 2);
    }
  }

  /// Make sure that at least one post-switch trial is a TARGET,
  /// so we are guaranteed to have at least one rule-conflict trial.
  void _enforceAtLeastOneConflictTarget() {
    if (_switchIndices.isEmpty) return;

    // Pick one of the switch indices at random
    final int switchIdx = _switchIndices[rand.nextInt(_switchIndices.length)];

    if (_leftTrialPlan[switchIdx] == true) {
      // Already a target -> guaranteed conflict; nothing to do.
      return;
    }

    // Find a target trial that is NOT a switch trial to swap with
    int swapIdx = -1;
    for (int i = 0; i < _leftTrialPlan.length; i++) {
      if (i == switchIdx) continue;
      if (!_switchIndices.contains(i) && _leftTrialPlan[i] == true) {
        swapIdx = i;
        break;
      }
    }

    // If we still didn't find a non-switch target (very unlikely),
    // just use any other target index.
    if (swapIdx == -1) {
      for (int i = 0; i < _leftTrialPlan.length; i++) {
        if (i == switchIdx) continue;
        if (_leftTrialPlan[i] == true) {
          swapIdx = i;
          break;
        }
      }
    }

    if (swapIdx == -1) {
      // No targets at all (shouldn't happen with our ratio); just force one.
      _leftTrialPlan[switchIdx] = true;
      return;
    }

    // Swap values so total number of targets stays the same.
    final bool tmp = _leftTrialPlan[switchIdx];
    _leftTrialPlan[switchIdx] = _leftTrialPlan[swapIdx];
    _leftTrialPlan[swapIdx] = tmp;
  }

  @override
  void dispose() {
    _leftTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _trialIndex = 0;
    remainingSeconds = _totalTrials;

    _startNextLeftTrial();
    _nextMathProblem();
  }

  void _finishGame() {
    _leftTimer?.cancel();

    setState(() {
      isGameOver = true;
    });
  }

  // ---------------- LEFT STREAM – DETERMINISTIC PLAN ----------------

  void _startNextLeftTrial() {
    if (isGameOver) return;

    if (_trialIndex >= _totalTrials) {
      _finishGame();
      return;
    }

    // UPDATE "remainingSeconds" display (trials left)
    setState(() {
      remainingSeconds = _totalTrials - _trialIndex;
    });

    // RULE SWITCH CHECK (using precomputed schedule)
    bool didSwitch = _switchIndices.contains(_trialIndex);
    if (didSwitch) {
      _switchRule();
    }

    final bool planIsTarget = _leftTrialPlan[_trialIndex];

    setState(() {
      final Color previousColor = currentStimulusColor;

      bool showTarget;
      Color nextColor;

      if (planIsTarget) {
        // TARGET TRIAL: color MUST be targetColor (to keep semantics clean)
        showTarget = true;
        nextColor = targetColor;
      } else {
        // DISTRACTOR TRIAL: color must NOT be targetColor or previousColor
        showTarget = false;

        var distractor = colorPalette[rand.nextInt(colorPalette.length)];
        int safety = 0;
        while ((distractor['color'] == targetColor ||
            distractor['color'] == previousColor) &&
            safety < 10) {
          distractor = colorPalette[rand.nextInt(colorPalette.length)];
          safety++;
        }
        nextColor = distractor['color'];
      }

      // --- RULE-CONFLICT FLAG (only meaningful on post-switch trial) ---
      bool isRuleConflict = false;
      if (didSwitch) {
        final bool shouldTapOld = (nextColor == _prevTargetColor);
        final bool shouldTapNew = (nextColor == targetColor);
        isRuleConflict = (shouldTapOld != shouldTapNew);
      }

      currentStimulusColor = nextColor;
      isTargetActive = showTarget;

      _hasActiveLeftTrial = true;
      _leftTrialWasTarget = planIsTarget; // aligned with plan
      _leftTrialResponded = false;
      _leftTrialIsPostSwitch = didSwitch;
      _leftTrialIsRuleConflict = isRuleConflict;
    });

    // Trial duration: normal vs first after switch.
    final int thisTrialDurationMs =
    didSwitch ? _trialDurationMs + _postSwitchExtraMs : _trialDurationMs;

    _leftTimer?.cancel();
    _leftTimer = Timer(
      Duration(milliseconds: thisTrialDurationMs),
      _closeTrialAndScheduleNext,
    );
  }

  void _closeTrialAndScheduleNext() {
    if (isGameOver) return;

    _finalizeLeftTrial();
    _trialIndex++;
    _startNextLeftTrial();
  }

  void _switchRule() {
    // Remember old target for conflict detection
    _prevTargetColor = targetColor;

    var newTarget = colorPalette[rand.nextInt(colorPalette.length)];
    while (newTarget['color'] == targetColor) {
      newTarget = colorPalette[rand.nextInt(colorPalette.length)];
    }
    targetColor = newTarget['color'];
    targetName = newTarget['name'];
  }

  void _finalizeLeftTrial() {
    if (!_hasActiveLeftTrial) return;

    bool correct;

    if (_leftTrialWasTarget) {
      _leftTargets++;
      if (_leftTrialResponded) {
        _leftHitsT++;
        correct = true;
      } else {
        leftMisses++;
        correct = false;
      }
    } else {
      _leftDistractors++;
      if (_leftTrialResponded) {
        leftFalseAlarms++;
        correct = false;
      } else {
        _leftCorrectRejections++;
        correct = true;
      }
    }

    _leftTrialCorrect.add(correct);
    _leftTrialPostSwitch.add(_leftTrialIsPostSwitch);
    _leftTrialRuleConflict.add(_leftTrialIsRuleConflict);

    _hasActiveLeftTrial = false;
  }

  void _triggerTapFeedback(Color color) {
    _tapFeedbackActive = true;
    _tapFeedbackColor = color;
    Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() {
        _tapFeedbackActive = false;
      });
    });
  }

  void _onLeftTap() {
    if (isGameOver) return;

    // No active trial → ignore silently (no ring)
    if (!_hasActiveLeftTrial) {
      return;
    }

    // Already responded in this trial → ignore
    if (_leftTrialResponded) {
      return;
    }

    final bool trialIsTarget = _leftTrialWasTarget;

    setState(() {
      _leftTrialResponded = true;

      if (trialIsTarget) {
        leftHits++;
        HapticFeedback.mediumImpact();
        _triggerTapFeedback(Colors.greenAccent.withOpacity(0.8));
      } else {
        HapticFeedback.heavyImpact();
        _triggerTapFeedback(Colors.redAccent.withOpacity(0.8));
      }
    });
  }

  // ---------------- RIGHT: MATH STREAM ----------------
  //
  // Very easy: single digit add/sub only, small offsets on distractors.

  void _nextMathProblem() {
    final int op = rand.nextInt(2); // 0: Add, 1: Sub
    int a, b, correct;
    String sign;

    if (op == 0) {
      // Easy addition: 1–9 + 1–9 (2..18)
      a = rand.nextInt(9) + 1;
      b = rand.nextInt(9) + 1;
      correct = a + b;
      sign = "+";
    } else {
      // Easy subtraction: a - b, 0–9, result >= 0
      a = rand.nextInt(10); // 0..9
      b = rand.nextInt(a + 1); // 0..a
      correct = a - b;
      sign = "-";
    }

    final Set<int> opts = {correct};
    while (opts.length < 3) {
      final int delta = rand.nextInt(3) + 1; // 1..3
      final bool add = rand.nextBool();
      int candidate = add ? correct + delta : correct - delta;
      if (candidate < 0) candidate = correct + delta;
      opts.add(candidate);
    }

    setState(() {
      mathQuestion = "$a $sign $b";
      mathAnswer = correct;
      mathOptions = opts.toList()..shuffle();
    });
  }

  void _onRightTap(int selection) {
    if (isGameOver) return;

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
      leftTrialRuleConflict: _leftTrialRuleConflict,
      mathHits: mathHits,
      mathWrongs: mathWrongs,
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
              const Icon(Icons.splitscreen,
                  color: Colors.blue, size: 80),
              const SizedBox(height: 20),
              const Text(
                "Split Stream Done!",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 10),
              Text(
                "Visual Hits: $leftHits  |  Math Solved: $mathHits",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
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
                  color: remainingSeconds <= 5
                      ? Colors.red
                      : Colors.indigo,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const Text(
                      "TAP ON:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: targetColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        targetName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration:
                            const Duration(milliseconds: 180),
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: currentStimulusColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black12,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: currentStimulusColor ==
                                      Colors.grey[200]
                                      ? Colors.transparent
                                      : currentStimulusColor
                                      .withOpacity(0.6),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                          ),
                          if (_tapFeedbackActive)
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _tapFeedbackColor,
                                  width: 6,
                                ),
                              ),
                            ),
                        ],
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
                  const Text(
                    "SOLVE",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    child: Text(
                      mathQuestion,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: mathOptions.map((opt) {
                      return Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 6.0),
                        child: ElevatedButton(
                          onPressed: () => _onRightTap(opt),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            backgroundColor: Colors.indigo[50],
                            foregroundColor: Colors.indigo,
                            elevation: 0,
                            side: BorderSide(
                              color: Colors.indigo[100]!,
                            ),
                          ),
                          child: Text(
                            "$opt",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
