// lib/games/signal_decode_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignalDecodeGame extends StatefulWidget {
  const SignalDecodeGame({Key? key}) : super(key: key);

  @override
  State<SignalDecodeGame> createState() => _SignalDecodeGameState();
}

enum _Phase { learning, trials, done }
enum _TrialType { simpleRT, spatial, emotion, memory, balance }

class _Trial {
  final _TrialType type;
  final String prompt;

  // For multiple-choice trials
  final List<String> options;
  final int correctIndex;

  // For rendering helpers
  final _SpatialStimulus? spatial;
  final _BalanceStimulus? balance;
  final String? emoji;

  _Trial({
    required this.type,
    required this.prompt,
    this.options = const [],
    this.correctIndex = 0,
    this.spatial,
    this.balance,
    this.emoji,
  });
}

class _SpatialStimulus {
  final int gridSize;
  final Point<int> start;
  final Point<int> target;

  const _SpatialStimulus({
    required this.gridSize,
    required this.start,
    required this.target,
  });
}

class _BalanceStimulus {
  final int gridSize;
  final List<Set<int>> patterns; // 3 options
  final int correctIndex;

  const _BalanceStimulus({
    required this.gridSize,
    required this.patterns,
    required this.correctIndex,
  });
}

class _SignalDecodeGameState extends State<SignalDecodeGame> {
  final Random rand = Random();

  // --- GAME FLOW ---
  _Phase phase = _Phase.learning;
  bool isGameOver = false;

  Timer? _gameTimer;
  Timer? _phaseTimer;
  Timer? _trialTimeoutTimer;

  int remainingSeconds = 40;

  // --- LEARNING (Associative Memory encoding) ---
  // 4 symbol -> code pairs shown in the learning phase, then queried later.
  late final List<String> _symbols;
  late final List<String> _codes;
  late final Map<String, String> _symbolToCode;

  // --- TRIALS ---
  final List<_Trial> _trialQueue = [];
  int _trialIndex = 0;

  _Trial? _currentTrial;
  int _trialStartMs = 0;

  // --- TRACKING (Missing Skills) ---
  // Reaction Time (Simple)
  int _rtSimpleTotal = 0;
  int _rtSimpleHits = 0;
  final List<int> _rtSimpleRTs = [];

  // Spatial Awareness
  int _spatialTotal = 0;
  int _spatialCorrect = 0;
  final List<int> _spatialRTs = [];

  // Emotion Recognition
  int _emotionTotal = 0;
  int _emotionCorrect = 0;
  final List<int> _emotionRTs = [];

  // Associative Memory
  int _memoryTotal = 0;
  int _memoryCorrect = 0;
  final List<int> _memoryRTs = [];

  // Aesthetic Balance
  int _balanceTotal = 0;
  int _balanceCorrect = 0;
  final List<int> _balanceRTs = [];

