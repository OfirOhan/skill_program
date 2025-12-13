import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const int _roundLimitMs = 20000; // 20s timeout penalty for speed scoring

  @override
  void initState() {
    super.initState();
    // Rotates continuously
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
    HapticFeedback.vibrate();

    // Anti-cheat: if you don't answer, you get a max-time reaction time.
    reactionTimes.add(_roundLimitMs);

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
    final int n = levels.length;
    if (n == 0) {
      return {
        "Mental Rotation": 0.0,
        "Spatial Awareness": 0.0,
        "Pattern Recognition": 0.0,
        "Information Processing Speed": 0.0,
        "Decision Under Pressure": 0.0,
      };
    }

    // Accuracy (timeouts automatically count as wrong because correctCount doesn't increase)
    final double accuracy = (correctCount / n).clamp(0.0, 1.0);

    // Avg RT (includes timeout penalty if user didn't answer)
    final double avgRt = reactionTimes.isEmpty
        ? _roundLimitMs.toDouble()
        : reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;

    // Raw speed: 2.5s = fast (1.0), 14s = slow (0.0)
    final double rawSpeed = (1.0 - ((avgRt - 2500.0) / 11500.0)).clamp(0.0, 1.0);

    // Earned speed: you only "get speed credit" if you're correct (anti-guess)
    final double earnedSpeed = (rawSpeed * accuracy).clamp(0.0, 1.0);

    final double mentalRotation = (0.80 * accuracy + 0.20 * earnedSpeed).clamp(0.0, 1.0);
    final double spatialAwareness = (0.70 * accuracy + 0.30 * earnedSpeed).clamp(0.0, 1.0);
    final double patternRecognition = accuracy;

    // Under pressure: mostly accuracy, small benefit from being quick
    final double decisionUnderPressure = (0.80 * accuracy + 0.20 * rawSpeed).clamp(0.0, 1.0);

    return {
      "Mental Rotation": mentalRotation,
      "Spatial Awareness": spatialAwareness,
      "Pattern Recognition": patternRecognition,
      "Information Processing Speed": earnedSpeed,
      "Decision Under Pressure": decisionUnderPressure,
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
              const Icon(Icons.view_in_ar, color: Colors.indigoAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Spatial Test Done!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Score: $correctCount / ${levels.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                   HapticFeedback.lightImpact();
                   Navigator.of(context).pop(grade());
                },
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("9. 3D Spin (${index + 1}/${levels.length})"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
          Column(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.withOpacity(0.3))
                  ),
                  child: AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ObjectPainter(
                            level.targetObject,
                            rotationY: _spinController.value * 2 * pi,
                            rotationX: pi / 8,
                            color: Colors.indigo
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Text("Which object matches the one above?", style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
                            ]
                        ),
                        child: CustomPaint(
                          painter: ObjectPainter(
                              level.options[i],
                              rotationY: level.optionRotations[i],
                              rotationX: pi / 8,
                              color: Colors.blueGrey
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
              color: feedbackColor!.withOpacity(0.9),
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
    final paint = Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
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
    for (var p in projected) canvas.drawCircle(p, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- CONTENT GENERATOR (LOGIC FIXED) ---

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

  // SHAPE: "The Crank" (Replaces the symmetric Claw)
  // This shape is CHIRAL (Asymmetric). Mirroring it creates a distinct object.
  // Shape: Up, Right, Forward.
  Object3D crank = _createPolycube([
    Point3D(0,0,0),
    Point3D(0,1,0), // Up
    Point3D(1,1,0), // Right
    Point3D(1,1,1)  // Forward
  ]);

  Object3D mirror(Object3D obj) {
    return Object3D(
        obj.vertices.map((v) => Point3D(-v.x, v.y, v.z)).toList(),
        obj.edges
    );
  }

  return [
    // 1. THE CHAIR
    SpinLevel(
        chair,
        [tShape, chair, snake],
        [pi/2, pi, 0], // Option 1 is Correct
        1
    ),

    // 2. THE SNAKE
    SpinLevel(
        snake,
        [snake, mirror(snake), _createPolycube([Point3D(0,0,0), Point3D(1,0,0), Point3D(1,1,0), Point3D(0,1,0)])],
        [pi/2, pi/2, 0], // Option 0 is Correct
        0
    ),

    // 3. THE CRANK (Fixed: Now asymmetric)
    SpinLevel(
        crank,
        [mirror(crank), crank, mirror(crank)], // Mirror is now logically WRONG
        [0, 3*pi/2, pi],
        1 // Center is correct
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