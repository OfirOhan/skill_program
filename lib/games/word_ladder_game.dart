// lib/word_ladder_game.dart
import 'dart:async';
import 'package:flutter/material.dart';

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
    reactionTimes.add(rt);

    bool isCorrect = (selectedIdx == item.correctIndex);
    if (isCorrect) correctCount++;

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
    double accuracy = items.isEmpty ? 0.0 : correctCount / items.length;
    double avgRt = reactionTimes.isEmpty ? 4000 : reactionTimes.reduce((a,b)=>a+b) / reactionTimes.length;

    // Adjusted for difficulty: 2.5s is fast now
    double speedScore = (1.0 - ((avgRt - 2500) / 5000)).clamp(0.0, 1.0);

    // Deep Semantic Logic: Did they get the 3x3 grids right? (Last 2 items)
    // We infer abstract reasoning from overall high score on this hard set.
    double abstractLogic = accuracy > 0.8 ? 1.0 : accuracy * 0.7;

    return {
      "Verbal Reasoning": accuracy,
      "Long-Term Recall": accuracy * 0.8,
      "Analytical Thinking": (accuracy * 0.6 + speedScore * 0.4).clamp(0.0, 1.0),
      "Pattern Recognition (linguistic)": accuracy,
      "Storytelling Ability": accuracy * 0.8,
      "Cultural Sensitivity": 1.0,
      "Active Listening": accuracy,
      "Abstract Reasoning": abstractLogic, // New metric for hard questions
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) return _buildResultsScreen();

    final item = items[index];

    return Scaffold(
      appBar: AppBar(
        title: Text("4. Logic Sprint (${index + 1}/${items.length})"),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
                child: Text(
                    "${remainingSeconds}s",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: remainingSeconds <= 3 ? Colors.red : Colors.orange[800]
                    )
                )
            ),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
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
      appBar: AppBar(title: const Text("4. Logic Sprint"), automaticallyImplyLeading: false),
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

    // 2. Functional Hierarchy (Hard)
    SymbolItem(
        "SYSTEMS",
        "🧱 : 🏰\n⬇️\n🧬 : ❓",
        ["🩸", "🧑", "🏥", "🧪"],
        1 // Dinosaur (DNA builds the Organism)
    ),

    // 3. Conceptual Math (Energy)
    SymbolItem(
        "CONCEPT MATH",
        "☀️ + 🌱 = 🌻\n⚡ + 💡 = ❓",
        ["🔦", "🔋", "🔌", "🕯️"],
        0 // Flashlight/Beam (Light is produced)
    ),

    // 4. Conceptual Math (Result)
    SymbolItem(
        "CONCEPT MATH",
        "🐛 + ⏳ = 🦋\n🌱 + ☀️ = ❓",
        ["🌻", "🌱", "🌫️", "💦"],
        0 //
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
        "✍️ ➡️ 🗂️ ➡️ ❓\n⚗️ ➡️ 🧫 ➡️ ❓\n🔍 ➡️ 📊 ➡️ ❓",
        ["📚", "💡", "🏷️", "📎"],
        1 // 💡 — the three rows produce 'insight' / 'meaning'
    ),

  ];
}