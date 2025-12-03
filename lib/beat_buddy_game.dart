// lib/beat_buddy_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class BeatBuddyGame extends StatefulWidget {
  const BeatBuddyGame({Key? key}) : super(key: key);

  @override
  _BeatBuddyGameState createState() => _BeatBuddyGameState();
}

class _BeatBuddyGameState extends State<BeatBuddyGame> with SingleTickerProviderStateMixin {
  // Game Config
  final int bpm = 80; // Beats per minute
  late double beatIntervalMs;

  // State
  late Ticker _ticker;
  double _lastBeatTime = 0;
  double _currentTime = 0; // milliseconds since start
  bool isGameOver = false;

  // Timer
  Timer? _gameTimer;
  int remainingSeconds = 20;

  // Metrics
  List<int> deviations = []; // Difference in ms from perfect beat
  int perfectHits = 0;
  int missedBeats = 0;

  // Feedback
  String feedbackText = "WAIT...";
  Color feedbackColor = Colors.grey;
  double feedbackScale = 1.0;

  @override
  void initState() {
    super.initState();
    beatIntervalMs = 60000 / bpm; // e.g., 750ms for 80 BPM

    // Ticker gives us high-precision frame updates
    _ticker = createTicker((elapsed) {
      if (isGameOver) return;
      setState(() {
        _currentTime = elapsed.inMilliseconds.toDouble();
      });
    });

    _startGame();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _ticker.start();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) _finishGame();
    });
  }

  void _finishGame() {
    _ticker.stop();
    _gameTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _onTap() {
    if (isGameOver) return;

    // 1. Calculate nearest beat
    // Current time modulo interval gives us time *into* the current beat
    // We want to know how close we are to the "Drop" (when cycle restarts)
    double phase = _currentTime % beatIntervalMs;

    // We are aiming for phase = 0 (or phase = interval)
    // Deviation is distance to 0 or Interval
    double devFromStart = phase;
    double devFromEnd = beatIntervalMs - phase;

    double actualDeviation = min(devFromStart, devFromEnd);

    // Determine if Early (-) or Late (+)
    // If phase is small (e.g. 50ms), we tapped late (after beat)
    // If phase is big (e.g. 700ms), we tapped early (before next beat)
    bool isLate = devFromStart < devFromEnd;
    int signedDeviation = isLate ? actualDeviation.toInt() : -actualDeviation.toInt();

    // 2. Grade the Tap
    // Window: +/- 150ms is valid. Anything else is a "Miss" or ignore.
    if (actualDeviation > 150) {
      // Too far off, ignore (or count as miss if we were strict)
      setState(() {
        feedbackText = "MISS";
        feedbackColor = Colors.grey;
      });
      return;
    }

    deviations.add(actualDeviation.toInt());

    String text;
    Color color;
    if (actualDeviation < 40) {
      text = "PERFECT!!";
      color = Colors.cyanAccent;
      perfectHits++;
    } else if (actualDeviation < 90) {
      text = "GOOD";
      color = Colors.green;
    } else {
      text = isLate ? "LATE" : "EARLY";
      color = Colors.orange;
    }

    setState(() {
      feedbackText = text;
      feedbackColor = color;
      feedbackScale = 1.5; // Pop effect
    });

    // Reset scale animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => feedbackScale = 1.0);
    });
  }

  // --- GRADING ---
  Map<String, double> grade() {
    // 1. Rhythm Coordination (Avg deviation)
    // Lower deviation = Higher score.
    // 0ms = 1.0. 150ms = 0.0.
    double avgDev = deviations.isEmpty ? 150.0 : deviations.reduce((a,b)=>a+b) / deviations.length;
    double rhythmScore = (1.0 - (avgDev / 150.0)).clamp(0.0, 1.0);

    // 2. Consistency (Standard Deviation would be better, but using Perfect Hit ratio here)
    // 20 seconds @ 80BPM = approx 26 beats.
    double consistency = (deviations.length / 26.0).clamp(0.0, 1.0); // Did they hit every beat?

    // 3. Motor Coordination
    // Penalize misses heavily
    double motor = (perfectHits / 26.0).clamp(0.0, 1.0);

    return {
      "Rhythm Coordination": rhythmScore,
      "Musical Perception": (rhythmScore * 0.8 + consistency * 0.2).clamp(0.0, 1.0),
      "Motor Coordination": motor,
      "Reaction Time": rhythmScore, // In rhythm games, reaction is anticipation
      "Consistency & Reliability": consistency,
      "Emotional Regulation": 0.5, // Baseline
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, color: Colors.pinkAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Session Recorded!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Perfect Hits: $perfectHits", style: const TextStyle(color: Colors.white70, fontSize: 18)),

              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(grade()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
              )
            ],
          ),
        ),
      );
    }

    // Visualizer Math
    // Progress 0.0 to 1.0 within a beat interval
    double beatProgress = (_currentTime % beatIntervalMs) / beatIntervalMs;
    // We want the ring to shrink: Large (1.0) -> Small (0.0)
    // When progress is near 0.0 or 1.0, that's the "Beat"
    double ringSize = 300 * (1.0 - beatProgress);
    if (ringSize < 50) ringSize = 50; // Minimum target size

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("12. Beat Buddy ($remainingSeconds)"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.white70)))],
      ),
      body: GestureDetector(
        onTapDown: (_) => _onTap(), // Instant tap response
        behavior: HitTestBehavior.opaque, // Catch taps anywhere
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. The Target Zone (Fixed Center)
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 4),
              ),
              child: Center(child: Container(width: 10, height: 10, color: Colors.white)),
            ),

            // 2. The Shrinking Ring (Visual Metronome)
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pinkAccent, width: 4),
              ),
            ),

            // 3. Feedback Text
            Positioned(
              top: 100,
              child: AnimatedScale(
                scale: feedbackScale,
                duration: const Duration(milliseconds: 100),
                child: Text(
                    feedbackText,
                    style: TextStyle(color: feedbackColor, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)
                ),
              ),
            ),

            // 4. Instructions
            const Positioned(
              bottom: 50,
              child: Text(
                "Tap the screen when the\nPink Ring hits the Center!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}