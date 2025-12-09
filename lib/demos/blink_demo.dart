// lib/demos/blink_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class BlinkDemoWidget extends StatefulWidget {
  const BlinkDemoWidget({Key? key}) : super(key: key);

  @override
  _BlinkDemoWidgetState createState() => _BlinkDemoWidgetState();
}

class _BlinkDemoWidgetState extends State<BlinkDemoWidget> {
  // Sequence: Top-Left (Blue) -> Bottom-Right (Red) -> TL (Match) -> BR (Match)
  final List<Map<String, dynamic>> demoSequence = [
    {"cell": 0, "color": Color(0xFF2196F3)}, // Material Blue 500
    {"cell": 8, "color": Color(0xFFF44336)}, // Material Red 500
    {"cell": 0, "color": Color(0xFF2196F3)}, // Match
    {"cell": 8, "color": Color(0xFFF44336)}, // Match
  ];

  int stepIndex = 0;
  int? currentCell;
  Color currentColor = const Color(0xFF2196F3);
  Color? feedbackOverlay;

  // Controls the "Press" animation of the button
  bool isButtonPressed = false;

  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _runSequenceStep();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  void _runSequenceStep() {
    if (!mounted) return;

    // 1. Check for Reset
    if (stepIndex >= demoSequence.length) {
      setState(() {
        currentCell = null;
        isButtonPressed = false;
      });

      // 2-second pause before looping
      _loopTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() => stepIndex = 0);
        _runSequenceStep();
      });
      return;
    }

    // 2. Execute Step
    final step = demoSequence[stepIndex];
    setState(() {
      currentCell = step['cell'];
      currentColor = step['color'];
    });

    // 3. Handle Matches (Simulate Button Press)
    // Indices 2 and 3 are the "Match" steps
    if (stepIndex >= 2) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            isButtonPressed = true; // Visually press button
            feedbackOverlay = Colors.green.withOpacity(0.2); // Green flash on screen
          });

          // Release button after short delay
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              setState(() {
                isButtonPressed = false;
                feedbackOverlay = null;
              });
            }
          });
        }
      });
    }

    // 4. Schedule Next
    int stepDuration = (stepIndex >= 2) ? 1800 : 1200;

    // Clear grid shortly before next step (Blink effect)
    Future.delayed(Duration(milliseconds: stepDuration - 200), () {
      if (mounted) setState(() => currentCell = null);
    });

    _loopTimer = Timer(Duration(milliseconds: stepDuration), () {
      if (!mounted) return;
      stepIndex++;
      _runSequenceStep();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Exact colors from analysis or standard Material approximations
    final inactiveColor = const Color(0xFFEEEEEE); // Grey 200ish
    final buttonColor = const Color(0xFF3F51B5);   // Indigo 500

    return Stack(
      children: [
        if (feedbackOverlay != null)
          Positioned.fill(child: Container(color: feedbackOverlay)),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Text Label
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Text(
                  "DEMO: Watch for matches",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                  ),
                ),
              ),

              // 2. The Grid (Matching your screenshot style)
              SizedBox(
                height: 280,
                width: 280,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: List.generate(9, (i) {
                    final isActive = i == currentCell;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(
                        color: isActive ? currentColor : inactiveColor,
                        borderRadius: BorderRadius.circular(16), // Rounded corners
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 40),

              // 3. The "MATCH!" Button
              // Always visible, simulates a "dip" when pressed
              AnimatedScale(
                scale: isButtonPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: 200, // Wide pill shape
                  height: 60,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(30), // Pill shape
                    boxShadow: [
                      if (!isButtonPressed) // Shadow disappears when pressed
                        BoxShadow(
                          color: buttonColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "MATCH!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}