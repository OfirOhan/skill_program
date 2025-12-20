// lib/demos/semantic_sieve_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class WordGroupsDemoWidget extends StatefulWidget {
  const WordGroupsDemoWidget({Key? key}) : super(key: key);

  @override
  _SemanticSieveDemoWidgetState createState() => _SemanticSieveDemoWidgetState();
}

class _SemanticSieveDemoWidgetState extends State<WordGroupsDemoWidget> {
  // --- THEME COLORS (Matched to your Game) ---
  final Color colPrimary = const Color(0xFF3F51B5); // Indigo
  final Color colBackground = const Color(0xFFF0F2F5);
  final Color colSurface = Colors.white;
  final Color colCorrect = Colors.green;
  final Color colWrong = Colors.redAccent;

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
    // Cycles through 0 (Idle) -> 1 (Selected) -> 2 (Result)
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted) return;
      setState(() {
        demoStep = (demoStep + 1) % 3;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hardcoded demo scenario from your "Money" category
    final String category = "MONEY";
    final List<String> options = ["Frugal", "Thrifty", "Miserly", "Economical"];
    final String oddOne = "Miserly"; // The target

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Mini Title
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Text(
                "DEMO: Find the Intruder",
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12
                ),
              ),
            ),

            // 2. Game Card Scaled Down
            Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: colSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                        ]
                    ),
                    child: Column(
                      children: [
                        Text(
                          "CATEGORY: $category",
                          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Find the Intruder",
                          style: TextStyle(color: colPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Options Grid
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.6,
                    children: options.map((word) {
                      bool isTarget = (word == oddOne);

                      // Logic:
                      // Step 0: Neutral
                      // Step 1: Simulate Tap (if target)
                      // Step 2: Show Result (Green if target)

                      bool isSelected = (demoStep >= 1) && isTarget;
                      bool showResult = (demoStep == 2);

                      Color bg = colSurface;
                      Color txt = colPrimary;
                      Color border = Colors.indigo.shade50;

                      if (showResult && isTarget) {
                        bg = colCorrect;
                        txt = Colors.white;
                        border = colCorrect;
                      } else if (isSelected && !showResult) {
                        // Simulating the "Tap" state
                        bg = Colors.grey[200]!;
                      }

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 2),
                            boxShadow: [
                              if (!isSelected)
                                BoxShadow(color: colPrimary.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 2))
                            ]
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          word,
                          style: TextStyle(
                              color: txt,
                              fontSize: 14,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Feedback Label
            SizedBox(
              height: 20,
              child: AnimatedOpacity(
                opacity: demoStep == 2 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                    "CORRECT: 'Miserly' is negative",
                    style: TextStyle(
                      color: colCorrect,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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