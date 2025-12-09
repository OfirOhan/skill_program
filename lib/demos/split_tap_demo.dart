// lib/demos/split_tap_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class SplitTapDemoWidget extends StatefulWidget {
  const SplitTapDemoWidget({Key? key}) : super(key: key);

  @override
  _SplitTapDemoWidgetState createState() => _SplitTapDemoWidgetState();
}

class _SplitTapDemoWidgetState extends State<SplitTapDemoWidget> {
  // Demo Steps:
  // 0: Init (Left: Red, Right: 5+3)
  // 1: Solve Math (Tap 8)
  // 2: Math Switch (New Problem: 9-4)
  // 3: Light turns GREEN
  // 4: Tap Light (Success)
  int step = 0;

  // Left Side State
  Color lightColor = Colors.red;
  bool isLightPressed = false;

  // Right Side State
  String mathQuestion = "5 + 3 = ?";
  List<String> mathOptions = ["6", "8", "9"];
  int? selectedMathIndex;

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
      lightColor = Colors.red;
      isLightPressed = false;

      // Problem 1
      mathQuestion = "5 + 3 = ?";
      mathOptions = ["6", "8", "9"];
      selectedMathIndex = null;
    });

    // Step 0: WAIT (0s - 1.0s)
    _loopTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      // Step 1: SOLVE 5+3 (1.0s)
      setState(() {
        step = 1;
        selectedMathIndex = 1; // Index of '8'
      });

      // Step 2: SWITCH PROBLEM (1.5s)
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          step = 2;
          // Clear selection and show Problem 2
          selectedMathIndex = null;
          mathQuestion = "9 - 4 = ?";
          mathOptions = ["3", "5", "6"];
        });

        // Step 3: LIGHT TURNS GREEN (2.5s)
        Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          setState(() {
            step = 3;
            lightColor = Colors.green; // Target match!
          });

          // Step 4: TAP LIGHT (3.5s)
          Timer(const Duration(milliseconds: 1000), () {
            if (!mounted) return;
            setState(() {
              step = 4;
              isLightPressed = true;
            });

            // RESTART (5.0s)
            Timer(const Duration(milliseconds: 1500), _startDemoLoop);
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 240,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Row(
        children: [
          // --- LEFT SIDE: VISUAL TASK ---
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Target Instruction
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12)
                    ),
                    child: const Text("TAP GREEN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  const SizedBox(height: 20),

                  // The Light Button
                  AnimatedScale(
                    scale: isLightPressed ? 0.9 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                          color: lightColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: lightColor.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2
                            )
                          ],
                          border: Border.all(color: Colors.black12, width: 4)
                      ),
                      // Success checkmark on tap
                      child: isLightPressed
                          ? const Icon(Icons.check, color: Colors.white, size: 40)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(width: 1, color: Colors.black12),

          // --- RIGHT SIDE: MATH TASK ---
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dynamic Question
                  Text(mathQuestion, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Dynamic Options
                  ...List.generate(mathOptions.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildMathOption(index, mathOptions[index]),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMathOption(int index, String text) {
    bool isSelected = (selectedMathIndex == index);
    Color bg = Colors.white;
    Color border = Colors.grey[300]!;
    Color textColor = Colors.black87;

    if (isSelected) {
      bg = Colors.green[50]!;
      border = Colors.green;
      textColor = Colors.green[800]!;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
      ),
    );
  }
}