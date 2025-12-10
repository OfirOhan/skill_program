// lib/demos/roleplay_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class RoleplayDemoWidget extends StatefulWidget {
  const RoleplayDemoWidget({Key? key}) : super(key: key);

  @override
  _RoleplayDemoWidgetState createState() => _RoleplayDemoWidgetState();
}

class _RoleplayDemoWidgetState extends State<RoleplayDemoWidget> {
  // Demo State
  // 0: Idle (Read Quote)
  // 1: Select Option (Highlight Correct Answer)
  // 2: Show Feedback (Success)
  int step = 0;
  Timer? _loopTimer;

  // NEW SCENARIO: The Job Interview
  final String quote = "We'll keep your resume on file.";
  final String contextText = "Said while checking their watch, ending the interview 15 minutes early.";
  final List<String> options = ["Strong Candidate", "Polite Rejection"];
  final int correctIndex = 1; // Rejection

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
    setState(() => step = 0);

    // Step 0: READ (0s - 2.0s)
    _loopTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;

      // Step 1: SELECT CORRECT OPTION (2.0s)
      setState(() => step = 1);

      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;

        // Step 2: SHOW FEEDBACK (3.0s)
        setState(() => step = 2);

        // RESTART (4.5s)
        Timer(const Duration(milliseconds: 1500), _startDemoLoop);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
          // 1. Header Instruction
          const Text(
              "What is the TRUE intent?",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)
          ),
          const SizedBox(height: 16),

          // 2. The Quote Box
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]
            ),
            child: Column(
              children: [
                const Icon(Icons.format_quote, color: Colors.grey, size: 32),
                const SizedBox(height: 8),
                Text(
                  quote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. The Context (Crucial!)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.withOpacity(0.3))
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                  children: [
                    const TextSpan(text: "CONTEXT: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    TextSpan(text: contextText),
                  ]
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. Options
          Column(
            children: List.generate(options.length, (i) {
              bool isCorrect = (i == correctIndex);
              bool isSelected = (step >= 1) && isCorrect;
              bool showSuccess = (step == 2) && isCorrect;

              Color bg = Colors.white;
              Color border = Colors.grey[300]!;
              Color text = Colors.black87;

              if (showSuccess) {
                bg = Colors.green;
                border = Colors.green;
                text = Colors.white;
              } else if (isSelected) {
                bg = Colors.indigo;
                border = Colors.indigo;
                text = Colors.white;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 45,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                    boxShadow: isSelected
                        ? [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))]
                        : null
                ),
                alignment: Alignment.center,
                child: Text(
                  options[i],
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: text
                  ),
                ),
              );
            }),
          ),

          // 5. Success Badge
          SizedBox(
            height: 24,
            child: AnimatedOpacity(
              opacity: step == 2 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Text(
                  "SPOT ON!",
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)
              ),
            ),
          )
        ],
      ),
    );
  }
}