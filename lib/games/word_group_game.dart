// lib/games/semantic_sieve_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WordGroupsGame extends StatefulWidget {
  const WordGroupsGame({Key? key}) : super(key: key);

  @override
  State<WordGroupsGame> createState() => _SemanticSieveGameState();
}

class _SemanticSieveGameState extends State<WordGroupsGame> {
  // --- THEME COLORS ---
  final Color colPrimary = const Color(0xFF3F51B5); // Indigo
  final Color colAccent = const Color(0xFF00E5FF);  // Teal/Cyan
  final Color colBackground = const Color(0xFFF0F2F5);
  final Color colText = const Color(0xFF2D3436);

  final Random rand = Random();

  // --- GAME STATE ---
  bool _isGameOver = false;
  int _roundIndex = 0;
  final int _maxRounds = 5; // Kept at 5 rounds

  // Timer (Now Per Round)
  Timer? _roundTimer;
  int _currentRoundSeconds = 10; // 10s per round

  // Data Queue
  List<_WordSet> _sessionQueue = [];

  // Current Round Data
  late _WordSet _currentSet;
  List<String> _shuffledOptions = [];
  int _roundStartTime = 0;

  // Interaction State
  bool _isTransitioning = false;

  // Scoring
  int _scoreCorrect = 0;
  List<int> _reactionTimes = [];

