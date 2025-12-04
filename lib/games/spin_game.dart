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
  late List<SpinLevel> levels;
  int index = 0;
  bool isGameOver = false;

  late AnimationController _spinController;
  Timer? _roundTimer;
  int remainingSeconds = 20;
  int startMs = 0;

  int correctCount = 0;
  List<int> reactionTimes = [];
  Color? feedbackColor;
  String? feedbackText;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    levels = _generateHardLevels();
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
      remainingSeconds = 20;
      startMs = DateTime.now().millisecondsSinceEpoch;
      feedbackColor = null;
      feedbackText = null;
    });

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) _handleTimeout();
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
        feedbackText = "TOO SLOW!";
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
    double speedScore = (1.0 - ((avgRt - 2000) / 6000)).clamp(0.0, 1.0);

    return {
      "3D Visualization": accuracy,
      "Spatial Awareness": (accuracy * 0.7 + speedScore * 0.3).clamp(0.0, 1.0),
      "Visual Perception Accuracy": accuracy,
      "Pattern Recognition": accuracy * 0.9,
      "Fine Motor Control": speedScore,
      "Color Differentiation": 0.5,
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
      backgroundColor: Colors.grey[900],
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
                            rotationX: pi / 8,
                            color: Colors.cyanAccent
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Text("Which object matches the one above?", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 10),

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
                              rotationY: level.optionRotations[i],
                              rotationX: pi / 8,
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

class ObjectPainter extends CustomPainter {
  final Object3D object;
  final double rotationX;
  final double rotationY;
  final Color color;

  ObjectPainter(this.object, {required this.rotationX, required this.rotationY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    double cx = size.width / 2;
    double cy = size.height / 2;
    double scale = size.width / 4;

    List<Offset> projected = [];
    for (var v in object.vertices) {
      double x1 = v.x * cos(rotationY) - v.z * sin(rotationY);
      double z1 = v.x * sin(rotationY) + v.z * cos(rotationY);
      double y2 = v.y * cos(rotationX) - z1 * sin(rotationX);

      projected.add(Offset(cx + x1 * scale, cy + y2 * scale));
    }

    for (var e in object.edges) {
      canvas.drawLine(projected[e.start], projected[e.end], paint);
    }

    final dotPaint = Paint()..color = color.withOpacity(0.6)..style=PaintingStyle.fill;
    for (var p in projected) canvas.drawCircle(p, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- HARDCORE CONTENT GENERATOR (FIXED ROUND 1) ---

List<SpinLevel> _generateHardLevels() {

  // SHAPE 1: "The Chair"
  Object3D chair = _createPolycube([
    Point3D(0,0,0), Point3D(0,1,0), Point3D(0,2,0), // Vertical
    Point3D(1,0,0) // Horizontal Leg
  ]);

  // SHAPE: "T-Shape" (Distractor for Chair)
  Object3D tShape = _createPolycube([
    Point3D(0,0,0), Point3D(0,1,0), Point3D(0,2,0), // Vertical
    Point3D(1,1,0) // Horizontal Mid
  ]);

  // SHAPE: "The Snake"
  Object3D snake = _createPolycube([
    Point3D(0,0,0), Point3D(1,0,0), // Base
    Point3D(1,1,0), // Up
    Point3D(1,1,1)  // Forward (Z-axis)
  ]);

  // SHAPE: "The Claw"
  Object3D claw = _createPolycube([
    Point3D(0,0,0),
    Point3D(1,0,0), Point3D(-1,0,0), // Wide Base
    Point3D(0,1,0), // Center Up
    Point3D(0,1,1)  // Hook Forward
  ]);

  Object3D mirror(Object3D obj) {
    return Object3D(
        obj.vertices.map((v) => Point3D(-v.x, v.y, v.z)).toList(),
        obj.edges
    );
  }

  return [
    // 1. THE CHAIR (FIXED: Replaced 'mirror' with 'tShape' to remove ambiguity)
    SpinLevel(
        chair,
        [tShape, chair, snake], // Option 0 is now clearly wrong (T-shape vs L-shape)
        [pi/2, pi, 0], // Option 1 is Correct (Rotated 180)
        1
    ),

    // 2. THE SNAKE
    SpinLevel(
        snake,
        [snake, mirror(snake), _createPolycube([Point3D(0,0,0), Point3D(1,0,0), Point3D(1,1,0), Point3D(0,1,0)])],
        [pi/2, pi/2, 0],
        0
    ),

    // 3. THE CLAW
    SpinLevel(
        claw,
        [mirror(claw), claw, mirror(claw)],
        [0, 3*pi/2, pi],
        1
    ),
  ];
}

Object3D _createPolycube(List<Point3D> blocks) {
  List<Point3D> verts = [];
  List<Edge> edges = [];

  for (int i=0; i<blocks.length; i++) {
    verts.add(Point3D(blocks[i].x * 0.8, -blocks[i].y * 0.8, blocks[i].z * 0.8));
  }

  for (int i=0; i<blocks.length; i++) {
    for (int j=i+1; j<blocks.length; j++) {
      if ((blocks[i].x - blocks[j].x).abs() + (blocks[i].y - blocks[j].y).abs() + (blocks[i].z - blocks[j].z).abs() == 1) {
        edges.add(Edge(i, j));
      }
    }
  }

  return Object3D(verts, edges);
}