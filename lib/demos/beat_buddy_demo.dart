// lib/demos/beat_buddy_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class BeatBuddyDemoWidget extends StatefulWidget {
  const BeatBuddyDemoWidget({Key? key}) : super(key: key);

  @override
  _BeatBuddyDemoWidgetState createState() => _BeatBuddyDemoWidgetState();
}

class _BeatBuddyDemoWidgetState extends State<BeatBuddyDemoWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Visual State
  bool showTapIndicator = false;
  String feedbackText = "";
  Color feedbackColor = Colors.transparent;
  double feedbackOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Simulate ~60 BPM (1 second per beat)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _startDemoLoop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startDemoLoop() async {
    while (mounted) {
      // --- BEAT 1: PERFECT ---
      // Reset Feedback
      if (mounted) setState(() => feedbackOpacity = 0.0);

      // Wait for ring to be near center (approx 900ms)
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      // Tap + Feedback
      _triggerTap();
      _showFeedback("PERFECT", Colors.green);

      // Wait for next beat alignment
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;

      // --- BEAT 2: LATE ---
      if (mounted) setState(() => feedbackOpacity = 0.0);

      // Wait past center (1000ms + 250ms late)
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      _triggerTap();
      _showFeedback("LATE", Colors.orange);

      await Future.delayed(const Duration(milliseconds: 1750));
      if (!mounted) return;

      // --- BEAT 3: PERFECT AGAIN ---
      if (mounted) setState(() => feedbackOpacity = 0.0);

      _triggerTap();
      _showFeedback("PERFECT", Colors.green);

      // Hold before loop restart
      await Future.delayed(const Duration(milliseconds: 2000));
    }
  }

  // Helper: Flashes the finger icon briefly (like a real tap)
  void _triggerTap() {
    if (!mounted) return;
    setState(() => showTapIndicator = true);

    // Hide finger after 150ms (quick tap)
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => showTapIndicator = false);
    });
  }

  // Helper: Shows the text badge
  void _showFeedback(String text, Color color) {
    if (!mounted) return;
    setState(() {
      feedbackText = text;
      feedbackColor = color;
      feedbackOpacity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Header Instructions
          const Positioned(
            top: 24,
            child: Text(
                "Tap when the Ring hits Center",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)
            ),
          ),

          // 2. Animated Beat Visualizer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = _controller.value;
              double ringSize = 90 + (160 * (1.0 - progress)); // Demo Scale

              bool onBeat = progress > 0.9 || progress < 0.1;
              double centerSize = onBeat ? 100 : 90;
              Color centerColor = onBeat ? Colors.indigo : Colors.grey[300]!;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Target Zone
                  Container(
                    width: centerSize, height: centerSize,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                        border: Border.all(
                            color: centerColor,
                            width: onBeat ? 6 : 4
                        ),
                        boxShadow: [
                          if (onBeat)
                            BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                        ]
                    ),
                  ),

                  // Shrinking Ring
                  Container(
                    width: ringSize, height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.indigoAccent, width: 4),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Feedback Badge (Below)
          Transform.translate(
            offset: const Offset(0, 100),
            child: AnimatedOpacity(
              opacity: feedbackOpacity,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                    color: feedbackColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: feedbackColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
                    ]
                ),
                child: Text(
                    feedbackText,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                ),
              ),
            ),
          ),

          // 4. Simulated Finger Tap (Visual Indicator)
          // Renders ON TOP of everything else
          if (showTapIndicator)
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.1),
              ),
              child: const Icon(Icons.touch_app, color: Colors.indigo, size: 40),
            ),
        ],
      ),
    );
  }
}