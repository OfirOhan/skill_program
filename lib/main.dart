// lib/main.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'session_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Career Alignment',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF3F2E9E),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. BACKGROUND PATTERN
          Positioned.fill(
            child: CustomPaint(
              painter: DotGridPainter(),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Hello, Candidate",
                    style: TextStyle(
                      color: Color(0xFF505050),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // --- Center Hero ---
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // THE CUSTOM ICON REPLACEMENT
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3F2E9E).withOpacity(0.15),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          // Using CustomPaint to draw your specific Hexagon icon
                          child: Padding(
                            padding: const EdgeInsets.all(28.0), // Padding ensures icon fits inside circle
                            child: CustomPaint(
                              painter: HexagonNetworkPainter(
                                color: const Color(0xFF3F2E9E),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        const Text(
                          "Discover Your\nTrue Potential",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 4),

                  // --- Bottom Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SessionManager()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF151030),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "START ASSESSMENT",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- BACKGROUND DOTS PAINTER ---
class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const double gap = 25.0;
    final List<Offset> points = [];

    for (double i = gap / 2; i < size.width; i += gap) {
      for (double j = gap / 2; j < size.height; j += gap) {
        points.add(Offset(i, j));
      }
    }
    canvas.drawPoints(ui.PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- NEW CUSTOM ICON PAINTER (The Hexagon Network) ---
class HexagonNetworkPainter extends CustomPainter {
  final Color color;
  HexagonNetworkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0 // Thickness of lines
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Calculate the 6 vertices of the hexagon
    final List<Offset> hexPoints = [];
    for (int i = 0; i < 6; i++) {
      // Start from angle -pi/2 (top) + (pi/3 * i)
      // Actually standard pointy-top hex starts at -90deg (-pi/2)
      // Flat-topped hex (like your image) starts at 0deg or 30deg depending on orientation.
      // Your image has a point at the top.
      double angle = (math.pi / 3) * i - (math.pi / 2); // -90 degrees start
      hexPoints.add(Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ));
    }

    // 2. Draw Outer Hexagon
    final path = Path()..moveTo(hexPoints[0].dx, hexPoints[0].dy);
    for (int i = 1; i < 6; i++) {
      path.lineTo(hexPoints[i].dx, hexPoints[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);

    // 3. Draw Inner Connections (The "Network")
    // Based on your image:
    // Top(0) connects to Bottom-Right(2) and Bottom-Left(4)
    // Bottom(3) connects to Top-Right(1) and Top-Left(5)
    // Center point connects to all? Let's mimic the image closely:
    // It looks like a projection of a cube or a star shape.

    // Connecting every other point creates the internal triangle star
    final innerPath = Path();
    // Triangle 1 (0 -> 2 -> 4 -> 0)
    innerPath.moveTo(hexPoints[0].dx, hexPoints[0].dy);
    innerPath.lineTo(hexPoints[2].dx, hexPoints[2].dy);
    innerPath.lineTo(hexPoints[4].dx, hexPoints[4].dy);
    innerPath.close();

    // Triangle 2 (1 -> 3 -> 5 -> 1)
    innerPath.moveTo(hexPoints[1].dx, hexPoints[1].dy);
    innerPath.lineTo(hexPoints[3].dx, hexPoints[3].dy);
    innerPath.lineTo(hexPoints[5].dx, hexPoints[5].dy);
    innerPath.close();

    canvas.drawPath(innerPath, paint);

    // Center point connection (vertical line down the middle?)
    // Your image has a vertical line from Top(0) to Bottom(3)
    canvas.drawLine(hexPoints[0], hexPoints[3], paint);

    // 4. Draw Dots at vertices and intersections
    double dotRadius = 4.0;

    // Outer vertices
    for (var point in hexPoints) {
      canvas.drawCircle(point, dotRadius, dotPaint);
    }

    // Center dot
    canvas.drawCircle(center, dotRadius, dotPaint);

    // Calculate inner intersection points for extra detail (optional, adds realism)
    // Midpoints between center and vertices?
    // Let's stick to the main vertices and center for the clean look.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}