// lib/demos/brick_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class BrickDemoWidget extends StatefulWidget {
  const BrickDemoWidget({Key? key}) : super(key: key);

  @override
  _BrickDemoWidgetState createState() => _BrickDemoWidgetState();
}

class _BrickDemoWidgetState extends State<BrickDemoWidget> {
  // Demo State:
  // 0: Phase 1 Intro (Brainstorm)
  // 1: Type "Hold papers"
  // 2: Type "Unclog glue"
  // 3: Phase 2 Intro (Select Best)
  // 4: Select "Unclog glue"
  // 5: Success
  int step = 0;

  // UI State
  String textFieldValue = "";
  List<String> demoIdeas = [];
  int? selectedIdeaIndex;

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
      textFieldValue = "";
      demoIdeas = [];
      selectedIdeaIndex = null;
    });

    // Step 0: SHOW PROMPT (0s - 1.5s)
    _loopTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // Step 1: TYPE IDEA 1 (1.5s)
      setState(() => step = 1);
      _typeAndSubmit("Hold papers", 1500, () {

        // Step 2: TYPE IDEA 2 (3.0s)
        setState(() => step = 2);
        _typeAndSubmit("Unclog glue", 3000, () {

          // Step 3: SWITCH TO PHASE 2 (4.5s)
          Timer(const Duration(milliseconds: 1000), () {
            if (!mounted) return;
            setState(() => step = 3);

            // Step 4: SELECT IDEA (5.5s)
            Timer(const Duration(milliseconds: 1000), () {
              if (!mounted) return;
              setState(() {
                step = 4;
                selectedIdeaIndex = 0; // Select top item (newest is top)
              });

              // Step 5: SUCCESS (6.0s)
              Timer(const Duration(milliseconds: 500), () {
                if (!mounted) return;
                setState(() => step = 5);

                // RESTART (7.5s)
                Timer(const Duration(milliseconds: 1500), _startDemoLoop);
              });
            });
          });
        });
      });
    });
  }

  void _typeAndSubmit(String text, int durationMs, VoidCallback onComplete) {
    // Simple typing simulation
    int charDelay = 50;
    for (int i = 1; i <= text.length; i++) {
      Timer(Duration(milliseconds: i * charDelay), () {
        if (mounted) setState(() => textFieldValue = text.substring(0, i));
      });
    }

    // Submit after typing
    Timer(Duration(milliseconds: (text.length * charDelay) + 300), () {
      if (mounted) {
        setState(() {
          demoIdeas.insert(0, textFieldValue); // Add to top
          textFieldValue = "";
        });
        onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isPhase1 = step < 3;

    return Container(
      width: 300,
      height: 400, // Taller to fit list
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isPhase1 ? Colors.indigo : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPhase1 ? "PHASE 1: BRAINSTORM" : "PHASE 2: SELECT BEST",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),

          const SizedBox(height: 12),

          // PROMPT
          const Text(
              "Uses for a PAPERCLIP",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
          ),

          const SizedBox(height: 16),

          // INPUT FIELD (Only visible in Phase 1)
          if (isPhase1)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!)
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(textFieldValue, style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              ],
            )
          else
            const Text(
              "Tap your best idea:",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),

          const SizedBox(height: 12),

          // LIST OF IDEAS
          Expanded(
            child: ListView.builder(
              itemCount: demoIdeas.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                bool isSelected = (index == selectedIdeaIndex);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: isSelected ? Colors.green[50] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSelected ? Colors.green : Colors.grey[200]!,
                          width: isSelected ? 2 : 1
                      )
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.grey[200],
                        child: Text("${demoIdeas.length - index}", style: const TextStyle(fontSize: 10, color: Colors.black)),
                      ),
                      const SizedBox(width: 10),
                      Text(demoIdeas[index], style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.green, size: 18)
                    ],
                  ),
                );
              },
            ),
          ),

          // SUCCESS OVERLAY (Simulated)
          if (step == 5)
            Container(
              height: 40,
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Text("DONE!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }
}