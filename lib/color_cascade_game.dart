// lib/color_cascade_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ColorCascadeGame extends StatefulWidget {
  const ColorCascadeGame({Key? key}) : super(key: key);

  @override
  _ColorCascadeGameState createState() => _ColorCascadeGameState();
}

class _ColorCascadeGameState extends State<ColorCascadeGame> {
  // Game State
  int level = 0;
  bool isGameOver = false;

  // Level Data
  late ColorBase baseColor;
  late List<Color> tiles;
  int? oddOneIndex; // For Odd One Out mode

  // Reorderable State (Round 1)
  List<Color> reorderableList = [];

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 20;
  int startMs = 0;

  // Metrics
  int totalCorrect = 0;
  double totalPrecision = 0.0; // Distance from correct order
  List<int> reactionTimes = [];

  // Feedback
  Color? feedbackColor;
  String? feedbackText;

  @override
  void initState() {
    super.initState();
    _startLevel(0);
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startLevel(int lvl) {
    if (lvl >= 3) {
      _finishGame();
      return;
    }

    setState(() {
      level = lvl;
      remainingSeconds = 20;
      startMs = DateTime.now().millisecondsSinceEpoch;
      feedbackColor = null;

      // Generate content based on level
      baseColor = _randomBaseColor();
      if (level == 0) {
        // Sort: Light to Dark
        reorderableList = _generateGradient(baseColor, 5);
        reorderableList.shuffle();
      } else if (level == 1) {
        // Odd One Out: 4x4 Grid
        tiles = List.filled(16, baseColor.color);
        oddOneIndex = Random().nextInt(16);
        tiles[oddOneIndex!] = baseColor.color.withOpacity(0.85); // Slight diff
      } else {
        // Gradient Match: Pick the missing link
        // Logic handled in UI build for simplicity
      }
    });

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _roundTimer?.cancel();
    _showFeedback(false, isTimeout: true);
  }

  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => isGameOver = true);
  }

  // --- ROUND 1 LOGIC ---
  void _checkSort() {
    // Calculate correctness based on luminance sorting
    double score = 0;
    for (int i = 0; i < reorderableList.length - 1; i++) {
      if (reorderableList[i].computeLuminance() > reorderableList[i+1].computeLuminance()) {
        score++; // Correct order (Light -> Dark means High Lum -> Low Lum)
      }
    }

    // Perfect is count-1.
    bool perfect = score == (reorderableList.length - 1);
    if (perfect) {
      totalCorrect++;
      totalPrecision += 1.0;
      _showFeedback(true);
    } else {
      totalPrecision += (score / (reorderableList.length - 1));
      _showFeedback(false);
    }
  }

  // --- ROUND 2 LOGIC ---
  void _onGridTap(int index) {
    if (isGameOver || feedbackColor != null) return;

    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    if (index == oddOneIndex) {
      totalCorrect++;
      totalPrecision += 1.0;
      _showFeedback(true);
    } else {
      _showFeedback(false);
    }
  }

  void _showFeedback(bool correct, {bool isTimeout = false}) {
    setState(() {
      if (isTimeout) {
        feedbackColor = Colors.orange;
        feedbackText = "TOO SLOW!";
      } else {
        feedbackColor = correct ? Colors.green : Colors.red;
        feedbackText = correct ? "PERFECT!" : "OFF!";
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _startLevel(level + 1);
    });
  }

  // --- GENERATORS ---
  List<Color> _generateGradient(ColorBase base, int steps) {
    List<Color> list = [];
    for (int i = 0; i < steps; i++) {
      // Generate shades from 0.2 to 0.8 opacity overlay or lightness
      double factor = 0.1 + (i * (0.8 / steps));
      list.add(HSLColor.fromColor(base.color).withLightness(0.9 - factor).toColor());
    }
    return list;
  }

  ColorBase _randomBaseColor() {
    List<ColorBase> bases = [
      ColorBase(Colors.blue, "Blue"),
      ColorBase(Colors.red, "Red"),
      ColorBase(Colors.green, "Green"),
      ColorBase(Colors.purple, "Purple"),
      ColorBase(Colors.teal, "Teal"),
    ];
    return bases[Random().nextInt(bases.length)];
  }

  Map<String, double> grade() {
    double accuracy = totalCorrect / 3.0;
    double precision = totalPrecision / 3.0;

    return {
      "Color Differentiation": accuracy,
      "Aesthetic Sensitivity": precision, // Did they get the gradient perfect?
      "Visual Perception Accuracy": accuracy,
      "Attention to Detail": precision * 0.9,
      "Pattern Recognition": accuracy,
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
              const Icon(Icons.palette, color: Colors.pinkAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Spectrum Analyzed!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Precision: ${(totalPrecision * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 18)),
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
        title: Text("11. Color Cascade ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
      ),
      body: Stack(
        children: [
          // LEVEL CONTENT
          if (level == 0) _buildSortLevel(),
          if (level == 1) _buildGridLevel(),
          if (level == 2) _buildMatchLevel(), // Reuse grid logic or similar

          // FEEDBACK OVERLAY
          if (feedbackColor != null)
            Container(
              color: feedbackColor!.withOpacity(0.9),
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortLevel() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Drag to order: LIGHTEST (Top) to DARKEST (Bottom)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            children: [
              for (int i=0; i<reorderableList.length; i++)
                Container(
                  key: ValueKey(reorderableList[i]),
                  height: 80,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      color: reorderableList[i],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                  ),
                )
            ],
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = reorderableList.removeAt(oldIndex);
                reorderableList.insert(newIndex, item);
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _checkSort,
              child: const Text("SUBMIT ORDER"),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildGridLevel() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Find the ODD COLOR out!", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 16,
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () => _onGridTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tiles[i],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // For Level 3, let's do a simplified "Pick the Match"
  // (Normally gradient match, but for code brevity reusing grid logic works well as 'Hard Mode' grid)
  Widget _buildMatchLevel() {
    // Re-use grid but make it harder (subtler difference) for Level 3
    // Or we can implement a specific gradient picker.
    // For simplicity in this MVP, Level 3 is "Hard Grid"
    if (tiles.isEmpty) {
      // init hard grid on fly if needed (hack for MVP flow)
      baseColor = _randomBaseColor();
      tiles = List.filled(25, baseColor.color); // 5x5
      oddOneIndex = Random().nextInt(25);
      tiles[oddOneIndex!] = baseColor.color.withOpacity(0.92); // Very subtle
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("HARD MODE: Find the odd one!", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 25,
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () => _onGridTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tiles[i],
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ColorBase {
  final Color color;
  final String name;
  ColorBase(this.color, this.name);
}