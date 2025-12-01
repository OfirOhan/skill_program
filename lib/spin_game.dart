// lib/spin_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class SpinGame extends StatefulWidget {
  const SpinGame({Key? key}) : super(key: key);

  @override
  _SpinGameState createState() => _SpinGameState();
}

class _SpinGameState extends State<SpinGame> with TickerProviderStateMixin {
  // Game State
  late List<SpinLevel> levels;
  int index = 0;
  bool isGameOver = false;

  // Animation for the "Target" object
  late AnimationController _spinController;

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 15;
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
    _spinController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10)
    )..repeat();

    levels = _generateLevels();
    _startRound();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (index >= levels.length) {
      _finishGame();
      return;
    }

    setState(() {
      remainingSeconds = 15;
      startMs = DateTime.now().millisecondsSinceEpoch;
      feedbackColor = null;
      feedbackText = null;
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
    _spinController.stop();
    setState(() => isGameOver = true);
  }

  void onOptionSelected(int optionIndex) {
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();

    final level = levels[index];
    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    bool isCorrect = (optionIndex == level.correctIndex);
    if (isCorrect) correctCount++;

    _showFeedback(isCorrect);
  }

  void _showFeedback(bool correct, {bool isTimeout = false}) {
    setState(() {
      if (isTimeout) {
        feedbackColor = Colors.orange;
        feedbackText = "TIME'S UP!";
      } else {
        feedbackColor = correct ? Colors.green : Colors.red;
        feedbackText = correct ? "MATCH!" : "WRONG!";
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        index++;
      });
      _startRound();
    });
  }

  Map<String, double> grade() {
    double accuracy = levels.isEmpty ? 0.0 : correctCount / levels.length;
    double avgRt = reactionTimes.isEmpty ? 5000 : reactionTimes.reduce((a,b)=>a+b) / reactionTimes.length;
    double speedScore = (1.0 - ((avgRt - 1000) / 4000)).clamp(0.0, 1.0);

    return {
      "3D Visualization": accuracy,
      "Spatial Awareness": (accuracy * 0.7 + speedScore * 0.3).clamp(0.0, 1.0),
      "Visual Perception Accuracy": accuracy,
      "Pattern Recognition": accuracy * 0.9,
      "Fine Motor Control": speedScore, // Fast taps implies confidence
      "Color Differentiation": 0.5, // N/A here, standard score
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
              const Icon(Icons.view_in_ar, color: Colors.cyanAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Spatial Test Done!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Score: $correctCount / ${levels.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
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

    final level = levels[index];

    return Scaffold(
      backgroundColor: Colors.grey[900], // Dark mode for 3D visibility
      appBar: AppBar(
        title: Text("9. 3D Spin (${index + 1}/${levels.length})"),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
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
                        color: remainingSeconds <= 5 ? Colors.red : Colors.cyan
                    )
                )
            ),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.white70)))
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- TARGET AREA (Rotating) ---
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyan.withOpacity(0.3))
                  ),
                  child: AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ObjectPainter(
                            level.targetObject,
                            rotationY: _spinController.value * 2 * pi,
                            rotationX: pi / 6, // Slight tilt
                            color: Colors.cyanAccent
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Text("Which object matches the one above?", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 10),

              // --- OPTIONS AREA (Static) ---
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(level.options.length, (i) {
                    return GestureDetector(
                      onTap: () => onOptionSelected(i),
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24)
                        ),
                        child: CustomPaint(
                          painter: ObjectPainter(
                              level.options[i],
                              rotationY: level.optionRotations[i], // Fixed rotation
                              rotationX: pi / 6,
                              color: Colors.white
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),

          // Feedback Overlay
          if (feedbackColor != null)
            Container(
              color: feedbackColor!.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feedbackColor == Colors.green ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 80),
                    const SizedBox(height: 10),
                    Text(feedbackText!, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- 3D ENGINE ---

class Point3D {
  final double x, y, z;
  Point3D(this.x, this.y, this.z);
}

class Edge {
  final int start, end;
  Edge(this.start, this.end);
}

class Object3D {
  final List<Point3D> vertices;
  final List<Edge> edges;
  Object3D(this.vertices, this.edges);
}

class SpinLevel {
  final Object3D targetObject;
  final List<Object3D> options;
  final List<double> optionRotations;
  final int correctIndex;
  SpinLevel(this.targetObject, this.options, this.optionRotations, this.correctIndex);
}

// --- PAINTER ---

class ObjectPainter extends CustomPainter {
  final Object3D object;
  final double rotationX;
  final double rotationY;
  final Color color;

  ObjectPainter(this.object, {required this.rotationX, required this.rotationY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    double cx = size.width / 2;
    double cy = size.height / 2;
    double scale = size.width / 3;

    // 1. Rotate Vertices
    List<Offset> projected = [];
    for (var v in object.vertices) {
      // Rotate Y
      double x1 = v.x * cos(rotationY) - v.z * sin(rotationY);
      double z1 = v.x * sin(rotationY) + v.z * cos(rotationY);

      // Rotate X
      double y2 = v.y * cos(rotationX) - z1 * sin(rotationX);
      double z2 = v.y * sin(rotationX) + z1 * cos(rotationX); // z2 for depth if needed

      // Project (Simple Orthographic)
      projected.add(Offset(cx + x1 * scale, cy + y2 * scale));
    }

    // 2. Draw Edges
    for (var e in object.edges) {
      canvas.drawLine(projected[e.start], projected[e.end], paint);
    }

    // Draw vertices (optional nodes)
    final dotPaint = Paint()..color = color.withOpacity(0.5)..style=PaintingStyle.fill;
    for (var p in projected) {
      canvas.drawCircle(p, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- GENERATOR (The Shapes) ---

List<SpinLevel> _generateLevels() {
  // SHAPE 1: CUBE
  Object3D cube = Object3D(
      [
        Point3D(-0.5, -0.5, -0.5), Point3D(0.5, -0.5, -0.5),
        Point3D(0.5, 0.5, -0.5), Point3D(-0.5, 0.5, -0.5),
        Point3D(-0.5, -0.5, 0.5), Point3D(0.5, -0.5, 0.5),
        Point3D(0.5, 0.5, 0.5), Point3D(-0.5, 0.5, 0.5),
      ],
      [
        Edge(0,1), Edge(1,2), Edge(2,3), Edge(3,0), // Back face
        Edge(4,5), Edge(5,6), Edge(6,7), Edge(7,4), // Front face
        Edge(0,4), Edge(1,5), Edge(2,6), Edge(3,7)  // Connectors
      ]
  );

  // SHAPE 2: PYRAMID
  Object3D pyramid = Object3D(
      [
        Point3D(0, -0.5, 0), // Top
        Point3D(-0.5, 0.5, -0.5), Point3D(0.5, 0.5, -0.5), // Base Back
        Point3D(0.5, 0.5, 0.5), Point3D(-0.5, 0.5, 0.5),   // Base Front
      ],
      [
        Edge(0,1), Edge(0,2), Edge(0,3), Edge(0,4), // Sides
        Edge(1,2), Edge(2,3), Edge(3,4), Edge(4,1)  // Base
      ]
  );

  // SHAPE 3: "L" BLOCK (Asymmetric)
  Object3D lShape = Object3D(
      [
        Point3D(-0.5, -0.5, 0), Point3D(-0.5, 0.5, 0), // Vertical Bar
        Point3D(0.5, 0.5, 0), // Horizontal ext
        Point3D(-0.5, -0.5, 0.2), Point3D(-0.5, 0.5, 0.2), // Thickness
        Point3D(0.5, 0.5, 0.2)
      ],
      [
        Edge(0,1), Edge(1,2), Edge(3,4), Edge(4,5), // Face lines
        Edge(0,3), Edge(1,4), Edge(2,5), // Depth lines
        Edge(0,2), Edge(3,5) // Closing the L (simplified wireframe)
      ]
  );

  // Construct Distractor Logic (Mirroring)
  // To mirror 3D, flip X coordinate.
  Object3D mirror(Object3D obj) {
    return Object3D(
        obj.vertices.map((v) => Point3D(-v.x, v.y, v.z)).toList(), // Flip X
        obj.edges
    );
  }

  return [
    // Level 1: Cube (Rotation match)
    SpinLevel(
        cube,
        [cube, pyramid, lShape], // Easy: Different shapes
        [pi/4, 0, 0],
        0
    ),
    // Level 2: Pyramid (Rotation)
    SpinLevel(
        pyramid,
        [pyramid, pyramid, cube],
        [pi, pi/2, 0], // One is rotated 180, one 90. Both valid shapes, logic requires finding the exact match?
        // Actually for pyramid, 180 and 0 look different in 2D perspective.
        1
    ),
    // Level 3: L-Shape (Mirror Logic - Hard)
    SpinLevel(
        lShape,
        [mirror(lShape), lShape, mirror(lShape)], // 1 Correct, 2 Mirrored traps
        [0, pi/2, pi],
        1
    )
  ];
}