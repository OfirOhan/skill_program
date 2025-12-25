// lib/games/signal_decode_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- CONFIGURATION ---
const String kAssetPrefix = "assets/pictures/emotions/";

class SignalDecodeGame extends StatefulWidget {
  const SignalDecodeGame({Key? key}) : super(key: key);

  @override
  State<SignalDecodeGame> createState() => _SignalDecodeGameState();
}

enum _Phase { learning, trials, done }
enum _TrialType { simpleRT, spatial, emotion, memory, balance }
enum _FaceType { typeA, typeB, typeC, typeD }

class _SignalDecodeGameState extends State<SignalDecodeGame> {
  // --- THEME COLORS ---
  final Color colPrimary = const Color(0xFF3F51B5); // Indigo
  final Color colAccent = const Color(0xFF009688);  // Teal
  final Color colBackground = const Color(0xFFF0F2F5);
  final Color colSurface = Colors.white;
  final Color colText = const Color(0xFF2D3436);

  final Random rand = Random();

  _Phase phase = _Phase.learning;
  bool isGameOver = false;

  Timer? _phaseTimer;
  Timer? _trialTimeoutTimer;
  Timer? _roundCountdownTimer;
  int _roundSecLeft = 0;

  late final List<String> _symbols;
  late final List<String> _codes;
  late final Map<String, String> _symbolToCode;

  final List<_Trial> _trialQueue = [];
  int _trialIndex = 0;
  _Trial? _currentTrial;
  int _trialStartMs = 0;
  bool _answeredThisTrial = false;
  int _currentTimeoutMs = 0;

  // Tracking vars
  int _rtSimpleTotal = 0; int _rtSimpleHits = 0; final List<int> _rtSimpleRTs = [];
  int _spatialTotal = 0; int _spatialCorrect = 0; final List<int> _spatialRTs = [];
  int _emotionTotal = 0; int _emotionCorrect = 0; final List<int> _emotionRTs = [];
  int _memoryTotal = 0; int _memoryCorrect = 0; final List<int> _memoryRTs = [];
  int _balanceTotal = 0; int _balanceCorrect = 0; final List<int> _balanceRTs = [];

  static const List<_FacePack> _facePool = [
    _FacePack(_FaceType.typeA, "IRRITATED", ["IRRITATED", "CONFUSED", "SUSPICIOUS", "LOST"], "irritated.png"),
    _FacePack(_FaceType.typeB, "ANNOYED", ["ANGRY", "SAD", "ANNOYED", "TIRED"], "annoyed.png"),
    _FacePack(_FaceType.typeC, "NERVOUS", ["EMBARRASSED", "CONFUSED", "SCARED", "NERVOUS"], "nervous.png"),
    _FacePack(_FaceType.typeD, "HOPEFUL", ["HOPEFUL", "HAPPY", "PLEASED", "EXCITED"], "hopeful.png"),
  ];

  @override
  void initState() {
    super.initState();
    _symbols = const ["▲", "●", "■", "★"];
    _codes = _makeCodes(4);
    _symbolToCode = { for (var i=0; i<4; i++) _symbols[i]: _codes[i] };
    _buildTrialQueueFixedNoRepeats();
    _startGame();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _trialTimeoutTimer?.cancel();
    _roundCountdownTimer?.cancel();
    super.dispose();
  }

  // ... [Logic methods kept same for brevity: _startRoundCountdownMs, _startGame, _finishGame, _buildTrialQueue, Generators, Engine, Grading] ...
  // Assuming Logic from previous turn is intact. Focusing on UI build methods below.

  // --- RE-INSERT LOGIC METHODS HERE (Copy/Paste from previous if needed) ---
  // For this output, I will include the core logic needed to run.

