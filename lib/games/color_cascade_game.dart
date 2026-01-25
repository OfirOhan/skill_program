// lib/color_cascade_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../grading/color_cascade_grading.dart';

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
  List<Color> tiles = [];
  List<Color> reorderableList = [];
  Set<int> oddTileIndices = {}; // Track both odd tiles
  Set<int> foundTiles = {}; // Track which odd tiles user has found

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 20;
  int startMs = 0;

  // Metrics - PER ROUND TRACKING
  List<bool> roundPerfect = [];      // Track which rounds were perfect
  List<double> roundPrecision = [];  // Track precision score per round
  List<int> reactionTimes = [];

  // Feedback
  Color? feedbackColor;
  String? feedbackText;

  static const int _timeoutPenaltyMs = 25000;

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
    if (lvl >= 4) {
      _finishGame();
      return;
    }

    setState(() {
      level = lvl;
      remainingSeconds = 25;
      startMs = DateTime.now().millisecondsSinceEpoch;
      feedbackColor = null;

      // Reset Data
      tiles = [];
      reorderableList = [];
      oddTileIndices.clear();
      foundTiles.clear();
      baseColor = _randomBaseColor();

      if (level == 0) {
        // ROUND 1: Sort 7 items (Extremely Subtle Gradient)
        reorderableList = _generateGradient(baseColor, 7, variance: 0.2);
        reorderableList.shuffle();
      }
      else if (level == 1) {
        // ROUND 2: 4x4 Grid (3% Diff) - Find 2 odd tiles
        int count = 16;
        tiles = List.filled(count, baseColor.color);

        // Pick 2 random positions for odd tiles
        List<int> positions = List.generate(count, (i) => i);
        positions.shuffle();
        oddTileIndices.add(positions[0]);
        oddTileIndices.add(positions[1]);

        double l = HSLColor.fromColor(baseColor.color).lightness;
        double diff = 0.03;
        double newL = (l > 0.5) ? l - diff : l + diff;

        tiles = List.generate(count, (i) {
          if (oddTileIndices.contains(i)) {
            return HSLColor.fromColor(baseColor.color).withLightness(newL.clamp(0.0, 1.0)).toColor();
          }
          return baseColor.color;
        });
      }
      else if (level == 2) {
        // ROUND 3: 5x5 Grid (1.5% Diff) - Find 2 odd tiles
        int count = 25;
        tiles = List.filled(count, baseColor.color);

        List<int> positions = List.generate(count, (i) => i);
        positions.shuffle();
        oddTileIndices.add(positions[0]);
        oddTileIndices.add(positions[1]);

        double l = HSLColor.fromColor(baseColor.color).lightness;
        double diff = 0.015;
        double newL = (l > 0.5) ? l - diff : l + diff;

        tiles = List.generate(count, (i) {
          if (oddTileIndices.contains(i)) {
            return HSLColor.fromColor(baseColor.color).withLightness(newL.clamp(0.0, 1.0)).toColor();
          }
          return baseColor.color;
        });
      }
      else {
        // ROUND 4: 6x6 Grid (1.0% Diff) - Find 2 odd tiles
        int count = 36;
        tiles = List.filled(count, baseColor.color);

        List<int> positions = List.generate(count, (i) => i);
        positions.shuffle();
        oddTileIndices.add(positions[0]);
        oddTileIndices.add(positions[1]);

        double l = HSLColor.fromColor(baseColor.color).lightness;
        double diff = 0.01;
        double newL = (l > 0.5) ? l - diff : l + diff;

        tiles = List.generate(count, (i) {
          if (oddTileIndices.contains(i)) {
            return HSLColor.fromColor(baseColor.color).withLightness(newL.clamp(0.0, 1.0)).toColor();
          }
          return baseColor.color;
        });
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

    // Record timeout for this round
    reactionTimes.add(_timeoutPenaltyMs);
    roundPerfect.add(false);
    roundPrecision.add(0.0);

    _showFeedback(false, isTimeout: true);
  }

  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => isGameOver = true);
  }

  // --- ROUND 1 LOGIC (Sorting) ---
  void _checkSort() {
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();

    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    // Count correct pairs (neighbors in correct order)
    int correctPairs = 0;
    int totalPairs = reorderableList.length - 1; // 6 pairs for 7 tiles

    for (int i = 0; i < totalPairs; i++) {
      if (reorderableList[i].computeLuminance() >=
          reorderableList[i+1].computeLuminance() - 0.0001) {
        correctPairs++;
      }
    }

    bool perfect = (correctPairs == totalPairs);
    double precision;

    if (perfect) {
      // Perfect: 1.0
      precision = 1.0;
    } else if (correctPairs >= 3) {
      // Partial credit only if at least 3 pairs correct (50%+)
      // Accelerating penalties: first mistake hurts, then gets worse

      if (correctPairs == 5) {
        precision = 0.80; // -20% for first mistake
      } else if (correctPairs == 4) {
        precision = 0.55; // -25% additional (45% total from perfect)
      } else { // correctPairs == 3
        precision = 0.30; // -25% additional (70% total from perfect)
      }
    } else {
      // Less than 3 pairs correct (< 50%) = no partial credit
      precision = 0.0;
    }

    // Store per-round data
    roundPrecision.add(precision);
    roundPerfect.add(perfect);

    if (perfect) {
      HapticFeedback.mediumImpact();
      _showFeedback(true);
    } else {
      HapticFeedback.heavyImpact();
      _showFeedback(false);
    }
  }

  // --- ROUND 2/3/4 LOGIC (Grid Tap) ---
  void _onGridTap(int index) {
    if (isGameOver || feedbackColor != null) return;
    HapticFeedback.lightImpact();

    // Check if this is an odd tile
    if (oddTileIndices.contains(index)) {
      // Found an odd tile!
      if (!foundTiles.contains(index)) {
        foundTiles.add(index);
        HapticFeedback.mediumImpact();

        // Update tile to show it's been found (make it slightly transparent or marked)
        setState(() {
          // Visual feedback happens in the builder
        });

        // Check if we found both tiles
        if (foundTiles.length == 2) {
          // Found both! End the round
          _roundTimer?.cancel();
          final rt = DateTime.now().millisecondsSinceEpoch - startMs;
          reactionTimes.add(rt);

          // Store per-round data: perfect = found both
          roundPrecision.add(1.0);
          roundPerfect.add(true);

          _showFeedback(true);
        }
      }
    } else {
      // Wrong tile - end round immediately
      _roundTimer?.cancel();
      final rt = DateTime.now().millisecondsSinceEpoch - startMs;
      reactionTimes.add(rt);

      HapticFeedback.heavyImpact();

      // Calculate precision: 0.0 if none found, 0.5 if found 1, 1.0 if found both
      double precision = foundTiles.length / 2.0;
      roundPrecision.add(precision);
      roundPerfect.add(false);

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

  Map<String, double> grade() {
    return ColorCascadeGrading.grade(
      roundPerfect: roundPerfect,
      roundPrecision: roundPrecision,
      reactionTimes: reactionTimes,
      timeoutPenaltyMs: _timeoutPenaltyMs,
    );
  }

  // --- GENERATORS ---
  List<Color> _generateGradient(ColorBase base, int steps, {double variance = 0.3}) {
    List<Color> list = [];
    double startL = 0.85;
    double stepSize = variance / steps;

    for (int i = 0; i < steps; i++) {
      double l = startL - (i * stepSize);
      list.add(HSLColor.fromColor(base.color).withLightness(l.clamp(0.1, 0.9)).toColor());
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
      ColorBase(Colors.orange, "Orange"),
      ColorBase(Colors.pink, "Pink"),
    ];
    return bases[Random().nextInt(bases.length)];
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      // Calculate accuracy for display
      int totalCorrect = roundPerfect.where((p) => p).length;

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
              Text("Accuracy: ${(totalCorrect / 4 * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(grade());
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Color Cascade"),
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
                      color: remainingSeconds <= 5 ? Colors.red : Colors.indigo
                  )
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (level == 0) _buildSortLevel()
          else _buildGridLevel(),

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
          child: Text("Drag Handle to order:\nLIGHTEST (Top)  ->  DARKEST (Bottom)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            buildDefaultDragHandles: false,
            children: [
              for (int i=0; i<reorderableList.length; i++)
                Container(
                  key: ValueKey(reorderableList[i]),
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      color: reorderableList[i],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 2)]
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      const Spacer(),
                      ReorderableDragStartListener(
                        index: i,
                        child: Container(
                          width: 60,
                          height: double.infinity,
                          color: Colors.black12,
                          child: const Icon(Icons.drag_handle, color: Colors.white, size: 30),
                        ),
                      )
                    ],
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
            height: 55,
            child: ElevatedButton(
              onPressed: _checkSort,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text("SUBMIT ORDER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildGridLevel() {
    int crossAxis = 4;
    if (level == 2) crossAxis = 5;
    if (level == 3) crossAxis = 6;

    String title = "Find 2 ODD Colors!";
    if (level == 2) title = "EXPERT: Find both odd ones";
    if (level == 3) title = "MASTER: Find 2. Good luck.";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Found: ${foundTiles.length}/2",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: foundTiles.length == 2 ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, i) {
                  bool isFound = foundTiles.contains(i);

                  return GestureDetector(
                    onTap: () => _onGridTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tiles[i],
                        borderRadius: BorderRadius.circular(4),
                        border: isFound ? Border.all(color: Colors.greenAccent, width: 3) : null,
                      ),
                      child: isFound
                          ? const Icon(Icons.check_circle, color: Colors.white, size: 24)
                          : null,
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