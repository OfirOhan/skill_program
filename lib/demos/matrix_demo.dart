// lib/demos/matrix_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class MatrixDemoWidget extends StatefulWidget {
  const MatrixDemoWidget({Key? key}) : super(key: key);

  @override
  _MatrixDemoWidgetState createState() => _MatrixDemoWidgetState();
}

class _MatrixDemoWidgetState extends State<MatrixDemoWidget> {
  int demoStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startDemoLoop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startDemoLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (t) {
      if (!mounted) return;
      setState(() {
        demoStep = (demoStep + 1) % 3;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Puzzle Pattern:
    // Row 1 (Orange): Star -> Circle
    // Row 2 (Blue):   Star -> ? (Blue Circle)
    final List<IconData> gridIcons = [
      Icons.star_rounded,
      Icons.circle,
      Icons.star_rounded,
      Icons.question_mark_rounded,
    ];

    final List<IconData> options = [
      Icons.square_rounded,
      Icons.circle,
      Icons.change_history,
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 24.0), // Increased padding
            child: Text(
              "DEMO: Complete the pattern",
              textAlign: TextAlign.center,
              // Increased font size
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          // --- GRID CONTAINER (Enlarged 160 -> 220) ---
          Container(
            height: 220,
            width: 220,
            padding: const EdgeInsets.all(16), // Increased padding
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12, // Increased spacing
              mainAxisSpacing: 12,  // Increased spacing
              children: List.generate(4, (index) {
                bool isQuestion = index == 3;
                bool isSecondRow = index >= 2;
                Color shapeColor = isSecondRow ? Colors.blue : Colors.orange;

                if (isQuestion && demoStep == 2) {
                  return _buildGridItem(Icons.circle, Colors.blue);
                }

                return _buildGridItem(
                    gridIcons[index],
                    isQuestion ? Colors.indigo : shapeColor,
                    isQuestion: isQuestion
                );
              }),
            ),
          ),

          const SizedBox(height: 32), // Increased spacing

          // --- OPTIONS ROW (Buttons Enlarged 50 -> 70) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(options.length, (index) {
              bool isCorrectOption = (index == 1);
              bool isHighlighted = (demoStep >= 1) && isCorrectOption;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0), // Increased spacing
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 70,  // Bigger button
                  height: 70, // Bigger button
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? (demoStep == 2 ? Colors.green : Colors.indigo)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isHighlighted ? Colors.transparent : Colors.grey[300]!,
                        width: 3 // Thicker border
                    ),
                    boxShadow: isHighlighted
                        ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)]
                        : null,
                  ),
                  child: Icon(
                    options[index],
                    size: 40, // Bigger icon (was 30)
                    color: isHighlighted ? Colors.white : Colors.blue,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          AnimatedOpacity(
            opacity: demoStep == 2 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Text(
                "MATCH!",
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 18 // Larger text
                )
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGridItem(IconData icon, Color color, {bool isQuestion = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isQuestion
            ? Border.all(color: Colors.indigo.withOpacity(0.3), width: 3)
            : null,
      ),
      child: Center(
        // Icon size increased 48 -> 60
        child: Icon(icon, size: 60, color: color),
      ),
    );
  }
}