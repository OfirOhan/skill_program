// lib/word_ladder_game.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WordLadderGame extends StatefulWidget {
  const WordLadderGame({Key? key}) : super(key: key);

  @override
  _WordLadderGameState createState() => _WordLadderGameState();
}

class _WordLadderGameState extends State<WordLadderGame> {
  late List<SymbolItem> items;
  int index = 0;
  bool isGameOver = false;

  // Timer settings
  Timer? _questionTimer;
  static const int timePerQuestion = 15; // 15s because these are harder
  int remainingSeconds = timePerQuestion;
  int startMs = 0;

  // Metrics
  int correctCount = 0;
  List<int> reactionTimes = [];

  // Feedback
  Color? feedbackColor;
  String? feedbackText;

  // --- NEW: per-item evidence (no logic change) ---
  final List<bool> itemCorrect = [];
  final List<int> itemTimesMs = [];

  @override
  void initState() {
    super.initState();
    items = _generateItems();
    _startQuestion();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    if (index >= items.length) {
      _finishGame();
      return;
    }

    setState(() {
      remainingSeconds = timePerQuestion;
      startMs = DateTime.now().millisecondsSinceEpoch;
      feedbackColor = null;
      feedbackText = null;
    });

    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _questionTimer?.cancel();
    HapticFeedback.vibrate();

    // Evidence: no response by deadline => incorrect, time = limit (not fabricated)
    itemCorrect.add(false);
    itemTimesMs.add(timePerQuestion * 1000);

    _showFeedback(false, isTimeout: true);
  }

  void _finishGame() {
    _questionTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void onOptionSelected(int selectedIdx) {
    if (isGameOver || feedbackColor != null) return;
    _questionTimer?.cancel();

    final item = items[index];
    final rt = DateTime.now().millisecondsSinceEpoch - startMs;

    final bool isCorrect = (selectedIdx == item.correctIndex);

    // Evidence logging
    itemCorrect.add(isCorrect);
    itemTimesMs.add(rt.clamp(0, timePerQuestion * 1000));

    if (isCorrect) correctCount++;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    _showFeedback(isCorrect);
  }

  void _showFeedback(bool correct, {bool isTimeout = false}) {
    setState(() {
      if (isTimeout) {
        feedbackColor = Colors.orange;
        feedbackText = "TOO SLOW!";
      } else {
        feedbackColor = correct ? Colors.green : Colors.red;
        feedbackText = correct ? "CORRECT!" : "WRONG!";
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        index++;
      });
      _startQuestion();
    });
  }

  Map<String, double> grade() {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    final int n = [
      items.length,
      itemCorrect.length,
      itemTimesMs.length,
    ].reduce((a, b) => a < b ? a : b);

    if (n <= 0) {
      return {
        "Inductive Reasoning": 0.0,
        "Abstract Thinking": 0.0,
        "Information Processing Speed": 0.0,
      };
    }

    // ---- Intermediate metrics ----
    int correctTotal = 0;

    int inductiveN = 0, inductiveCorrect = 0;
    int abstractN = 0, abstractCorrect = 0;

    for (int i = 0; i < n; i++) {
      final item = items[i];
      final bool correct = itemCorrect[i];
      if (correct) correctTotal++;

      final String cat = item.category;

      final bool isAbstractBucket =
          cat.contains("SYSTEMS") || cat.contains("EMERGENCE");

      if (isAbstractBucket) {
        abstractN++;
        if (correct) abstractCorrect++;
      } else {
        inductiveN++;
        if (correct) inductiveCorrect++;
      }
    }

    final double overallAccuracy = clamp01(correctTotal / n);

    final double inductiveAccuracy =
    inductiveN == 0 ? 0.0 : clamp01(inductiveCorrect / inductiveN);

    final double abstractAccuracy =
    abstractN == 0 ? 0.0 : clamp01(abstractCorrect / abstractN);

    // ---- Information Processing Speed (earned; gated by correctness) ----
    double informationProcessingSpeed = 0.0;
    {
      final times = itemTimesMs.take(n).toList()..sort();
      final int mid = times.length ~/ 2;
      final double medianMs = times.length.isOdd
          ? times[mid].toDouble()
          : ((times[mid - 1] + times[mid]) / 2.0);

      // Normalize by the actual question time limit (no magic constants)
      final double rawSpeed = clamp01(1.0 - (medianMs / (timePerQuestion * 1000)));

      // Earned speed: no fast-guessing points
      informationProcessingSpeed = clamp01(rawSpeed * overallAccuracy);
    }

    // ---- Skills (no overlap / no forced skills) ----
    return {
      "Inductive Reasoning": inductiveAccuracy,
      "Abstract Thinking": abstractAccuracy,
      "Information Processing Speed": informationProcessingSpeed,
    };
  }