  void _startRoundCountdownMs(int durationMs) {
    _roundCountdownTimer?.cancel();
    final deadline = DateTime.now().millisecondsSinceEpoch + durationMs;
    setState(() => _roundSecLeft = (durationMs/1000).ceil());
    _roundCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || isGameOver) return;
      final left = deadline - DateTime.now().millisecondsSinceEpoch;
      final sec = left <= 0 ? 0 : (left/1000).ceil();
      if (sec != _roundSecLeft) setState(() => _roundSecLeft = sec);
    });
  }

  void _startGame() {
    _startRoundCountdownMs(6000);
    _phaseTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !isGameOver) {
        setState(() => phase = _Phase.trials);
        _advanceToNextTrial();
      }
    });
  }

  void _finishGame() {
    _phaseTimer?.cancel();
    _trialTimeoutTimer?.cancel();
    _roundCountdownTimer?.cancel();
    if (mounted) setState(() { isGameOver = true; phase = _Phase.done; });
  }

  void _buildTrialQueueFixedNoRepeats() {
    _trialQueue.clear();
    _trialIndex = 0;
    final types = <_TrialType>[];
    for (int i=0; i<4; i++) types.addAll(_TrialType.values);
    types.shuffle(rand);

    final simplePool = List.generate(4, (_) => _Trial(type: _TrialType.simpleRT, prompt: "ALERT! TAP NOW"));
    final spatialPool = _makeSpatialTrialsUniqueDirections();
    final balancePool = List.generate(4, (_) => _makeBalanceTrial());
    final memoryPool = _makeMemoryTrialsNoRepeatSymbols();
    final emotionPool = _facePool.map((p) => _makeEmotionTrial(p)).toList()..shuffle(rand);

    for (final t in types) {
      if (t == _TrialType.simpleRT) _trialQueue.add(simplePool.removeLast());
      else if (t == _TrialType.spatial) _trialQueue.add(spatialPool.removeLast());
      else if (t == _TrialType.balance) _trialQueue.add(balancePool.removeLast());
      else if (t == _TrialType.memory) _trialQueue.add(memoryPool.removeLast());
      else if (t == _TrialType.emotion) _trialQueue.add(emotionPool.removeLast());
    }
  }

  List<_Trial> _makeSpatialTrialsUniqueDirections() {
    const dirs = ["UP", "DOWN", "LEFT", "RIGHT"];
    return dirs.map((dir) => _Trial(
        type: _TrialType.spatial, prompt: "Where is TARGET relative to START?",
        spatial: _makeSpatialStimulus(dir), options: dirs, correctIndex: dirs.indexOf(dir)
    )).toList()..shuffle(rand);
  }

  _SpatialStimulus _makeSpatialStimulus(String dir) {
    int x = rand.nextInt(5), y = rand.nextInt(5);
    int step = 1 + rand.nextInt(3);
    int tx=x, ty=y;
    if (dir == "UP") { y = max(step, y); ty = y-step; }
    else if (dir == "DOWN") { y = min(4-step, y); ty = y+step; }
    else if (dir == "LEFT") { x = max(step, x); tx = x-step; }
    else { x = min(4-step, x); tx = x+step; }
    return _SpatialStimulus(gridSize: 5, start: Point(x,y), target: Point(tx,ty));
  }

  _Trial _makeEmotionTrial(_FacePack p) {
    final opts = List<String>.from(p.options)..shuffle(rand);
    return _Trial(type: _TrialType.emotion, prompt: "Identify the expression", faceType: p.type, options: opts, correctIndex: opts.indexOf(p.correct));
  }

  List<_Trial> _makeMemoryTrialsNoRepeatSymbols() {
    final syms = List<String>.from(_symbols)..shuffle(rand);
    return syms.map((s) {
      final ans = _symbolToCode[s]!;
      final opts = <String>{ans};
      while(opts.length<4) opts.add(_codes[rand.nextInt(4)]);
      final l = opts.toList()..shuffle(rand);
      return _Trial(type: _TrialType.memory, prompt: "Recall CODE for: $s", options: l, correctIndex: l.indexOf(ans));
    }).toList();
  }

  _Trial _makeBalanceTrial() {
    final stim = _makeBalanceStimulus();
    return _Trial(type: _TrialType.balance, prompt: "Pick BALANCED layout", balance: stim, options: ["A", "B", "C"], correctIndex: stim.correctIndex);
  }

  void _advanceToNextTrial() {
    _trialTimeoutTimer?.cancel();
    if (isGameOver) return;
    if (_trialIndex >= _trialQueue.length) { _finishGame(); return; }

    _currentTrial = _trialQueue[_trialIndex++];
    _answeredThisTrial = false;
    _trialStartMs = DateTime.now().millisecondsSinceEpoch;

    final ms = _currentTrial!.type == _TrialType.simpleRT ? 1200 : 7000;
    _currentTimeoutMs = ms;
    _startRoundCountdownMs(ms);

    _trialTimeoutTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted && !isGameOver && phase == _Phase.trials && !_answeredThisTrial) {
        _recordData(_currentTrial!, -1, false);
        _advanceToNextTrial();
      }
    });
    setState(() {});
  }

  void _handleInput(int choiceIndex, bool isTap) {
    if (isGameOver || phase != _Phase.trials || _answeredThisTrial) return;
    final t = _currentTrial!.type;
    if (isTap && t != _TrialType.simpleRT) return;
    if (!isTap && t == _TrialType.simpleRT) return;

    _answeredThisTrial = true;
    _trialTimeoutTimer?.cancel();
    final rt = DateTime.now().millisecondsSinceEpoch - _trialStartMs;
    bool correct = isTap ? true : (choiceIndex == _currentTrial!.correctIndex);

    if (correct) HapticFeedback.mediumImpact(); else HapticFeedback.heavyImpact();
    _recordData(_currentTrial!, rt, correct);
    _advanceToNextTrial();
  }

  void _recordData(_Trial t, int rt, bool correct) {
    final r = (rt == -1) ? _currentTimeoutMs : rt;
    switch(t.type) {
      case _TrialType.simpleRT: _rtSimpleTotal++; _rtSimpleRTs.add(r); if(correct) _rtSimpleHits++; break;
      case _TrialType.spatial: _spatialTotal++; _spatialRTs.add(r); if(correct) _spatialCorrect++; break;
      case _TrialType.emotion: _emotionTotal++; _emotionRTs.add(r); if(correct) _emotionCorrect++; break;
      case _TrialType.memory: _memoryTotal++; _memoryRTs.add(r); if(correct) _memoryCorrect++; break;
      case _TrialType.balance: _balanceTotal++; _balanceRTs.add(r); if(correct) _balanceCorrect++; break;
    }
  }

  Map<String, double> grade() {
    double calc(int cor, int tot, List<int> rts, double best, double worst) {
      if (tot == 0) return 0.0;
      double acc = cor / tot;
      if (rts.isEmpty) return acc;
      rts.sort();
      double med = rts[rts.length~/2].toDouble();
      double sp = (1.0 - (med - best)/(worst - best)).clamp(0.0, 1.0);
      return (acc * 0.8 + sp * 0.2).clamp(0.0, 1.0);
    }
    double rtScore = 0.0;
    if (_rtSimpleTotal > 0 && _rtSimpleRTs.isNotEmpty) {
      _rtSimpleRTs.sort();
      double med = _rtSimpleRTs[_rtSimpleRTs.length~/2].toDouble();
      double sp = (1.0 - (med - 350)/1050).clamp(0.0, 1.0);
      double acc = _rtSimpleHits / _rtSimpleTotal;
      rtScore = sp * acc;
    }
    return {
      "Reaction Time (Simple)": double.parse(rtScore.toStringAsFixed(2)),
      "Spatial Awareness": double.parse(calc(_spatialCorrect, _spatialTotal, _spatialRTs, 600, 7000).toStringAsFixed(2)),
      "Emotion Recognition": double.parse(calc(_emotionCorrect, _emotionTotal, _emotionRTs, 600, 7000).toStringAsFixed(2)),
      "Associative Memory": double.parse(calc(_memoryCorrect, _memoryTotal, _memoryRTs, 800, 7000).toStringAsFixed(2)),
      "Aesthetic Balance": double.parse(calc(_balanceCorrect, _balanceTotal, _balanceRTs, 700, 7000).toStringAsFixed(2)),
    };
  }

  List<String> _makeCodes(int n) {
    final l = "ABCDEFGHJKLMNPQRSTUVWXYZ".split('')..shuffle();
    return List.generate(n, (i) => "${l[i]}${l[(i+1)%l.length]}");
  }

  _BalanceStimulus _makeBalanceStimulus() {
    const gridSize = 5;
    final balanced = _makeVerticallySymmetricPattern(gridSize, dots: 8);
    Set<int> makeClone() {
      Set<int> p; int g = 0;
      do { p = Set.from(balanced); _introduceAsymmetry(p, gridSize); g++; }
      while (_isVerticallySymmetric(p, gridSize) && g < 30);
      return p;
    }
    final patterns = [balanced, makeClone(), makeClone()]..shuffle(rand);
    return _BalanceStimulus(gridSize: 5, patterns: patterns, correctIndex: patterns.indexWhere((p) => _isVerticallySymmetric(p, gridSize)));
  }

  Set<int> _makeVerticallySymmetricPattern(int n, {required int dots}) {
    final set = <int>{};
    final leftMax = (n ~/ 2) - 1;
    final targetDots = dots.isOdd ? (dots - 1) : dots;
    while (set.length < targetDots) {
      final x = rand.nextInt(leftMax + 1);
      final y = rand.nextInt(n);
      set.add(y * n + x); set.add(y * n + (n - 1) - x);
      while (set.length > targetDots) set.remove(set.elementAt(rand.nextInt(set.length)));
    }
    return set;
  }

  void _introduceAsymmetry(Set<int> pattern, int n) {
    if (pattern.isEmpty) return;
    if (rand.nextBool() && pattern.length >= 2) {
      pattern.remove(pattern.elementAt(rand.nextInt(pattern.length)));
      if (_isVerticallySymmetric(pattern, n) && pattern.isNotEmpty) pattern.remove(pattern.elementAt(rand.nextInt(pattern.length)));
      return;
    }
    pattern.add(rand.nextInt(n * n));
  }

  bool _isVerticallySymmetric(Set<int> pattern, int n) {
    for (final idx in pattern) {
      final y = idx ~/ n; final x = idx % n;
      if (!pattern.contains(y * n + (n - 1) - x)) return false;
    }
    return true;
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      final s = grade();
      return Scaffold(
          backgroundColor: Colors.black87,
          body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.radar, color: Colors.tealAccent, size: 80),
            const SizedBox(height: 20),
            const Text("ANALYSIS COMPLETE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            _ScoreRow("Reaction Speed", s["Reaction Time (Simple)"]!),
            _ScoreRow("Spatial Logic", s["Spatial Awareness"]!),
            _ScoreRow("Emotion Decode", s["Emotion Recognition"]!),
            _ScoreRow("Memory Recall", s["Associative Memory"]!),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, s),
              style: ElevatedButton.styleFrom(backgroundColor: colPrimary, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: const Text("FINISH", style: TextStyle(fontSize: 16)),
            )
          ]))
      );
    }

    return Scaffold(
      backgroundColor: colBackground,
      appBar: AppBar(
        title: const Text("Signal Decode"),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                "${_roundSecLeft}s",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _roundSecLeft < 3 ? Colors.red : colPrimary),
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: phase == _Phase.trials && _currentTrial?.type == _TrialType.simpleRT,
      body: (phase == _Phase.trials && _currentTrial?.type == _TrialType.simpleRT)
          ? _buildTrial() // No SafeArea for RT test = full screen click area
          : SafeArea(child: phase == _Phase.learning ? _buildLearning() : _buildTrial()),
    );
  }

  Widget _buildLearning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.memory, size: 60, color: colPrimary),
          const SizedBox(height: 10),
          const Text("MEMORIZE CODES", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 30),
          Wrap(
            spacing: 15, runSpacing: 15,
            alignment: WrapAlignment.center,
            children: List.generate(4, (i) =>
                Container(
                  width: 140, padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))]),
                  child: Column(children: [
                    Text(_symbols[i], style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 5),
                    Text(_codes[i], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colPrimary))
                  ]),
                )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrial() {
    final t = _currentTrial!;

    // --- SIMPLE RT (RED SCREEN) ---
    // --- SIMPLE RT (RED SCREEN) ---
    if (t.type == _TrialType.simpleRT) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _handleInput(-1, true),
        child: Container(
          color: const Color(0xFF111111),
          // No SafeArea for this mode to catch clicks everywhere
          child: SizedBox.expand(
            child: Center(
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 40)]
                ),
                child: const Center(
                  child: Text("TAP!",
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- MAIN GAME UI ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Prompt Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Text(t.prompt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),

          // Stimulus Area
          if (t.type == _TrialType.emotion)
            _FaceCard(faceType: t.faceType!),

          if (t.type == _TrialType.spatial && t.spatial != null)
            _SpatialGrid(stimulus: t.spatial!),

          if (t.type == _TrialType.balance && t.balance != null)
            _BalanceOptions(stimulus: t.balance!),

          if (t.type == _TrialType.memory)
            Icon(Icons.help_outline, size: 80, color: Colors.grey.shade400),

          const SizedBox(height: 30),

          // Options Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: List.generate(t.options.length, (i) =>
                _OptionButton(
                    label: t.options[i],
                    onTap: () => _handleInput(i, false),
                    color: colPrimary
                )
            ),
          )
        ],
      ),
    );
  }
}

