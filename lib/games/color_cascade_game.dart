// lib/color_cascade_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int? oddOneIndex;

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 20;
  int startMs = 0;

  // Metrics
  int totalCorrect = 0;
  double totalPrecision = 0.0;
  List<int> reactionTimes = [];

  // Feedback
  Color? feedbackColor;
  String? feedbackText;

  static const int _timeoutPenaltyMs = 25000; // treat no-answer as very slow

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
      baseColor = _randomBaseColor();

      if (level == 0) {
        // ROUND 1: Sort 7 items (Extremely Subtle Gradient)
        // Increased count to 7, reduced variance to 0.2 (very tight steps)
        reorderableList = _generateGradient(baseColor, 7, variance: 0.2);
        reorderableList.shuffle();
      }
      else if (level == 1) {
        // ROUND 2: 4x4 Grid (3% Diff - Was 4%)
        int count = 16;
        tiles = List.filled(count, baseColor.color);
        oddOneIndex = Random().nextInt(count);

        double l = HSLColor.fromColor(baseColor.color).lightness;
        double diff = 0.03;

        double newL = (l > 0.5) ? l - diff : l + diff;
        tiles = List.generate(count, (i) {
          if (i == oddOneIndex) {
            return HSLColor.fromColor(baseColor.color).withLightness(newL.clamp(0.0, 1.0)).toColor();
          }
          return baseColor.color;
        });
      }
      else if (level == 2) {
        // ROUND 3: 5x5 Grid (1.5% Diff - Was 3%)
        int count = 25;
        tiles = List.filled(count, baseColor.color);
        oddOneIndex = Random().nextInt(count);

        double l = HSLColor.fromColor(baseColor.color).lightness;
        double diff = 0.015;
        double newL = (l > 0.5) ? l - diff : l + diff;

        tiles = List.generate(count, (i) {
          if (i == oddOneIndex) {
            return HSLColor.fromColor(baseColor.color).withLightness(newL.clamp(0.0, 1.0)).toColor();
          }
          return baseColor.color;
        });
      }
      else {
        // ROUND 4: 6x6 Grid (0.8% Diff - Was 1.5%)
        // This is nearly impossible on standard screens
        int count = 36;
        tiles = List.filled(count, baseColor.color);
        oddOneIndex = Random().nextInt(count);

        double l = HSLColor.fromColor(baseColor.color).lightness;
        double diff = 0.008;
        double newL = (l > 0.5) ? l - diff : l + diff;

        tiles = List.generate(count, (i) {
          if (i == oddOneIndex) {
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

    // record a speed penalty for "no answer"
    reactionTimes.add(_timeoutPenaltyMs);

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

    double score = 0;
    int checks = reorderableList.length - 1;

    for (int i = 0; i < checks; i++) {
      if (reorderableList[i].computeLuminance() >= reorderableList[i+1].computeLuminance() - 0.0001) {
        score++;
      }
    }

    bool perfect = score == checks;
    if (perfect) {
      totalCorrect++;
      totalPrecision += 1.0;
      HapticFeedback.mediumImpact();
      _showFeedback(true);
    } else {
      totalPrecision += (score / checks);
      HapticFeedback.heavyImpact();
      _showFeedback(false);
    }
  }


  // --- ROUND 2/3/4 LOGIC (Grid Tap) ---
  void _onGridTap(int index) {
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();
    HapticFeedback.lightImpact();

    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    if (index == oddOneIndex) {
      totalCorrect++;
      totalPrecision += 1.0;
      HapticFeedback.mediumImpact();
      _showFeedback(true);
    } else {
      HapticFeedback.heavyImpact();
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
    const int rounds = 4;

    // Strict round wins (perfect sort + correct odd-tap rounds)
    final double strictAccuracy = (totalCorrect / rounds).clamp(0.0, 1.0);

    // Precision includes partial credit on sort + 0/1 on grid rounds
    final double precision = (totalPrecision / rounds).clamp(0.0, 1.0);

    // Speed (includes timeout penalties)
    final double avgRt = reactionTimes.isEmpty
        ? _timeoutPenaltyMs.toDouble()
        : reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;

    // 1200ms = fast, 25000ms = very slow
    final double rawSpeed = (1.0 - ((avgRt - 1200.0) / (_timeoutPenaltyMs - 1200.0))).clamp(0.0, 1.0);

    // Speed only counts if perception was actually good (anti-guess / anti-random tapping)
    final double earnedSpeed = (rawSpeed * precision).clamp(0.0, 1.0);

    final double colorDiscrimination = precision;
    final double visualAcuity = (0.7 * precision + 0.3 * strictAccuracy).clamp(0.0, 1.0);
    final double patternRecognition = (0.6 * strictAccuracy + 0.4 * precision).clamp(0.0, 1.0);

    final double decisionUnderPressure = (0.8 * strictAccuracy + 0.2 * rawSpeed).clamp(0.0, 1.0);

    return {
      "Color Discrimination": colorDiscrimination,
      "Visual Acuity": visualAcuity,
      "Pattern Recognition": patternRecognition,
      "Information Processing Speed": earnedSpeed,
      "Decision Under Pressure": decisionUnderPressure,
    };
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
        title: const Text("11. Color Cascade"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "${remainingSeconds}s",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: remainingSeconds <= 5 ? Colors.red : Colors.indigo
                )
              )
            ),
          ),
          TextButton(onPressed: () {
           HapticFeedback.lightImpact();
           Navigator.of(context).pop(null);
        }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
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
                  height: 60, // Slightly shorter to fit 7 items
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
    int crossAxis = 4; // Default 4x4
    if (level == 2) crossAxis = 5; // 5x5
    if (level == 3) crossAxis = 6; // 6x6

    String title = "Find the ODD Color!";
    if (level == 2) title = "EXPERT: Find the odd one";
    if (level == 3) title = "MASTER: Good luck.";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  return GestureDetector(
                    onTap: () => _onGridTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tiles[i],
                        borderRadius: BorderRadius.circular(4),
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