  @override
  Widget build(BuildContext context) {
    if (isGameOver) return _buildResultsScreen();

    final item = items[index];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Logic Sprint"),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                "$remainingSeconds s",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: remainingSeconds <= 3 ? Colors.red : Colors.indigo
                )
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(20)),
                    child: Text(item.category, style: TextStyle(color: Colors.indigo[800], fontWeight: FontWeight.bold)),
                  ),
                ),

                const Spacer(flex: 1),

                // THE QUESTION DISPLAY
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Center(child: _buildQuestionContent(item)),
                ),

                const Spacer(flex: 2),

                // OPTIONS
                Expanded(
                  flex: 6,
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: List.generate(item.options.length, (i) {
                      return ElevatedButton(
                        onPressed: () => onOptionSelected(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          item.options[i],
                          style: const TextStyle(fontSize: 42),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          if (feedbackColor != null)
            Container(
              color: feedbackColor!.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        feedbackColor == Colors.green ? Icons.check_circle : Icons.cancel,
                        color: Colors.white, size: 100
                    ),
                    const SizedBox(height: 20),
                    Text(feedbackText!, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    if (feedbackColor != Colors.green) ...[
                      const SizedBox(height: 10),
                      Text("Correct: ${item.options[item.correctIndex]}", style: const TextStyle(color: Colors.white, fontSize: 24)),
                    ]
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Handle multiline/grid questions
  Widget _buildQuestionContent(SymbolItem item) {
    if (item.category.contains("GRID")) {
      // Parse the grid string (assuming newlines separate rows)
      List<String> rows = item.question.split('\n');
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(r, style: const TextStyle(fontSize: 32, letterSpacing: 8)),
        )).toList(),
      );
    } else {
      // Standard Question
      return Text(
        item.question,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 40, height: 1.2),
      );
    }
  }

  Widget _buildResultsScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text("Logic Sprint"), automaticallyImplyLeading: false),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 80),
            const SizedBox(height: 20),
            const Text("Logic Sprint Done!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Score: $correctCount / ${items.length}", style: const TextStyle(color: Colors.grey, fontSize: 18)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(grade()),
              icon: const Icon(Icons.arrow_forward),
              label: const Text("NEXT GAME"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DATA STRUCTURES ---

class SymbolItem {
  final String category;
  final String question;
  final List<String> options;
  final int correctIndex;

  SymbolItem(this.category, this.question, this.options, this.correctIndex);
}

// --- HARDCORE CONTENT GENERATOR ---
List<SymbolItem> _generateItems() {
  return [
    // 1. Scale/Observation (Hard)
    SymbolItem(
        "SCALE",
        "🔭 : 🌌\n⬇️\n🔬 : ❓",
        ["👀", "👓", "🦠", "🌍"],
        2 // Microbe/Bacteria
    ),

    // 2. Conceptual Math (Result)
    SymbolItem(
        "CONCEPT MATH",
        "🐛 + ⏳ = 🦋\n🌱 + ☀️ = ❓",
        ["🌻", "🌱", "🌫️", "💦"],
        0 //
    ),

    // 3. Conceptual Math (Energy)
    SymbolItem(
        "CONCEPT MATH",
        "🚗 + ⛽ = 💨\n📱 + ⚡ = ❓",
        ["🔋", "📴", "🔨", "🧊"],
        0 // Green Battery (Phone + Energy = Charged)
    ),

    // 4. Functional Hierarchy (Hard)
    SymbolItem(
        "SYSTEMS",
        "🧱 : 🏰\n⬇️\n🧬 : ❓",
        ["🩸", "🧑", "🏥", "🧪"],
        1 // Dinosaur (DNA builds the Organism)
    ),

    SymbolItem(
        "METAMORPHOSIS (very hard)",
        "🥛 + 🧪 = 🧀\n🌾 + 🧫 = 🍞\n🪨 + ⏳ = ❓",
        ["🧱", "🏺", "🔥", "💎"],
        3 // 💎 — rock + time/pressure → gemstone (metamorphism/crystallization)
    ),

    // 6. SYSTEMS HIERARCHY (Genius 3x3)
    SymbolItem(
        "EMERGENCE — INSIGHT (very hard)",
        "✍️ ➡️ 🗂️ ➡️ ❓\n🧫 ➡️ 🔬 ➡️ ❓\n🔍 ➡️ 📊 ➡️ ❓",
        ["📚", "💡", "🏷️", "📎"],
        1 // 💡 — the three rows produce 'insight' / 'meaning'
    ),

  ];
}