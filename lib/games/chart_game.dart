import 'package:flutter/services.dart';
import '../grading/chart_grading.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ChartDashGame extends StatefulWidget {
  const ChartDashGame({Key? key}) : super(key: key);

  @override
  _ChartDashGameState createState() => _ChartDashGameState();
}

class _ChartDashGameState extends State<ChartDashGame> {
  late List<ChartQuestion> questions;
  int index = 0;
  bool isGameOver = false;

  Timer? _roundTimer;
  int remainingSeconds = 15;
  int startMs = 0;

  int correctCount = 0;
  List<int> reactionTimes = [];

  Color? feedbackColor;
  String? feedbackText;

  final List<bool> _qCorrect = [];
  final List<int> _qRtMs = [];
  final List<int> _qLimitMs = [];

  int _currentLimitMs = 15000;

  @override
  void initState() {
    super.initState();
    questions = _generateQuestions();
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (index >= questions.length) {
      _finishGame();
      return;
    }

    // Dynamic Time Limit based on difficulty
    int timeLimit = 15;
    if (index == 1) timeLimit = 15; // Moderate (Trend identification)
    if (index == 2) timeLimit = 25; // Moderate-Hard (Math calculation)
    if (index == 3) timeLimit = 30; // Hard (Revenue puzzle)
    if (index == 4) timeLimit = 35; // Very Hard (Multi-step average)
    _currentLimitMs = timeLimit * 1000;
    setState(() {
      remainingSeconds = timeLimit;
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
    HapticFeedback.vibrate();

    // Record explicit failure + full time cost (no free points)
    _qCorrect.add(false);
    _qRtMs.add(_currentLimitMs);
    _qLimitMs.add(_currentLimitMs);

    _showFeedback(false, isTimeout: true);
  }


  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _onOptionSelected(int optionIndex) {
    HapticFeedback.lightImpact(); // Selection feedback
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();

    final q = questions[index];
    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    bool isCorrect = (optionIndex == q.correctIndex);
    _qCorrect.add(isCorrect);
    _qRtMs.add(rt);
    _qLimitMs.add(_currentLimitMs);

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
        feedbackText = "TIME'S UP!";
      } else {
        feedbackColor = correct ? Colors.green : Colors.red;
        feedbackText = correct ? "CORRECT!" : "WRONG!";
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
    final int n = [
      questions.length,
      _qCorrect.length,
      _qRtMs.length,
      _qLimitMs.length,
    ].reduce((a, b) => a < b ? a : b);

    // Questions 2, 3, and 4 (indices 2, 3, 4) are math questions
    final List<bool> isMath = List.generate(n, (i) => i >= 2);

    return ChartGrading.grade(
      results: _qCorrect.take(n).toList(),
      reactionTimes: _qRtMs.take(n).toList(),
      isMathQuestion: isMath,
    );
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
              const Icon(Icons.bar_chart, color: Colors.blueAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Analysis Complete!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Score: $correctCount / ${questions.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
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

    final q = questions[index];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chart Dash"),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(12)),
                  child: Text(q.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ),
                const SizedBox(height: 10),

                // CHART
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 30, 20, 30),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, 2))]
                    ),
                    child: CustomPaint(
                      painter: ChartPainter(q.type, q.dataPoints, q.labels, highlightIndex: q.highlightIndex),
                      child: Container(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // OPTIONS
                Expanded(
                  flex: 3,
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: List.generate(q.options.length, (i) {
                      return ElevatedButton(
                        onPressed: () => _onOptionSelected(i),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[50],
                            foregroundColor: Colors.indigo[900],
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.indigo[100]!)
                        ),
                        child: Text(q.options[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      );
                    }),
                  ),
                ),
              ],
            ),
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

// --- DATA MODELS ---

enum ChartType { bar, line }

class ChartQuestion {
  final ChartType type;
  final String question;
  final List<double> dataPoints;
  final List<String> labels;
  final List<String> options;
  final int correctIndex;
  final int? highlightIndex;

  ChartQuestion({
    required this.type,
    required this.question,
    required this.dataPoints,
    required this.labels,
    required this.options,
    required this.correctIndex,
    this.highlightIndex,
  });
}

