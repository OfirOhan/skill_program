// lib/demos/word_ladder_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class WordLadderDemoWidget extends StatefulWidget {
  const WordLadderDemoWidget({Key? key}) : super(key: key);

  @override
  _WordLadderDemoWidgetState createState() => _WordLadderDemoWidgetState();
}

class _WordLadderDemoWidgetState extends State<WordLadderDemoWidget> {
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
    // Data
    final String questionTop = "🍎 : 🧃";
    final String questionBottom = "🍇 : ❓";
    final List<String> options = ["🍕", "🍷", "🌵", "🚙"];
    final int correctIndex = 1;

    return Center(
      // Wrap in SingleChildScrollView to prevent crash on very small screens,
      // though our goal is to fit without scrolling.
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Wrap content tightly
          children: [
            // 1. Title (Reduced Padding)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Text(
                "DEMO: Solve the analogy",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14
                ),
              ),
            ),

            // 2. Question Box (Compacted)
            Container(
              width: 260, // Match standard width
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: Column(
                children: [
                  Text(questionTop, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_downward, color: Colors.grey, size: 20),
                  const SizedBox(height: 8),
                  Text(questionBottom, style: const TextStyle(fontSize: 28)),
                ],
              ),
            ),

            const SizedBox(height: 16), // Reduced Spacing

            // 3. Options Grid (Adjusted Height & Ratio)
            SizedBox(
              width: 260,
              height: 150, // Fixed height that definitely fits
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.8, // Wider/Shorter buttons to save vertical space
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: List.generate(options.length, (i) {
                  bool isCorrect = (i == correctIndex);
                  bool isSelected = (demoStep >= 1) && isCorrect;
                  bool showSuccess = (demoStep == 2) && isCorrect;

                  Color bg = Colors.white;
                  if (showSuccess) bg = Colors.green;
                  else if (isSelected) bg = Colors.indigo;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.grey[300]!,
                          width: 2
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        options[i],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 12),

            // 4. Feedback Label
            SizedBox( // Fixed container to prevent jumpiness
              height: 24,
              child: AnimatedOpacity(
                opacity: demoStep == 2 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Text(
                    "CORRECT!",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2
                    )
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}