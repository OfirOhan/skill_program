// lib/demos/chart_demo.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- ENUMS (Local for Demo) ---
enum DemoChartType { bar, line }

class ChartDashDemoWidget extends StatefulWidget {
  const ChartDashDemoWidget({Key? key}) : super(key: key);

  @override
  _ChartDashDemoWidgetState createState() => _ChartDashDemoWidgetState();
}

class _ChartDashDemoWidgetState extends State<ChartDashDemoWidget> {
  // Demo Data (New "Spoiler-Free" Question)
  // "Which Quarter had Highest Revenue?"
  // Data: Q1=30, Q2=50, Q3=90, Q4=40
  // Answer: Q3 (Index 2)

  int step = 0;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _startDemoLoop();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  void _startDemoLoop() {
    // RESET
    setState(() {
      step = 0;
    });

    // Step 0: READ QUESTION (0s - 1.5s)
    _loopTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // Step 1: SELECT OPTION (1.5s)
      setState(() {
        step = 1; // Highlight Correct Option (Q3)
      });

      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;

        // Step 2: SHOW FEEDBACK (2.5s)
        setState(() {
          step = 2; // Show Correct Badge
        });

        // RESTART (4.0s)
        Timer(const Duration(milliseconds: 1500), _startDemoLoop);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // New Dummy Data
    final List<double> dataPoints = [30, 50, 90, 40];
    final List<String> labels = ["Q1", "Q2", "Q3", "Q4"];
    final List<String> options = ["Q1", "Q2", "Q3", "Q4"];
    final int correctIndex = 2; // Q3 is highest (90)

    return Container(
      width: 300,
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
        mainAxisSize: MainAxisSize.min, // Wrap content height
        children: [
          // 1. HEADER
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
            child: const Text(
                "Which Quarter had Highest Revenue?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)
            ),
          ),

          const SizedBox(height: 12),

          // 2. CHART AREA
          AspectRatio(
            aspectRatio: 1.6,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: CustomPaint(
                painter: DemoChartPainter(
                    DemoChartType.bar,
                    dataPoints,
                    labels,
                    highlightIndex: (step >= 1) ? correctIndex : null
                ),
                child: Container(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. OPTIONS (Using Column+Rows instead of GridView to prevent cutoff)
          Column(
            children: [
              Row(
                children: [
                  _buildOptionButton(options[0], 0, correctIndex),
                  const SizedBox(width: 10),
                  _buildOptionButton(options[1], 1, correctIndex),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildOptionButton(options[2], 2, correctIndex),
                  const SizedBox(width: 10),
                  _buildOptionButton(options[3], 3, correctIndex),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. FEEDBACK BADGE
          AnimatedOpacity(
            opacity: step == 2 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                  "CORRECT!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOptionButton(String text, int index, int correctIndex) {
    bool isCorrect = (index == correctIndex);
    bool isSelected = (step >= 1) && isCorrect;
    bool showSuccess = (step == 2) && isCorrect;

    Color bg = Colors.indigo[50]!;
    Color fg = Colors.indigo[900]!;
    Color border = Colors.indigo[100]!;

    if (showSuccess) {
      bg = Colors.green;
      fg = Colors.white;
      border = Colors.green;
    } else if (isSelected) {
      bg = Colors.indigo;
      fg = Colors.white;
      border = Colors.indigo;
    }

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 45, // Explicit height ensures text isn't cut off
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
            text,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: fg
            )
        ),
      ),
    );
  }
}

// --- EXACT PAINTER FROM GAME ---
class DemoChartPainter extends CustomPainter {
  final DemoChartType type;
  final List<double> data;
  final List<String> labels;
  final int? highlightIndex;

  DemoChartPainter(this.type, this.data, this.labels, {this.highlightIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final textStyle = const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold);

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
    }

    double barWidth = (size.width / data.length) * 0.5;
    double spacing = (size.width / data.length);

    if (type == DemoChartType.bar) {
      for (int i = 0; i < data.length; i++) {
        double h = (data[i] / gridMax) * size.height;
        double left = i * spacing + (spacing - barWidth) / 2;
        double top = size.height - h;

        // Visual Highlight Logic for Demo
        if (highlightIndex != null && i == highlightIndex) {
          paint.color = Colors.indigo; // Darker blue for selection
        } else {
          paint.color = Colors.blueAccent;
        }

        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barWidth, h), const Radius.circular(4)), paint);

        _drawText(canvas, labels[i], Offset(left + barWidth/2, size.height + 10), textStyle);
        // Value label
        _drawText(canvas, data[i].toInt().toString(), Offset(left + barWidth/2, top - 10), const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey));
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}