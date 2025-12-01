// lib/chart_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ChartDashGame extends StatefulWidget {
  const ChartDashGame({Key? key}) : super(key: key);

  @override
  _ChartDashGameState createState() => _ChartDashGameState();
}

class _ChartDashGameState extends State<ChartDashGame> {
  // Game State
  late List<ChartQuestion> questions;
  int index = 0;
  bool isGameOver = false;

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
    setState(() => isGameOver = true);
  }

  void _onOptionSelected(int optionIndex) {
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();

    final q = questions[index];
    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    bool isCorrect = (optionIndex == q.correctIndex);
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
    double accuracy = questions.isEmpty ? 0.0 : correctCount / questions.length;
    double avgRt = reactionTimes.isEmpty ? 5000 : reactionTimes.reduce((a,b)=>a+b) / reactionTimes.length;

    // Speed: 2s is fast (1.0), 8s is slow (0.0)
    double speedScore = (1.0 - ((avgRt - 2000) / 6000)).clamp(0.0, 1.0);

    // Analytical thinking weighs accuracy heavily on complex charts
    return {
      "Data Interpretation": accuracy,
      "Statistical Skill": accuracy * 0.9,
      "Numerical Reasoning": (accuracy * 0.8 + speedScore * 0.2).clamp(0.0, 1.0),
      "Analytical Thinking": accuracy,
      "Risk Assessment": accuracy * 0.85, // Implied by volatility detection
      "Attention to Detail": (accuracy * 0.7 + speedScore * 0.3).clamp(0.0, 1.0),
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
              const Icon(Icons.bar_chart, color: Colors.blueAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Analysis Complete!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Score: $correctCount / ${questions.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
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

    final q = questions[index];

    return Scaffold(
      appBar: AppBar(
        title: Text("8. Chart Dash (${index + 1}/${questions.length})"),
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
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- QUESTION HEADER ---
                Text(q.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // --- CHART AREA ---
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 20, 20, 30),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, 2))]
                    ),
                    child: CustomPaint(
                      painter: ChartPainter(q.type, q.dataPoints, q.labels),
                      child: Container(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // --- OPTIONS ---
                Expanded(
                  flex: 3,
                  child: Column(
                    children: List.generate(q.options.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => _onOptionSelected(i),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo[50],
                                foregroundColor: Colors.indigo[900],
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.indigo[100]!)
                            ),
                            child: Text(q.options[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Feedback Overlay
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

enum ChartType { bar, line, dualBar }

class ChartQuestion {
  final ChartType type;
  final String question;
  final List<double> dataPoints; // For single series
  final List<String> labels;
  final List<String> options;
  final int correctIndex;

  // Optional secondary data for Dual Bar
  final List<double>? dataPoints2;

  ChartQuestion({
    required this.type,
    required this.question,
    required this.dataPoints,
    required this.labels,
    required this.options,
    required this.correctIndex,
    this.dataPoints2,
  });
}

// --- PAINTER ENGINE ---

class ChartPainter extends CustomPainter {
  final ChartType type;
  final List<double> data;
  final List<String> labels;
  final List<double>? data2; // For dual charts (future proofing)

  ChartPainter(this.type, this.data, this.labels, {this.data2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final textStyle = const TextStyle(color: Colors.black54, fontSize: 12);

    // Draw Axis Lines
    final axisPaint = Paint()..color = Colors.grey[400]!..strokeWidth = 2;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint); // X
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint); // Y

    double maxVal = data.reduce(max);
    if (maxVal == 0) maxVal = 1;
    double barWidth = (size.width / data.length) * 0.6;
    double spacing = (size.width / data.length);

    if (type == ChartType.bar) {
      paint.color = Colors.blueAccent;
      for (int i = 0; i < data.length; i++) {
        double h = (data[i] / maxVal) * size.height;
        double left = i * spacing + (spacing - barWidth) / 2;
        double top = size.height - h;

        // Bar
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barWidth, h), const Radius.circular(4)),
            paint
        );

        // Label
        _drawText(canvas, labels[i], Offset(left + barWidth/2, size.height + 5), textStyle);
        // Value (optional)
        _drawText(canvas, data[i].toInt().toString(), Offset(left + barWidth/2, top - 15), textStyle);
      }
    }
    else if (type == ChartType.line) {
      paint.color = Colors.orange;
      paint.strokeWidth = 4;
      paint.style = PaintingStyle.stroke;

      Path path = Path();
      for (int i = 0; i < data.length; i++) {
        double h = (data[i] / maxVal) * size.height;
        double x = i * spacing + spacing / 2;
        double y = size.height - h;

        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);

        // Draw points
        canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.orange..style = PaintingStyle.fill);

        // Label
        _drawText(canvas, labels[i], Offset(x, size.height + 5), textStyle);
      }
      canvas.drawPath(path, paint);
    }
    else if (type == ChartType.dualBar) {
      // Draw 2 bars per category
      // Logic handled by specialized data2 passing, but for MVP we use "Comparative" via logic questions
      // Let's implement a simple dual bar logic inside the single loop
      // Assuming data contains interleaved values or we just visualize one set for simplicity
      // Actually, let's stick to Bar/Line for robustness in MVP.
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- GENERATOR ---
List<ChartQuestion> _generateQuestions() {
  return [
    // Q1: Bar Chart (Find Max)
    ChartQuestion(
      type: ChartType.bar,
      question: "Which Quarter had the HIGHEST revenue?",
      dataPoints: [45, 80, 65, 90], // Q4 is highest
      labels: ["Q1", "Q2", "Q3", "Q4"],
      options: ["Q1", "Q2", "Q3", "Q4"],
      correctIndex: 3,
    ),

    // Q2: Line Chart (Trend Analysis)
    ChartQuestion(
      type: ChartType.line,
      question: "How would you describe the trend?",
      dataPoints: [20, 35, 50, 40, 65, 80], // Generally Up
      labels: ["J", "F", "M", "A", "M", "J"],
      options: ["Consistent Decline", "Stable / Flat", "Volatile Growth", "Sharp Crash"],
      correctIndex: 2, // Growth but with a dip (Volatile Growth)
    ),

    // Q3: Bar Chart (Calculation/Comparison)
    // Find the difference or lowest
    ChartQuestion(
      type: ChartType.bar,
      question: "Which department spent the LEAST?",
      dataPoints: [120, 90, 150, 60], // Dept D
      labels: ["HR", "IT", "MKT", "OPS"],
      options: ["HR", "IT", "Marketing", "Operations"],
      correctIndex: 3,
    ),
  ];
}