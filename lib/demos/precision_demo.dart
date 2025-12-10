// lib/demos/precision_demo.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui'; // For Points/Offsets
import 'package:flutter/material.dart';

class PrecisionDemoWidget extends StatefulWidget {
  const PrecisionDemoWidget({Key? key}) : super(key: key);

  @override
  _PrecisionDemoWidgetState createState() => _PrecisionDemoWidgetState();
}

class _PrecisionDemoWidgetState extends State<PrecisionDemoWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Offset> demoPath;

  // Demo State
  bool showSuccess = false;

  @override
  void initState() {
    super.initState();
    // Initialize the demo path
    demoPath = _generateDemoPath(300, 400);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Trace takes 3 seconds
    );

    _startDemoLoop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startDemoLoop() async {
    while (mounted) {
      // 1. Reset
      setState(() => showSuccess = false);
      _controller.reset();

      // 2. Pause before starting
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // 3. Trace the path
      await _controller.forward();
      if (!mounted) return;

      // 4. Show Success
      setState(() => showSuccess = true);

      // 5. Hold Success screen
      await Future.delayed(const Duration(milliseconds: 2000));
    }
  }

  List<Offset> _generateDemoPath(double w, double h) {
    List<Offset> points = [];

    // CHANGED: Increased top padding to 100.0 to clear the text
    double topPadding = 100.0;
    double bottomPadding = 60.0;

    double startY = topPadding;
    double endY = h - bottomPadding;
    int steps = 60;

    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      double y = startY + (endY - startY) * t;
      // Simple Sine Wave
      double x = (w / 2) + sin(t * pi * 2) * (w / 4);
      points.add(Offset(x, y));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Stack(
        children: [
          // 1. The Game Area (Canvas)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: DemoPathPainter(
                      pathPoints: demoPath,
                      progress: _controller.value,
                      pathWidth: 50.0 // Scaled for demo
                  ),
                );
              },
            ),
          ),

          // 2. Instructions Header (Now clearly separated from the path)
          Positioned(
            top: 24, left: 0, right: 0,
            child: Center(
              child: Text(
                  "Trace without hitting walls",
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14)
              ),
            ),
          ),

          // 3. Success Badge (Kept at bottom)
          if (showSuccess)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0,4))]
                  ),
                  child: const Text(
                      "PERFECT!",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- EXACT PAINTER FROM GAME (Adapted for Animation) ---
class DemoPathPainter extends CustomPainter {
  final List<Offset> pathPoints;
  final double progress; // 0.0 to 1.0
  final double pathWidth;

  DemoPathPainter({required this.pathPoints, required this.progress, required this.pathWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.isEmpty) return;

    // 1. Draw The "Road" (Grey Background)
    final roadPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = pathWidth;

    Path fullPath = Path();
    fullPath.moveTo(pathPoints.first.dx, pathPoints.first.dy);
    for (int i = 1; i < pathPoints.length; i++) {
      fullPath.lineTo(pathPoints[i].dx, pathPoints[i].dy);
    }
    canvas.drawPath(fullPath, roadPaint);

    // 2. Draw Center Line (White)
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(fullPath, centerPaint);

    // 3. Draw Start & End Circles
    canvas.drawCircle(pathPoints.first, pathWidth/1.5, Paint()..color = Colors.green);
    canvas.drawCircle(pathPoints.last, pathWidth/1.5, Paint()..color = Colors.redAccent);

    // Labels
    TextPainter(
        text: const TextSpan(text: "START", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
        textDirection: TextDirection.ltr
    )
      ..layout()
      ..paint(canvas, pathPoints.first - const Offset(16, 6));

    TextPainter(
        text: const TextSpan(text: "END", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
        textDirection: TextDirection.ltr
    )
      ..layout()
      ..paint(canvas, pathPoints.last - const Offset(10, 6));

    // 4. Draw Animated User Trace (Purple)
    if (progress > 0) {
      final tracePaint = Paint()
        ..color = Colors.purpleAccent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8;

      Path tracePath = Path();
      tracePath.moveTo(pathPoints.first.dx, pathPoints.first.dy);

      // Calculate how many points to draw based on progress
      int limit = (pathPoints.length * progress).floor();
      for (int i = 1; i < limit; i++) {
        tracePath.lineTo(pathPoints[i].dx, pathPoints[i].dy);
      }

      // Interpolate the very last segment for smooth animation
      if (limit < pathPoints.length - 1) {
        double segmentProgress = (pathPoints.length * progress) - limit;
        Offset p1 = pathPoints[limit];
        Offset p2 = pathPoints[limit + 1];
        Offset currentPos = Offset.lerp(p1, p2, segmentProgress)!;
        tracePath.lineTo(currentPos.dx, currentPos.dy);

        // Draw "Finger" indicator circle at tip
        canvas.drawCircle(currentPos, 12, Paint()..color = Colors.purple.withOpacity(0.5));
        canvas.drawCircle(currentPos, 6, Paint()..color = Colors.purple);
      }

      canvas.drawPath(tracePath, tracePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}