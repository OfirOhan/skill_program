// lib/demos/stress_sprint_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class StressSprintDemoWidget extends StatefulWidget {
  const StressSprintDemoWidget({Key? key}) : super(key: key);

  @override
  _StressSprintDemoWidgetState createState() => _StressSprintDemoWidgetState();
}

class _StressSprintDemoWidgetState extends State<StressSprintDemoWidget> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  // Demo Sequence:
  // 0: Q1 Start
  // 1: Q1 Select
  // 2: Q1 Success (Pot Up)
  // 3: Q2 Start (Timer Reset)
  // 4: Q2 Select
  // 5: Q2 Success (Pot Up)
  // 6: Q3 Start (Timer Reset) -> DECIDE TO CASH OUT
  // 7: Secured Screen
  int step = 0;
  int currentPot = 0;

  // Display Data
  String displayQuestion = "5 + 3";
  List<String> displayOptions = ["6", "8", "9"];
  int? highlightedIndex;
  bool isCashOutPressed = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _startDemoLoop();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _startDemoLoop() async {
    while (mounted) {
      // --- RESET TO Q1 ---
      setState(() {
        step = 0;
        currentPot = 0;
        displayQuestion = "5 + 3";
        displayOptions = ["6", "8", "9"];
        highlightedIndex = null;
        isCashOutPressed = false;
      });
      _timerController.duration = const Duration(seconds: 3);
      _timerController.forward(from: 0.0);

      // Wait for Q1 Read
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // --- Q1 ANSWER (8) ---
      setState(() {
        step = 1;
        highlightedIndex = 1;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // --- Q2 SETUP ---
      setState(() {
        step = 2; // Visually update pot
        currentPot = 50;

        displayQuestion = "15 - 3";
        displayOptions = ["10", "12", "15"];
        highlightedIndex = null;
      });

      // RESET TIMER for Q2 (Faster: 2.5s)
      _timerController.duration = const Duration(milliseconds: 2500);
      _timerController.forward(from: 0.0);

      // Wait for Q2 Read
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // --- Q2 ANSWER (12) ---
      setState(() {
        step = 4;
        highlightedIndex = 1;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // --- Q3 SETUP ---
      setState(() {
        step = 5; // Update Pot
        currentPot = 150;

        displayQuestion = "6 × 4";
        displayOptions = ["20", "24", "28"];
        highlightedIndex = null;
      });

      // RESET TIMER for Q3 (Very Fast: 1.5s)
      _timerController.duration = const Duration(milliseconds: 1500);
      _timerController.forward(from: 0.0);

      // Wait briefly to show the new question and scary timer
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // --- ACTION: CASH OUT (Skip Answering) ---
      setState(() {
        step = 6;
        isCashOutPressed = true;
      });
      _timerController.stop(); // Freeze timer

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // --- SECURED SCREEN ---
      setState(() {
        step = 7;
        isCashOutPressed = false;
      });

      // Hold Final State
      await Future.delayed(const Duration(milliseconds: 2000));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (step == 7) {
      return _buildSecuredScreen();
    }

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("POT AT RISK", style: TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.bold)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                        "$currentPot",
                        key: ValueKey(currentPot),
                        style: const TextStyle(color: Colors.indigo, fontSize: 24, fontWeight: FontWeight.w900)
                    ),
                  ),
                ],
              ),
              AnimatedScale(
                scale: isCashOutPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isCashOutPressed ? [] : [
                        BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                  ),
                  child: const Text("CASH OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              )
            ],
          ),

          const SizedBox(height: 16),

          // 2. Timer Bar
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, child) {
              Color barColor = Color.lerp(Colors.blue, Colors.red, _timerController.value)!;
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 1.0 - _timerController.value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 8,
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // 3. Question
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Text(
                displayQuestion,
                key: ValueKey(displayQuestion),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87)
            ),
          ),

          const SizedBox(height: 24),

          // 4. Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(displayOptions.length, (i) {
              bool isSelected = (i == highlightedIndex);
              return _buildOption(displayOptions[i], isSelected);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuredScreen() {
    return Container(
      width: 300,
      height: 280, // Matching approx height of main screen
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text("SECURED!", style: TextStyle(color: Colors.green, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text("Banked: $currentPot", style: TextStyle(color: Colors.green[800], fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String text, bool isSelected) {
    Color bg = isSelected ? Colors.indigo : Colors.white;
    Color border = isSelected ? Colors.indigo : Colors.grey[300]!;
    Color textColor = isSelected ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 70, height: 60,
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: isSelected
              ? [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
              : null
      ),
      alignment: Alignment.center,
      child: Text(
          text,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor
          )
      ),
    );
  }
}