  @override
  void initState() {
    super.initState();

    _symbols = const ["▲", "●", "■", "★"];
    _codes = _makeCodes(4);
    _symbolToCode = {
      _symbols[0]: _codes[0],
      _symbols[1]: _codes[1],
      _symbols[2]: _codes[2],
      _symbols[3]: _codes[3],
    };

    _buildTrialQueue();
    _startGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _phaseTimer?.cancel();
    _trialTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _finishGame();
      }
    });

    // Learning phase lasts 6 seconds, then we start trials automatically.
    _phaseTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || isGameOver) return;
      setState(() => phase = _Phase.trials);
      _advanceToNextTrial();
    });
  }

  void _finishGame() {
    _gameTimer?.cancel();
    _phaseTimer?.cancel();
    _trialTimeoutTimer?.cancel();
    if (!mounted) return;
    setState(() {
      isGameOver = true;
      phase = _Phase.done;
    });
  }

  // ------------------------------
  // TRIAL ENGINE
  // ------------------------------
  void _buildTrialQueue() {
    // Balanced evidence collection:
    // 5 types × 4 trials each = 20 trials
    final types = <_TrialType>[];
    for (int i = 0; i < 4; i++) {
      types.addAll([
        _TrialType.simpleRT,
        _TrialType.spatial,
        _TrialType.emotion,
        _TrialType.memory,
        _TrialType.balance,
      ]);
    }
    types.shuffle(rand);

    for (final type in types) {
      _trialQueue.add(_makeTrial(type));
    }
  }

  void _advanceToNextTrial() {
    _trialTimeoutTimer?.cancel();

    if (isGameOver) return;
    if (_trialIndex >= _trialQueue.length) {
      _finishGame();
      return;
    }

    _currentTrial = _trialQueue[_trialIndex];
    _trialIndex++;

    _trialStartMs = DateTime.now().millisecondsSinceEpoch;

    // Timeouts: keep it simple and defensible.
    // - Simple RT: tight window (1200ms)
    // - Others: reasonable decision window (4500ms)
    final timeout = (_currentTrial!.type == _TrialType.simpleRT)
        ? const Duration(milliseconds: 1200)
        : const Duration(milliseconds: 4500);

    _trialTimeoutTimer = Timer(timeout, () {
      // No response => record miss/incorrect and proceed
      if (!mounted || isGameOver || phase != _Phase.trials) return;
      _recordNoResponse(_currentTrial!);
      _advanceToNextTrial();
    });

    setState(() {});
  }

  void _answerChoice(int selectedIndex) {
    final trial = _currentTrial;
    if (trial == null || isGameOver || phase != _Phase.trials) return;

    _trialTimeoutTimer?.cancel();
    final rt = DateTime.now().millisecondsSinceEpoch - _trialStartMs;
    final correct = selectedIndex == trial.correctIndex;

    if (correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    // Record by trial type
    switch (trial.type) {
      case _TrialType.spatial:
        _spatialTotal++;
        if (correct) _spatialCorrect++;
        _spatialRTs.add(rt);
        break;
      case _TrialType.emotion:
        _emotionTotal++;
        if (correct) _emotionCorrect++;
        _emotionRTs.add(rt);
        break;
      case _TrialType.memory:
        _memoryTotal++;
        if (correct) _memoryCorrect++;
        _memoryRTs.add(rt);
        break;
      case _TrialType.balance:
        _balanceTotal++;
        if (correct) _balanceCorrect++;
        _balanceRTs.add(rt);
        break;
      case _TrialType.simpleRT:
      // Simple RT is handled by tap-anywhere instead of options
        break;
    }

    _advanceToNextTrial();
  }

  void _onSimpleTap() {
    final trial = _currentTrial;
    if (trial == null || isGameOver || phase != _Phase.trials) return;
    if (trial.type != _TrialType.simpleRT) return;

    _trialTimeoutTimer?.cancel();
    final rt = DateTime.now().millisecondsSinceEpoch - _trialStartMs;

    _rtSimpleTotal++;
    // Any tap within window counts as hit; timer would have fired otherwise.
    _rtSimpleHits++;
    _rtSimpleRTs.add(rt);

    HapticFeedback.lightImpact();
    _advanceToNextTrial();
  }

  void _recordNoResponse(_Trial trial) {
    // No response within time window
    switch (trial.type) {
      case _TrialType.simpleRT:
        _rtSimpleTotal++;
        // miss (no hit, no RT)
        break;
      case _TrialType.spatial:
        _spatialTotal++;
        break;
      case _TrialType.emotion:
        _emotionTotal++;
        break;
      case _TrialType.memory:
        _memoryTotal++;
        break;
      case _TrialType.balance:
        _balanceTotal++;
        break;
    }
  }

  // ------------------------------
  // SCORING
  // ------------------------------
  Map<String, dynamic> grade() {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    double? medianScaledScore({
      required List<int> rts,
      required double bestMs,
      required double worstMs,
    }) {
      if (rts.isEmpty) return null;
      final sorted = List<int>.from(rts)..sort();
      final mid = sorted.length ~/ 2;
      final double median = sorted.length.isOdd
          ? sorted[mid].toDouble()
          : ((sorted[mid - 1] + sorted[mid]) / 2.0);

      final raw = 1.0 - ((median - bestMs) / (worstMs - bestMs));
      return clamp01(raw);
    }

    double? accuracyScore({
      required int correct,
      required int total,
      required int minEvidence,
    }) {
      if (total <= 0) return null;
      final acc = clamp01(correct / total);
      final gate = clamp01(total / minEvidence);
      return clamp01(acc * gate);
    }

    double? accuracyWithSpeed({
      required int correct,
      required int total,
      required int minEvidence,
      required List<int> rts,
      required double bestMs,
      required double worstMs,
      double speedWeight = 0.25, // conservative
    }) {
      final acc = accuracyScore(correct: correct, total: total, minEvidence: minEvidence);
      if (acc == null) return null;

      final sp = medianScaledScore(rts: rts, bestMs: bestMs, worstMs: worstMs);
      if (sp == null) return acc; // if no RTs, keep accuracy-only

      final combined = (1.0 - speedWeight) * acc + speedWeight * sp;
      return clamp01(combined);
    }

    // --- Reaction Time (Simple) ---
    // Requires enough alerts to be credible.
    // Score based on median RT + miss rate.
    double? reactionTimeSimple;
    {
      if (_rtSimpleTotal >= 4 && _rtSimpleRTs.length >= 2) {
        final missRate = 1.0 - (_rtSimpleHits / _rtSimpleTotal).clamp(0.0, 1.0);
        final speed = medianScaledScore(rts: _rtSimpleRTs, bestMs: 250.0, worstMs: 1200.0) ?? 0.0;

        // Evidence gate (don't reward 1 alert)
        final gate = clamp01(_rtSimpleTotal / 6.0);

        // Penalize misses, but keep conservative scaling
        reactionTimeSimple = clamp01(speed * (1.0 - 0.5 * missRate) * gate);
      } else {
        reactionTimeSimple = null;
      }
    }

    // --- Spatial Awareness ---
    final spatial = accuracyWithSpeed(
      correct: _spatialCorrect,
      total: _spatialTotal,
      minEvidence: 6,
      rts: _spatialRTs,
      bestMs: 650.0,
      worstMs: 4500.0,
      speedWeight: 0.20,
    );

    // --- Emotion Recognition ---
    final emotion = accuracyWithSpeed(
      correct: _emotionCorrect,
      total: _emotionTotal,
      minEvidence: 6,
      rts: _emotionRTs,
      bestMs: 650.0,
      worstMs: 4500.0,
      speedWeight: 0.15,
    );

    // --- Associative Memory (accuracy-dominant) ---
    final memory = accuracyWithSpeed(
      correct: _memoryCorrect,
      total: _memoryTotal,
      minEvidence: 6,
      rts: _memoryRTs,
      bestMs: 900.0,
      worstMs: 6000.0,
      speedWeight: 0.10,
    );

    // --- Aesthetic Balance ---
    final balance = accuracyWithSpeed(
      correct: _balanceCorrect,
      total: _balanceTotal,
      minEvidence: 6,
      rts: _balanceRTs,
      bestMs: 700.0,
      worstMs: 4500.0,
      speedWeight: 0.20,
    );

    return {
      "Reaction Time (Simple)": reactionTimeSimple,
      "Spatial Awareness": spatial,
      "Emotion Recognition": emotion,
      "Associative Memory": memory,
      "Aesthetic Balance": balance,
    };
  }

  // ------------------------------
  // TRIAL GENERATORS
  // ------------------------------
  _Trial _makeTrial(_TrialType type) {
    switch (type) {
      case _TrialType.simpleRT:
        return _Trial(
          type: type,
          prompt: "ALERT! TAP NOW",
        );

      case _TrialType.emotion:
        final emotions = const [
          ("🙂", "HAPPY"),
          ("😡", "ANGRY"),
          ("😢", "SAD"),
          ("😲", "SURPRISED"),
        ];
        final pick = emotions[rand.nextInt(emotions.length)];
        final correctLabel = pick.$2;

        final options = emotions.map((e) => e.$2).toList()..shuffle(rand);
        final correctIndex = options.indexOf(correctLabel);

        return _Trial(
          type: type,
          prompt: "Identify the emotion",
          emoji: pick.$1,
          options: options,
          correctIndex: correctIndex,
        );

      case _TrialType.spatial:
        final stim = _makeSpatialStimulus();
        final dir = _directionLabel(stim.start, stim.target);

        const options = ["UP", "DOWN", "LEFT", "RIGHT"];
        final correctIndex = options.indexOf(dir);

        return _Trial(
          type: type,
          prompt: "Where is TARGET relative to START?",
          spatial: stim,
          options: options,
          correctIndex: correctIndex,
        );

      case _TrialType.memory:
      // Ask: which CODE belongs to this SYMBOL?
        final symbol = _symbols[rand.nextInt(_symbols.length)];
        final correctCode = _symbolToCode[symbol]!;
        final options = <String>{correctCode};

        while (options.length < 4) {
          options.add(_codes[rand.nextInt(_codes.length)]);
        }

        final optList = options.toList()..shuffle(rand);
        final correctIndex = optList.indexOf(correctCode);

        return _Trial(
          type: type,
          prompt: "Recall the CODE for this symbol:  $symbol",
          options: optList,
          correctIndex: correctIndex,
        );

      case _TrialType.balance:
        final stim = _makeBalanceStimulus();
        return _Trial(
          type: type,
          prompt: "Pick the most BALANCED layout",
          balance: stim,
          options: const ["A", "B", "C"],
          correctIndex: stim.correctIndex,
        );
    }
  }

  _SpatialStimulus _makeSpatialStimulus() {
    const gridSize = 5;

    // Ensure target is not diagonal (same row or same column).
    final start = Point<int>(rand.nextInt(gridSize), rand.nextInt(gridSize));

    bool sameRow = rand.nextBool();
    Point<int> target;

    if (sameRow) {
      int tx = start.x;
      int ty = start.y;
      while (ty == start.y) {
        ty = rand.nextInt(gridSize);
      }
      target = Point<int>(tx, ty);
    } else {
      int tx = start.x;
      int ty = start.y;
      while (tx == start.x) {
        tx = rand.nextInt(gridSize);
      }
      target = Point<int>(tx, ty);
    }

    return _SpatialStimulus(gridSize: gridSize, start: start, target: target);
  }

  String _directionLabel(Point<int> start, Point<int> target) {
    if (target.x == start.x) {
      return target.y < start.y ? "UP" : "DOWN";
    } else {
      return target.x < start.x ? "LEFT" : "RIGHT";
    }
  }

  _BalanceStimulus _makeBalanceStimulus() {
    const gridSize = 5;

    // Create one objectively symmetric pattern (vertical symmetry),
    // then create two "near misses" by introducing a small asymmetry.
    final balanced = _makeVerticallySymmetricPattern(gridSize, dots: 8);

    final almost1 = Set<int>.from(balanced);
    _introduceAsymmetry(almost1, gridSize);

    final almost2 = Set<int>.from(balanced);
    _introduceAsymmetry(almost2, gridSize);

    final patterns = [balanced, almost1, almost2]..shuffle(rand);
    final correctIndex = patterns.indexWhere((p) => _isVerticallySymmetric(p, gridSize));

    return _BalanceStimulus(
      gridSize: gridSize,
      patterns: patterns,
      correctIndex: correctIndex < 0 ? 0 : correctIndex,
    );
  }

  Set<int> _makeVerticallySymmetricPattern(int n, {required int dots}) {
    final set = <int>{};

    // Add symmetric pairs
    while (set.length < dots) {
      final x = rand.nextInt((n + 1) ~/ 2); // left half
      final y = rand.nextInt(n);

      final xMirror = (n - 1) - x;

      set.add(y * n + x);
      set.add(y * n + xMirror);

      // If we overshoot too much, trim randomly
      while (set.length > dots) {
        set.remove(set.elementAt(rand.nextInt(set.length)));
      }
    }
    return set;
  }

  void _introduceAsymmetry(Set<int> pattern, int n) {
    if (pattern.isEmpty) return;
    // Remove or add a single dot on one side only
    if (rand.nextBool() && pattern.length >= 2) {
      final idx = pattern.elementAt(rand.nextInt(pattern.length));
      pattern.remove(idx);
    } else {
      // add a dot that breaks symmetry
      int tries = 0;
      while (tries < 50) {
        final x = rand.nextInt(n);
        final y = rand.nextInt(n);
        final idx = y * n + x;
        final mirror = y * n + ((n - 1) - x);
        if (!pattern.contains(idx) && pattern.contains(mirror)) {
          pattern.add(idx); // break symmetry
          return;
        }
        tries++;
      }
      // fallback: add any dot
      pattern.add(rand.nextInt(n * n));
    }
  }

  bool _isVerticallySymmetric(Set<int> pattern, int n) {
    for (final idx in pattern) {
      final y = idx ~/ n;
      final x = idx % n;
      final mirror = y * n + ((n - 1) - x);
      if (!pattern.contains(mirror)) return false;
    }
    return true;
  }

  List<String> _makeCodes(int count) {
    const letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // avoid confusing chars
    final codes = <String>[];
    while (codes.length < count) {
      final a = letters[rand.nextInt(letters.length)];
      final b = letters[rand.nextInt(letters.length)];
      final code = "$a$b";
      if (!codes.contains(code)) codes.add(code);
    }
    return codes;
  }

  // ------------------------------
  // UI
  // ------------------------------
  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      final scores = grade();
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.radar, color: Colors.tealAccent, size: 80),
                const SizedBox(height: 14),
                const Text("Signal Decode Complete",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  "RT Alerts: $_rtSimpleHits/$_rtSimpleTotal  |  Spatial: $_spatialCorrect/$_spatialTotal\n"
                      "Emotion: $_emotionCorrect/$_emotionTotal  |  Memory: $_memoryCorrect/$_memoryTotal  |  Balance: $_balanceCorrect/$_balanceTotal",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    scores.entries
                        .map((e) => "${e.key}: ${e.value == null ? "null" : (e.value as num).toStringAsFixed(2)}")
                        .join("\n"),
                    style: const TextStyle(color: Colors.white70, fontFamily: "Courier", fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(scores);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("NEXT GAME"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("16. Signal Decode ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(null);
            },
            child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
      body: phase == _Phase.learning ? _buildLearning() : _buildTrial(),
    );
  }

  Widget _buildLearning() {
    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link, size: 56, color: Colors.indigo),
          const SizedBox(height: 12),
          const Text(
            "MEMORIZE THE PAIRS",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            "You will be asked to recall these mappings later.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _symbols.map((s) {
              final code = _symbolToCode[s]!;
              return Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Text(s, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            "Starting automatically...",
            style: TextStyle(color: Colors.black45),
          )
        ],
      ),
    );
  }

  Widget _buildTrial() {
    final trial = _currentTrial;
    if (trial == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (trial.type == _TrialType.simpleRT) {
      return InkWell(
        onTap: _onSimpleTap,
        child: Container(
          width: double.infinity,
          color: Colors.black,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                "TAP!",
                style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(trial.prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),

          if (trial.type == _TrialType.emotion && trial.emoji != null) ...[
            Text(trial.emoji!, style: const TextStyle(fontSize: 70)),
            const SizedBox(height: 10),
          ],

          if (trial.type == _TrialType.spatial && trial.spatial != null) ...[
            _SpatialGrid(stimulus: trial.spatial!),
            const SizedBox(height: 12),
          ],

          if (trial.type == _TrialType.balance && trial.balance != null) ...[
            _BalanceOptions(stimulus: trial.balance!),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),
          _buildOptions(trial),
        ],
      ),
    );
  }

  Widget _buildOptions(_Trial trial) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(trial.options.length, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ElevatedButton(
            onPressed: () => _answerChoice(i),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.indigo[50],
              foregroundColor: Colors.indigo,
              elevation: 0,
              side: BorderSide(color: Colors.indigo[100]!),
            ),
            child: Text(
              trial.options[i],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }),
    );
  }
}

