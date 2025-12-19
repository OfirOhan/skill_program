// lib/precision_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrecisionGame extends StatefulWidget {
  const PrecisionGame({Key? key}) : super(key: key);

  @override
  _PrecisionGameState createState() => _PrecisionGameState();
}

class _PrecisionGameState extends State<PrecisionGame> {
  // Game Config
  int level = 0;
  bool isGameOver = false;

  // FIXED: Key to find the exact drawing area for coordinate conversion
  final GlobalKey _paintKey = GlobalKey();

  // Level Data
  late List<Offset> currentPathSpine;
  double pathWidth = 60.0;

  // User Input
  List<Offset> userTrace = [];
  int touchCount = 0;
  double totalDeviation = 0.0;
  int sampleCount = 0;
  bool levelCompleted = false;

  // Timer
  Timer? _levelTimer;
  int remainingSeconds = 15;

  // Metrics
  int totalTouches = 0;
  double avgDeviation = 0.0;
  int levelsCompleted = 0;

  double _sumOffRate = 0.0;   // off-path samples / total samples (per level)
  double _sumDevNorm = 0.0;   // avg deviation normalized by (pathWidth/2) (per level)
  int _metricLevels = 0;      // how many levels contributed evidence

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLevel();
    });
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    remainingSeconds = 15;
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _levelTimer?.cancel();
    _nextLevel();
  }

  void _finishGame() {
    _levelTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _startLevel() {
    if (level >= 3) {
      _finishGame();
      return;
    }

    final size = MediaQuery.of(context).size;
    final h = size.height - 150; // Approx canvas height
    final w = size.width;

    setState(() {
      userTrace = [];
      levelCompleted = false;

      if (level == 0) {
        pathWidth = 70.0;
        currentPathSpine = _generatePath(0, w, h);
      } else if (level == 1) {
        pathWidth = 50.0;
        currentPathSpine = _generatePath(1, w, h);
      } else {
        pathWidth = 35.0;
        currentPathSpine = _generatePath(2, w, h);
      }
    });

    _startTimer();
  }

  void _nextLevel() {
    // --- record evidence for this level (anti-cheat included) ---
    if (sampleCount >= 10) {
      final offRate = (touchCount / sampleCount).clamp(0.0, 1.0);

      final avgDevPx = totalDeviation / sampleCount;
      final devNorm = (avgDevPx / max(1.0, (pathWidth / 2))).clamp(0.0, 1.0);

      _sumOffRate += offRate;
      _sumDevNorm += devNorm;
      _metricLevels++;
    } else {
      // If they barely touched / did nothing, treat as worst evidence (prevents “no input” exploits)
      _sumOffRate += 1.0;
      _sumDevNorm += 1.0;
      _metricLevels++;
    }

    // Reset per-level counters
    touchCount = 0;
    totalDeviation = 0;
    sampleCount = 0;

    level++;
    _startLevel();
  }


  void _onPanStart(DragStartDetails details) {
    _handleInput(details.globalPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _handleInput(details.globalPosition);
  }

  void _handleInput(Offset globalPos) {
    if (isGameOver || levelCompleted) return;

    final RenderBox? box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    Offset localPos = box.globalToLocal(globalPos);

    setState(() {
      userTrace.add(localPos);
      _checkCollision(localPos);
    });
  }

  void _checkCollision(Offset userPos) {
    double minDistance = double.infinity;

    for (var p in currentPathSpine) {
      if ((p.dy - userPos.dy).abs() < 50) {
        double d = (p - userPos).distance;
        if (d < minDistance) minDistance = d;
      }
    }

    if (currentPathSpine.isNotEmpty && (userPos.dy >= currentPathSpine.last.dy - 20)) {
      if ((userPos - currentPathSpine.last).distance < pathWidth) {
        _handleWin();
        return;
      }
    }

    if (minDistance > (pathWidth / 2)) {
      touchCount++;
      if (touchCount % 5 == 0) HapticFeedback.lightImpact(); // Subtle feedback on errors
    }

    totalDeviation += minDistance;
    sampleCount++;
  }

  void _handleWin() {
    _levelTimer?.cancel();
    levelCompleted = true;
    levelsCompleted++;
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Round ${level+1} Clear!"),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 500),
        )
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _nextLevel();
    });
  }

  // --- FIXED PATH GENERATOR (Added Padding) ---
  List<Offset> _generatePath(int type, double w, double h) {
    List<Offset> points = [];
    double steps = 100;

    // FIXED: Add substantial padding so circles don't touch screen edges
    double paddingY = 80.0;
    double startY = paddingY;
    double endY = h - paddingY;

    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      double y = startY + (endY - startY) * t;
      double x = w / 2;

      if (type == 0) {
        x += sin(t * pi * 2) * (w / 4);
      } else if (type == 1) {
        x += sin(t * pi * 3) * (w / 3);
      } else {
        x += sin(t * pi * 5) * (w / 2.5) + cos(t * pi * 2) * 20;
      }
      points.add(Offset(x, y));
    }
    return points;
  }

  Map<String, double> grade() {
    if (_metricLevels == 0) {
      return {
        "Fine Motor Control": 0.0,
        "Visuomotor Integration": 0.0,
        "Movement Steadiness": 0.0,
      };
    }

    final completion = (levelsCompleted / 3.0).clamp(0.0, 1.0);

    final meanOffRate = (_sumOffRate / _metricLevels).clamp(0.0, 1.0);
    final meanDevNorm = (_sumDevNorm / _metricLevels).clamp(0.0, 1.0);

    // Tracking quality: balance “went out of bounds” + “how far from center”
    final trackingQuality =
    (1.0 - (0.55 * meanDevNorm + 0.45 * meanOffRate)).clamp(0.0, 1.0);

    // Steadiness: more deviation-heavy (wobble)
    final steadiness =
    (1.0 - (0.75 * meanDevNorm + 0.25 * meanOffRate)).clamp(0.0, 1.0);

    // Canonical skills
    final fineMotorControl = trackingQuality;
    final visuomotorIntegration = (trackingQuality * completion).clamp(0.0, 1.0);
    final movementSteadiness = steadiness;

    return {
      "Fine Motor Control": fineMotorControl,
      "Visuomotor Integration": visuomotorIntegration,
      "Movement Steadiness": movementSteadiness,
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
              const Icon(Icons.fingerprint, color: Colors.purpleAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Path Traced!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Wall Hits: $totalTouches", style: const TextStyle(color: Colors.white70, fontSize: 18)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("10. Precision Path"),
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
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        child: Container(
          key: _paintKey,
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: CustomPaint(
            painter: PathPainter(
                currentPathSpine,
                userTrace,
                pathWidth
            ),
          ),
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final List<Offset> pathPoints;
  final List<Offset> userTrace;
  final double width;

  PathPainter(this.pathPoints, this.userTrace, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.isEmpty) return;

    // 1. Draw The "Road"
    final roadPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;

    Path path = Path();
    path.moveTo(pathPoints.first.dx, pathPoints.first.dy);
    for (int i = 1; i < pathPoints.length; i++) {
      path.lineTo(pathPoints[i].dx, pathPoints[i].dy);
    }
    canvas.drawPath(path, roadPaint);

    // 2. Draw Center Line
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, centerPaint);

    // 3. Draw Start & End
    canvas.drawCircle(pathPoints.first, width/1.5, Paint()..color = Colors.green);
    canvas.drawCircle(pathPoints.last, width/1.5, Paint()..color = Colors.redAccent);

    TextPainter(text: const TextSpan(text: "START", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)
      ..layout()
      ..paint(canvas, pathPoints.first - const Offset(20, 7));

    TextPainter(text: const TextSpan(text: "END", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)
      ..layout()
      ..paint(canvas, pathPoints.last - const Offset(15, 7));

    // 4. Draw User Trace
    final tracePaint = Paint()
      ..color = Colors.purpleAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    if (userTrace.isNotEmpty) {
      Path trace = Path();
      trace.moveTo(userTrace.first.dx, userTrace.first.dy);
      for (int i = 1; i < userTrace.length; i++) {
        trace.lineTo(userTrace[i].dx, userTrace[i].dy);
      }
      canvas.drawPath(trace, tracePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}