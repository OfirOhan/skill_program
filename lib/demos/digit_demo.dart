// lib/demos/digit_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class DigitShuffleDemoWidget extends StatefulWidget {
  const DigitShuffleDemoWidget({Key? key}) : super(key: key);

  @override
  _DigitShuffleDemoWidgetState createState() => _DigitShuffleDemoWidgetState();
}

class _DigitShuffleDemoWidgetState extends State<DigitShuffleDemoWidget> {
  // Demo State
  // 0: Memorize (Show 7 2 5)
  // 1: Instruction (Sort Low to High)
  // 2: Typing '2'
  // 3: Typing '5'
  // 4: Typing '7'
  // 5: Press GO
  // 6: Success Feedback
  int step = 0;
  String displayNumbers = "";
  String userInput = "";
  String? pressedKey; // Which key is currently "down"
  Color? feedbackColor;

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
    // Phase 1: MEMORIZE (0s - 1.5s)
    setState(() {
      step = 0;
      displayNumbers = "7 2 5";
      userInput = "";
      feedbackColor = null;
      pressedKey = null;
    });

    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // Phase 2: INSTRUCTION (1.5s - 2.5s)
      setState(() {
        step = 1;
        displayNumbers = ""; // Hide numbers
      });

      // Phase 3: TYPE '2' (2.5s)
      _scheduleKeyTap("2", 2500, nextInput: "2");

      // Phase 4: TYPE '5' (3.0s)
      _scheduleKeyTap("5", 3000, nextInput: "2 5");

      // Phase 5: TYPE '7' (3.5s)
      _scheduleKeyTap("7", 3500, nextInput: "2 5 7");

      // Phase 6: PRESS 'GO' (4.0s)
      Timer(const Duration(milliseconds: 4000), () {
        if (!mounted) return;
        _simulateKeyPress("GO");

        // Phase 7: SUCCESS (4.2s)
        Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            step = 6;
            feedbackColor = Colors.green;
          });
        });

        // RESTART LOOP (5.5s)
        Timer(const Duration(milliseconds: 1500), _startDemoLoop);
      });
    });
  }

  void _scheduleKeyTap(String key, int delayMs, {required String nextInput}) {
    Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _simulateKeyPress(key);
      setState(() {
        userInput = nextInput;
      });
    });
  }

  void _simulateKeyPress(String key) {
    setState(() => pressedKey = key);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => pressedKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Bigger sizing as requested
    return Container(
      width: 320,
      height: 450,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Column(
            children: [
              // --- TOP SCREEN AREA ---
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[50],
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (step == 0) ...[
                        const Text("MEMORIZE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        Text(displayNumbers, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87)),
                      ] else ...[
                        Text(
                            "Sort: Low to High",
                            style: TextStyle(fontSize: 18, color: Colors.indigo[400], fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 2))
                          ),
                          alignment: Alignment.center,
                          child: Text(
                              userInput,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),

              // --- KEYPAD AREA ---
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildKeyRow(["1", "2", "3"]),
                      _buildKeyRow(["4", "5", "6"]),
                      _buildKeyRow(["7", "8", "9"]),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKeyButton("DEL", bg: Colors.red[50], text: Colors.red, isAction: true),
                            _buildKeyButton("0"),
                            _buildKeyButton("GO", bg: Colors.green[50], text: Colors.green, isAction: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- SUCCESS OVERLAY ---
          if (feedbackColor != null)
            Container(
              color: feedbackColor!.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 80),
                    SizedBox(height: 10),
                    Text("CORRECT!", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys.map((k) => _buildKeyButton(k)).toList(),
      ),
    );
  }

  Widget _buildKeyButton(String label, {Color? bg, Color? text, bool isAction = false}) {
    bool isPressed = (pressedKey == label);
    Color baseBg = bg ?? Colors.white;
    Color effectiveBg = isPressed ? Colors.grey[300]! : baseBg;

    // If it's the GO button and pressed, darken the green
    if (label == "GO" && isPressed) effectiveBg = Colors.green[200]!;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(8),
            border: isAction ? null : Border.all(color: Colors.grey[300]!),
            boxShadow: (!isPressed && !isAction)
                ? [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, 2), blurRadius: 2)]
                : null,
          ),
          child: Center(
            child: Text(
                label,
                style: TextStyle(
                    fontSize: isAction ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: text ?? Colors.black87
                )
            ),
          ),
        ),
      ),
    );
  }
}