// --- STYLED WIDGETS ---

class _FaceCard extends StatelessWidget {
  final _FaceType faceType;
  const _FaceCard({required this.faceType});
  @override
  Widget build(BuildContext context) {
    final pack = _SignalDecodeGameState._facePool.firstWhere((p) => p.type == faceType);
    return Container(
      height: 220,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Center(
        child: Image.asset(
          "$kAssetPrefix${pack.fileName}",
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      ),
    );
  }
}

class _SpatialGrid extends StatelessWidget {
  final _SpatialStimulus stimulus;
  const _SpatialGrid({required this.stimulus});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220, height: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
      child: GridView.count(
        crossAxisCount: 5,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(25, (i) {
          int x = i%5, y = i~/5;
          bool isStart = x==stimulus.start.x && y==stimulus.start.y;
          bool isTarget = x==stimulus.target.x && y==stimulus.target.y;
          Color? bg;
          if(isStart) bg = Colors.greenAccent;
          if(isTarget) bg = Colors.redAccent;
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: bg ?? Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text(isStart ? "S" : (isTarget ? "T" : ""), style: const TextStyle(fontWeight: FontWeight.bold))),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) =>
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(children: [
              Text(["A","B","C"][i], style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _MiniGrid(pattern: stimulus.patterns[i], gridSize: 5)
            ]),
          )
      ),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  final Set<int> pattern;
  final int gridSize;
  const _MiniGrid({required this.pattern, required this.gridSize});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
      child: GridView.count(
        crossAxisCount: gridSize,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(gridSize*gridSize, (i) =>
            Container(
                margin: const EdgeInsets.all(1),
                color: pattern.contains(i) ? Colors.black87 : Colors.grey.shade50
            )
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _OptionButton({required this.label, required this.onTap, required this.color});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.2), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double value;
  const _ScoreRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: 280,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// Data Classes (re-declared for standalone compilation)
class _Trial {
  final _TrialType type; final String prompt; final List<String> options; final int correctIndex;
  final _SpatialStimulus? spatial; final _BalanceStimulus? balance; final _FaceType? faceType;
  _Trial({required this.type, required this.prompt, this.options=const[], this.correctIndex=0, this.spatial, this.balance, this.faceType});
}
class _SpatialStimulus { final int gridSize; final Point<int> start; final Point<int> target; const _SpatialStimulus({required this.gridSize, required this.start, required this.target}); }
class _BalanceStimulus { final int gridSize; final List<Set<int>> patterns; final int correctIndex; const _BalanceStimulus({required this.gridSize, required this.patterns, required this.correctIndex}); }
class _FacePack { final _FaceType type; final String correct; final List<String> options; final String fileName; const _FacePack(this.type, this.correct, this.options, this.fileName); }