  // --- DATA POOL ---
  final List<_WordSet> _masterPool = [
    _WordSet(
        category: "Money",
        words: ["Frugal", "Thrifty", "Economical"],
        oddOne: "Miserly",
        reason: "Three imply smart saving.\n'Miserly' implies greed (negative)."
    ),
    _WordSet(
        category: "Fame",
        words: ["Famous", "Renowned", "Celebrated"],
        oddOne: "Notorious",
        reason: "Three are famous for good reasons.\n'Notorious' is famous for bad reasons."
    ),
    _WordSet(
        category: "Stubbornness",
        words: ["Tenacious", "Persistent", "Resolute"],
        oddOne: "Obstinate",
        reason: "Three imply strength of will.\n'Obstinate' implies unreasonable pig-headedness."
    ),
    _WordSet(
        category: "Smell",
        words: ["Fragrance", "Aroma", "Scent"],
        oddOne: "Stench",
        reason: "Three are pleasant or neutral.\n'Stench' is specifically repulsive."
    ),
    _WordSet(
        category: "Fear",
        words: ["Terrified", "Petrified", "Horrified"],
        oddOne: "Concerned",
        reason: "Three represent extreme fear.\n'Concerned' is merely mild worry."
    ),
    _WordSet(
        category: "Formality",
        words: ["Commence", "Initiate", "Embark"],
        oddOne: "Start",
        reason: "Three are formal/academic.\n'Start' is common/casual."
    ),
    _WordSet(
        category: "Youth",
        words: ["Youthful", "Childlike", "Innocent"],
        oddOne: "Childish",
        reason: "Three imply freshness/purity.\n'Childish' implies immaturity (negative)."
    ),
    _WordSet(
        category: "Groups",
        words: ["Herd", "Flock", "Pack"],
        oddOne: "Crowd",
        reason: "Three refer to animals.\n'Crowd' refers to humans."
    ),
    _WordSet(
        category: "Difficulty",
        words: ["Challenging", "Demanding", "Arduous"],
        oddOne: "Impossible",
        reason: "Three are doable with effort.\n'Impossible' cannot be done."
    ),
    _WordSet(
        category: "Look",
        words: ["Gaze", "Stare", "Peer"],
        oddOne: "Glance",
        reason: "Three imply duration/intensity.\n'Glance' is momentary."
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _initGame() {
    _sessionQueue = List.from(_masterPool)..shuffle(rand);
    if (_sessionQueue.length > _maxRounds) {
      _sessionQueue = _sessionQueue.sublist(0, _maxRounds);
    }
    // Note: Global timer removed. Round timer starts in _startRound
    _startRound();
  }

  void _startRound() {
    if (_roundIndex >= _sessionQueue.length) {
      _finishGame();
      return;
    }

    // RESET TIMER FOR NEW ROUND
    _roundTimer?.cancel();
    _currentRoundSeconds = 10;

    setState(() {
      _isTransitioning = false;
      _currentSet = _sessionQueue[_roundIndex];

      // Combine and shuffle options
      _shuffledOptions = List.from(_currentSet.words)..add(_currentSet.oddOne);
      _shuffledOptions.shuffle(rand);

      _roundStartTime = DateTime.now().millisecondsSinceEpoch;
    });

    // START COUNTDOWN
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentRoundSeconds--;
      });

      if (_currentRoundSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _roundTimer?.cancel();
    if (_isTransitioning) return;

    // Timeout penalty
    _reactionTimes.add(10000);

    setState(() => _isTransitioning = true);
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isGameOver) {
        setState(() => _roundIndex++);
        _startRound();
      }
    });
  }

  void _handleSelection(String word) {
    if (_isTransitioning || _isGameOver) return;

    // Stop timer on selection
    _roundTimer?.cancel();

    setState(() => _isTransitioning = true);

    final int rt = DateTime.now().millisecondsSinceEpoch - _roundStartTime;
    final bool correct = (word == _currentSet.oddOne);

    if (correct) {
      _scoreCorrect++;
      _reactionTimes.add(rt);
    } else {
      _reactionTimes.add(5000); // Penalty
    }

    HapticFeedback.lightImpact();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && !_isGameOver) {
        setState(() => _roundIndex++);
        _startRound();
      }
    });
  }

  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => _isGameOver = true);
  }

  // --- GRADING ALGORITHM ---
  Map<String, double> grade() {
    double breadth = _sessionQueue.isEmpty ? 0.0 : (_scoreCorrect / _sessionQueue.length);
    double avgRt = _reactionTimes.isEmpty ? 7000 :
    _reactionTimes.reduce((a,b)=>a+b) / _reactionTimes.length;

    double fluency = (1.0 - ((avgRt - 2000) / 5000)).clamp(0.0, 1.0);

    return {
      "Vocabulary Breadth": double.parse(breadth.toStringAsFixed(2)),
      "Verbal Fluency": double.parse(fluency.toStringAsFixed(2)),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver) {
      final scores = grade();
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, color: Colors.tealAccent, size: 80),
              const SizedBox(height: 20),
              const Text("LINGUISTIC ANALYSIS", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              _ScoreRow("Vocabulary Precision", scores["Vocabulary Breadth"]!),
              const SizedBox(height: 10),
              _ScoreRow("Verbal Fluency", scores["Verbal Fluency"]!),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(scores);
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colBackground,
      appBar: AppBar(
        title: const Text("Semantic Sieve"),
        backgroundColor: Colors.transparent,
        foregroundColor: colText,
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                  "$_currentRoundSeconds s",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _currentRoundSeconds <= 3 ? Colors.red : colPrimary
                  )
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HEADER CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Column(
                  children: [
                    Text(
                      "CATEGORY: ${_currentSet.category.toUpperCase()}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Find the Intruder",
                      style: TextStyle(color: colPrimary, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "3 words share a nuance. 1 does not.",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // --- OPTIONS GRID ---
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: _shuffledOptions.map((word) {
                  return GestureDetector(
                    onTap: _isTransitioning ? null : () => _handleSelection(word),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.indigo.shade50, width: 2),
                          boxShadow: [
                            BoxShadow(color: colPrimary.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 4))
                          ]
                      ),
                      child: Center(
                        child: Text(
                          word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Progress Indicator
              Center(
                child: Text(
                  "Round ${_roundIndex + 1} / $_maxRounds",
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- DATA MODEL ---
class _WordSet {
  final String category;
  final List<String> words;
  final String oddOne;
  final String reason;
  _WordSet({required this.category, required this.words, required this.oddOne, required this.reason});
}

// --- SCORE WIDGET ---
class _ScoreRow extends StatelessWidget {
  final String label; final double value;
  const _ScoreRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 18))
      ]),
    );
  }
}