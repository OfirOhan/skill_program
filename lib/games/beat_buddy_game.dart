// lib/beat_buddy_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // Added for Sound

class BeatBuddyGame extends StatefulWidget {
  const BeatBuddyGame({Key? key}) : super(key: key);

  @override
  _BeatBuddyGameState createState() => _BeatBuddyGameState();
}

class _BeatBuddyGameState extends State<BeatBuddyGame> with SingleTickerProviderStateMixin {
  // Game Config
  int level = 0;
  late double bpm;
  late double beatIntervalMs;

  // State
  late Ticker _ticker;
  double _currentTime = 0;
  bool isGameOver = false;

  // Timer
  Timer? _levelTimer;
  int remainingSeconds = 15;

  // Metrics
  List<int> deviations = [];
  int perfectHits = 0;
  int goodHits = 0;
  int totalBeatsEncountered = 0;

  // Feedback UI
  String feedbackText = "";
  Color feedbackColor = Colors.transparent;
  bool showFeedback = false;

  @override
  void initState() {
    super.initState();
    _startLevel(0);

    _ticker = createTicker((elapsed) {
      if (isGameOver) return;
      setState(() {
        _currentTime = elapsed.inMilliseconds.toDouble();
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _levelTimer?.cancel();
    super.dispose();
  }

  void _startLevel(int lvl) {
    if (lvl >= 3) {
      _finishGame();
      return;
    }

    setState(() {
      level = lvl;
      remainingSeconds = 15;

      // L1: 60 BPM, L2: 90 BPM, L3: 120 BPM
      if (level == 0) bpm = 60;
      else if (level == 1) bpm = 90;
      else bpm = 120;

      beatIntervalMs = 60000 / bpm;
      feedbackText = ""; // Clear text at start
      showFeedback = false;
    });

    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _nextLevel();
      }
    });
  }

  void _nextLevel() {
    totalBeatsEncountered += (15000 / beatIntervalMs).floor();
    _startLevel(level + 1);
  }

  void _finishGame() {
    _ticker.stop();
    _levelTimer?.cancel();
    // Auto-pop with grade (Fix logic: return scores when finished)
    Navigator.of(context).pop(grade());
  }

  // --- SKIP LOGIC ---
  void _onSkipPressed() {
    _ticker.stop();
    _levelTimer?.cancel();
    Navigator.of(context).pop(grade());
  }

  void _onTap() {
    if (isGameOver) return;

    // --- NEW: Play System Sound on Tap ---
    SystemSound.play(SystemSoundType.click);

    double phase = _currentTime % beatIntervalMs;
    double devFromStart = phase;
    double devFromEnd = beatIntervalMs - phase;
    double actualDeviation = min(devFromStart, devFromEnd);

    // Ignore accidental double taps (very short deviation) if we just hit one
    // But allow fast misses.
    // Limit: if > 250ms off, it's a complete miss or random tap
    if (actualDeviation > 250) {
      _triggerFeedback("MISS", Colors.grey);
      return;
    }

    deviations.add(actualDeviation.toInt());
    bool isLate = devFromStart < devFromEnd;

    if (actualDeviation < 45) {
      perfectHits++;
      _triggerFeedback("PERFECT", Colors.cyanAccent);
    } else if (actualDeviation < 110) {
      goodHits++;
      _triggerFeedback(isLate ? "LATE" : "EARLY", Colors.amber);
    } else {
      _triggerFeedback("BAD", Colors.red);
    }
  }

  void _triggerFeedback(String text, Color color) {
    setState(() {
      feedbackText = text;
      feedbackColor = color;
      showFeedback = true;
    });

    // Hide text after 300ms to keep UI clean
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => showFeedback = false);
    });
  }

  Map<String, double> grade() {
    double avgDev = deviations.isEmpty ? 200.0 : deviations.reduce((a,b)=>a+b) / deviations.length;
    double rhythmScore = (1.0 - (avgDev / 150.0)).clamp(0.0, 1.0);

    if (totalBeatsEncountered == 0) totalBeatsEncountered = 1;
    double hitRatio = (perfectHits + goodHits) / totalBeatsEncountered.toDouble();

    return {
      "Rhythm Coordination": rhythmScore,
      "Musical Perception": (rhythmScore * 0.7 + hitRatio * 0.3).clamp(0.0, 1.0),
      "Motor Coordination": hitRatio.clamp(0.0, 1.0),
      "Reaction Time": rhythmScore,
      "Consistency & Reliability": hitRatio,
      "Emotional Regulation": 0.5,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Visualizer Math
    double progress = (_currentTime % beatIntervalMs) / beatIntervalMs;
    // Ring shrinks from 300 down to 90 (Target is 90)
    double ringSize = 90 + (250 * (1.0 - progress));

    // Beat Pulse: Center target expands slightly on the beat
    bool onBeat = progress > 0.9 || progress < 0.1;
    double centerSize = onBeat ? 100 : 90;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          // GAME AREA (Full Screen Tap) - Placed FIRST (bottom layer)
          GestureDetector(
            onTapDown: (_) => _onTap(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent, // Ensures hit test works
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. TARGET ZONE (Fixed Center)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: centerSize, height: centerSize,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4), // Crisp White Border
                        color: Colors.white10, // Subtle fill
                        boxShadow: [
                          if (onBeat) BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)
                        ]
                    ),
                  ),

                  // 2. FEEDBACK TEXT (Dead Center, No Movement)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: showFeedback ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 50), // Fast fade in
                      child: Text(
                          feedbackText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: feedbackColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              shadows: const [Shadow(color: Colors.black, blurRadius: 5)]
                          )
                      ),
                    ),
                  ),

                  // 3. THE SHRINKING RING (Visual Metronome)
                  IgnorePointer(
                    child: Container(
                      width: ringSize,
                      height: ringSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.8), // Cyan Ring
                            width: 4
                        ),
                      ),
                    ),
                  ),

                  // 4. Static Instruction (Pinned to bottom)
                  const Positioned(
                    bottom: 80,
                    child: Text(
                      "Tap exactly when the\nRing hits the Center",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // APP BAR OVERLAY (Top layer)
          // We build a custom "AppBar" so it sits ON TOP of the gesture detector
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("12. Beat Buddy ($remainingSeconds)", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  // SKIP BUTTON (Using original TextButton style)
                  TextButton(
                      onPressed: _onSkipPressed,
                      child: const Text("SKIP", style: TextStyle(color: Colors.white54))
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}