// --- PSYCHOMETRIC GENERATOR ---
List<ChartQuestion> _generateQuestions() {
  return [
    // LEVEL 1: EASY (15s)
    // Task: Simple comparison
    // Q: Which department had the LOWEST expense?
    ChartQuestion(
      type: ChartType.bar,
      question: "Which Dept spent the LEAST?",
      dataPoints: [120, 90, 150, 60],
      labels: ["HR", "IT", "MKT", "OPS"],
      options: ["HR", "IT", "MKT", "OPS"],
      correctIndex: 3, // OPS (60)
    ),

    // LEVEL 2: MODERATE (15s)
    // Task: Identify trend/growth
    // Q: Which month had the HIGHEST growth?
    // Jan→Feb: +10, Feb→Mar: +30 (HIGHEST), Mar→Apr: +5, Apr→May: +15
    ChartQuestion(
      type: ChartType.line,
      question: "Which month had the HIGHEST growth?",
      dataPoints: [40, 50, 80, 85, 100],
      labels: ["Jan", "Feb", "Mar", "Apr", "May"],
      options: ["Feb", "Mar", "Apr", "May"],
      correctIndex: 1, // Mar (+30)
    ),

    // LEVEL 3: MODERATE-HARD (25s)
    // Task: Percentage calculation
    // Feb: 40, Mar: 60
    // Formula: (60-40)/40 = 50%
    ChartQuestion(
      type: ChartType.line,
      question: "Calculate % Growth from Feb to Mar:",
      dataPoints: [50, 40, 60, 55, 80],
      labels: ["Jan", "Feb", "Mar", "Apr", "May"],
      options: ["20%", "33%", "50%", "100%"],
      correctIndex: 2, // 50%
    ),

    // LEVEL 4: HARD (30s)
    // Task: Multiplication puzzle
    // A (100u @ $2) = $200
    // B (50u @ $5) = $250 <-- Winner
    // C (80u @ $3) = $240
    // D (200u @ $1) = $200
    ChartQuestion(
      type: ChartType.bar,
      question: "If Price is:\nA=\$2, B=\$5, C=\$3, D=\$1\nWhich earned highest revenue?",
      dataPoints: [100, 50, 80, 200],
      labels: ["A", "B", "C", "D"],
      options: ["Product A", "Product B", "Product C", "Product D"],
      correctIndex: 1, // B ($250)
    ),

// LEVEL 5 ALTERNATIVE: RATIO NIGHTMARE (35s)
// Task: Weighted average with ratios
// Q: Team A (3 people) averages 80 units. Team B (2 people) averages 90 units.
//    What's the OVERALL average per person?
// Calculation:
// Team A total: 3 × 80 = 240
// Team B total: 2 × 90 = 180
// Total people: 3 + 2 = 5
// Overall avg: (240 + 180) / 5 = 420 / 5 = 84
// Chart shows: [80, 90] (Team A avg, Team B avg)
    ChartQuestion(
      type: ChartType.bar,
      question: "Team A (3 people) avg 80.\nTeam B (2 people) avg 90.\nOverall avg per person?",
      dataPoints: [80, 90],
      labels: ["Team A", "Team B"],
      options: ["84", "85", "86", "88"],
      correctIndex: 0, // 84
    ),
  ];
}

// --- PAINTER ---
class ChartPainter extends CustomPainter {
  final ChartType type;
  final List<double> data;
  final List<String> labels;
  final int? highlightIndex;

  ChartPainter(this.type, this.data, this.labels, {this.highlightIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final textStyle = const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold);

    // Axis
    final axisPaint = Paint()..color = Colors.grey[400]!..strokeWidth = 2;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);

    double maxVal = data.reduce(max);
    double gridMax = (maxVal / 10).ceil() * 10.0;
    if (gridMax < maxVal) gridMax += 10;

    // Grid
    for(int i=1; i<=4; i++) {
      double y = size.height - (size.height * (i/4));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = Colors.grey[200]!..strokeWidth = 1);
      _drawText(canvas, "${(gridMax * i/4).toInt()}", Offset(-15, y), const TextStyle(fontSize: 10, color: Colors.grey));
    }

    double barWidth = (size.width / data.length) * 0.5;
    double spacing = (size.width / data.length);

    if (type == ChartType.bar) {
      for (int i = 0; i < data.length; i++) {
        double h = (data[i] / gridMax) * size.height;
        double left = i * spacing + (spacing - barWidth) / 2;
        double top = size.height - h;

        paint.color = Colors.blueAccent;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barWidth, h), const Radius.circular(4)), paint);

        _drawText(canvas, labels[i], Offset(left + barWidth/2, size.height + 10), textStyle);
        _drawText(canvas, data[i].toInt().toString(), Offset(left + barWidth/2, top - 15), const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey));
      }
    }
    else if (type == ChartType.line) {
      paint.color = Colors.orange;
      paint.strokeWidth = 4;
      paint.style = PaintingStyle.stroke;

      Path path = Path();
      List<Offset> points = [];
      for (int i = 0; i < data.length; i++) {
        double h = (data[i] / gridMax) * size.height;
        double x = i * spacing + spacing / 2;
        double y = size.height - h;
        points.add(Offset(x, y));
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        _drawText(canvas, labels[i], Offset(x, size.height + 10), textStyle);
        _drawText(canvas, data[i].toInt().toString(), Offset(x, y - 20), const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey));
      }
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
      for (var p in points) {
        paint.color = Colors.white;
        canvas.drawCircle(p, 6, paint);
        paint.color = Colors.orange;
        canvas.drawCircle(p, 4, paint);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}