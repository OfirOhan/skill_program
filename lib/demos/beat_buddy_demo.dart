// lib/demos/beat_buddy_demo.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class BeatBuddyDemoWidget extends StatefulWidget {
  const BeatBuddyDemoWidget({Key? key}) : super(key: key);

  @override
  _BeatBuddyDemoWidgetState createState() => _BeatBuddyDemoWidgetState();
}

class _BeatBuddyDemoWidgetState extends State<BeatBuddyDemoWidget> with TickerProviderStateMixin {
  // --- THEME ---
  final Color colPrimary = const Color(0xFF3F51B5);
  final Color colAccent = const Color(0xFF00E5FF);
  final Color colDarkDisplay = const Color(0xFF1E1E2C);

  // --- STATE ---
  int _demoPhase = 0; // 0 = Pitch, 1 = Rhythm

  // Pitch State
  bool _targetPlaying = false;
  bool _userPlaying = false;
  double _sliderValue = 0.3; // 0.0 to 1.0

  // Rhythm State
  String _rhythmLabel = "LISTEN...";
  bool _isPulsing = false;
  bool _highlightDifferent = false; // To simulate selection

  // Visual Feedback
  String _feedbackText = "";
  Color _feedbackColor = Colors.transparent;
  double _feedbackOpacity = 0.0;

  // Tap Simulation
  Offset _tapPosition = Offset.zero;
  bool _showTap = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _startDemoLoop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startDemoLoop() async {
    while (mounted) {
      // ==========================
      // PHASE 1: PITCH MATCHING
      // ==========================
      if (mounted) setState(() {
        _demoPhase = 0;
        _sliderValue = 0.2; // Start wrong
        _feedbackOpacity = 0.0;
        _targetPlaying = false;
        _userPlaying = false;
      });

      // 1. Play Target
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _targetPlaying = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _targetPlaying = false);

      // 2. Play User & Move Slider
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _userPlaying = true);

      // Animate Slider to "Correct" spot (approx 0.7)
      const int steps = 20;
      for(int i=0; i<steps; i++) {
        await Future.delayed(const Duration(milliseconds: 40));
        if (mounted) setState(() => _sliderValue += (0.5 / steps)); // Move from 0.2 to 0.7
      }

      if (mounted) setState(() => _userPlaying = false);

      // 3. Submit
      await Future.delayed(const Duration(milliseconds: 500));
      _simulateTap(const Offset(0, 150)); // Visual tap on button
      _showFeedback("PITCH MATCHED!", Colors.green);

      await Future.delayed(const Duration(milliseconds: 2000));

      // ==========================
      // PHASE 2: RHYTHM CHECK
      // ==========================
      if (mounted) setState(() {
        _demoPhase = 1;
        _feedbackOpacity = 0.0;
        _rhythmLabel = "GET READY...";
        _highlightDifferent = false;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      // 1. Play Pattern A
      if (mounted) setState(() => _rhythmLabel = "PATTERN A");
      await _visualPulse(3); // Pulse 3 times

      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Play Pattern B
      if (mounted) setState(() => _rhythmLabel = "PATTERN B");
      await _visualPulse(3); // Pulse 3 times

      // 3. Select Answer
      if (mounted) setState(() => _rhythmLabel = "SAME or DIFFERENT?");
      await Future.delayed(const Duration(milliseconds: 600));

      _simulateTap(const Offset(60, 120)); // Tap "Different"
      if (mounted) setState(() => _highlightDifferent = true);
      _showFeedback("CORRECT!", Colors.green);

      await Future.delayed(const Duration(milliseconds: 2500));
    }
  }

  Future<void> _visualPulse(int count) async {
    for (int i=0; i<count; i++) {
      if (!mounted) return;
      _pulseController.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  void _simulateTap(Offset relativeOffset) {
    if (!mounted) return;
    setState(() {
      _tapPosition = relativeOffset;
      _showTap = true;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showTap = false);
    });
  }

  void _showFeedback(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
      _feedbackOpacity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // CONTENT SWITCHER
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _demoPhase == 0 ? _buildPitchDemo() : _buildRhythmDemo(),
          ),

          // FEEDBACK OVERLAY
          Positioned(
            top: 40,
            child: AnimatedOpacity(
              opacity: _feedbackOpacity,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: _feedbackColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]
                ),
                child: Text(
                  _feedbackText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),

          // TAP INDICATOR (Simulated Finger)
          if (_showTap)
            Transform.translate(
              offset: _tapPosition,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.1),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)
                ),
                child: const Icon(Icons.touch_app, color: Colors.indigo, size: 30),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPitchDemo() {
    return Column(
      key: const ValueKey("PITCH"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("PART 1: PITCH", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // Target Box
        Container(
          width: 240, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colDarkDisplay, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _miniPlayBtn(colAccent, _targetPlaying),
              const SizedBox(width: 10),
              const Text("TARGET", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              if (_targetPlaying) ...[
                const SizedBox(width: 10),
                const Icon(Icons.graphic_eq, color: Colors.white, size: 16)
              ]
            ],
          ),
        ),

        const SizedBox(height: 10),

        // User Box
        Container(
          width: 240, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Row(
                children: [
                  _miniPlayBtn(colPrimary, _userPlaying),
                  const SizedBox(width: 10),
                  const Text("YOUR TONE", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              // Fake Slider
              SizedBox(
                height: 20,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(height: 4, color: Colors.indigo.shade100),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 50),
                      alignment: Alignment(_sliderValue * 2 - 1, 0), // Map 0..1 to -1..1
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Submit Button
        Container(
          width: 240, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colPrimary, borderRadius: BorderRadius.circular(8)),
          child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildRhythmDemo() {
    return Column(
      key: const ValueKey("RHYTHM"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("PART 2: RHYTHM", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Pulsing Orb
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [colAccent.withOpacity(0.8), Colors.cyan.shade200]),
                boxShadow: [BoxShadow(color: colAccent.withOpacity(0.4), blurRadius: 20)]
            ),
            alignment: Alignment.center,
            child: Text(_rhythmLabel, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 40),

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _miniBtn("SAME", Colors.grey.shade300),
            const SizedBox(width: 10),
            _miniBtn("DIFFERENT", _highlightDifferent ? Colors.deepOrange : Colors.deepOrange.withOpacity(0.3)),
          ],
        )
      ],
    );
  }

  Widget _miniPlayBtn(Color color, bool active) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? color : Colors.grey, width: 2)),
      child: Icon(active ? Icons.volume_up : Icons.play_arrow, size: 16, color: active ? color : Colors.grey),
    );
  }

  Widget _miniBtn(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}