class _SpatialGrid extends StatelessWidget {
  final _SpatialStimulus stimulus;
  const _SpatialGrid({required this.stimulus});

  @override
  Widget build(BuildContext context) {
    final n = stimulus.gridSize;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: List.generate(n, (y) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(n, (x) {
              final isStart = stimulus.start.x == x && stimulus.start.y == y;
              final isTarget = stimulus.target.x == x && stimulus.target.y == y;

              Color bg = Colors.white;
              String txt = "";
              if (isStart) { bg = Colors.green.shade200; txt = "S"; }
              if (isTarget) { bg = Colors.red.shade200; txt = "T"; }

              return Container(
                margin: const EdgeInsets.all(3),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w900)),
              );
            }),
          );
        }),
      ),
    );
  }
}

class _BalanceOptions extends StatelessWidget {
  final _BalanceStimulus stimulus;
  const _BalanceOptions({required this.stimulus});

  @override
  Widget build(BuildContext context) {
    final n = stimulus.gridSize;

    Widget grid(Set<int> pattern) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: List.generate(n, (y) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(n, (x) {
                final idx = y * n + x;
                final filled = pattern.contains(idx);
                return Container(
                  margin: const EdgeInsets.all(2),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.indigo : Colors.transparent,
                    border: Border.all(color: Colors.black12),
                  ),
                );
              }),
            );
          }),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(children: [const Text("A"), const SizedBox(height: 6), grid(stimulus.patterns[0])]),
        Column(children: [const Text("B"), const SizedBox(height: 6), grid(stimulus.patterns[1])]),
        Column(children: [const Text("C"), const SizedBox(height: 6), grid(stimulus.patterns[2])]),
      ],
    );
  }
}
