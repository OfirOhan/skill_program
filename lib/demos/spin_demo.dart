// lib/demos/spin_demo.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class SpinDemoWidget extends StatefulWidget {
  const SpinDemoWidget({Key? key}) : super(key: key);

  @override
  _SpinDemoWidgetState createState() => _SpinDemoWidgetState();
}

class _SpinDemoWidgetState extends State<SpinDemoWidget> with SingleTickerProviderStateMixin {
  // Demo State
  int step = 0;
  Timer? _loopTimer;
  late AnimationController _spinController;

  // The 3D Objects
  late Object3D targetObj;
  late List<Object3D> options;

  @override
  void initState() {
    super.initState();
    _initObjects();

    // Continuous rotation for the top object
    _spinController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8)
    )..repeat();

    _startDemoLoop();
  }

  void _initObjects() {
    // DEMO-ONLY SHAPE: "The Stairs"
    // (0,0,0) -> (1,0,0) -> (1,1,0) -> (2,1,0)
    targetObj = _createPolycube([
      Point3D(0,0,0), Point3D(1,0,0), // Bottom Step
      Point3D(1,1,0), Point3D(2,1,0)  // Top Step
    ]);

    // Distractor 1: "The Line" (Obviously wrong)
    var line = _createPolycube([
      Point3D(0,0,0), Point3D(1,0,0), Point3D(2,0,0), Point3D(3,0,0)
    ]);

    // Distractor 2: "The U-Shape" (Obviously wrong)
    var uShape = _createPolycube([
      Point3D(0,0,0), Point3D(0,1,0), // Left Up
      Point3D(1,0,0), // Bottom
      Point3D(2,0,0), Point3D(2,1,0)  // Right Up
    ]);

    // Options: [Line, Stairs (Correct), U-Shape]
    options = [line, targetObj, uShape];
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  void _startDemoLoop() {
    // RESET
    setState(() => step = 0);

    // Step 0: OBSERVE (0s - 2.0s)
    _loopTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;

      // Step 1: SELECT CORRECT OPTION (2.0s)
      setState(() => step = 1); // Highlight Middle (Index 1)

      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;

        // Step 2: SHOW FEEDBACK (3.0s)
        setState(() => step = 2); // Show "MATCH!"

        // RESTART (4.5s)
        Timer(const Duration(milliseconds: 1500), _startDemoLoop);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Column(
        children: [
          // 1. Header
          const Text(
              "Find the matching object",
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 14)
          ),
          const SizedBox(height: 16),

          // 2. Target Container (Indigo Theme)
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.withOpacity(0.3))
              ),
              child: AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: DemoObjectPainter(
                        targetObj,
                        rotationY: _spinController.value * 2 * pi,
                        rotationX: pi / 8,
                        color: Colors.indigo
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Options Row
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) {
                bool isCorrect = (i == 1);
                bool isSelected = (step >= 1) && isCorrect;
                bool showSuccess = (step == 2) && isCorrect;

                Color borderColor = Colors.grey[300]!;
                Color bgColor = Colors.white;

                if (showSuccess) {
                  borderColor = Colors.green;
                  bgColor = Colors.green[50]!;
                } else if (isSelected) {
                  borderColor = Colors.indigo;
                  bgColor = Colors.indigo[50]!;
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]
                          : null
                  ),
                  child: CustomPaint(
                    painter: DemoObjectPainter(
                        options[i],
                        // Static rotations for options so they look different but recognizable
                        rotationY: i == 1 ? pi : pi/4,
                        rotationX: pi / 8,
                        color: Colors.blueGrey
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Feedback Badge
          AnimatedOpacity(
            opacity: step == 2 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                  "MATCH!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- 3D UTILS (Same as Game) ---

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

class DemoObjectPainter extends CustomPainter {
  final Object3D object;
  final double rotationX;
  final double rotationY;
  final Color color;

  DemoObjectPainter(this.object, {required this.rotationX, required this.rotationY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    double cx = size.width / 2;
    double cy = size.height / 2;
    double scale = size.width / 5; // Scale adjusted for demo box size

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