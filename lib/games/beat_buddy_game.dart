// lib/beat_buddy_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:audioplayers/audioplayers.dart'; // Requires audioplayers package

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

  // Audio Players
  final AudioPlayer _perfectPlayer = AudioPlayer();
  final AudioPlayer _badPlayer = AudioPlayer();

  double _levelStartTimeMs = 0;

  int missHits = 0;
  int badHits = 0;      // (110–250ms window)
  int totalTaps = 0;


  @override
  void initState() {
    super.initState();
    _initAudio();
    _startLevel(0);

    _ticker = createTicker((elapsed) {
      if (isGameOver) return;
      setState(() {
        _currentTime = elapsed.inMilliseconds.toDouble();
      });
    });
    _ticker.start();
  }

  Future<void> _initAudio() async {
    await _perfectPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _badPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _levelTimer?.cancel();
    _perfectPlayer.dispose();
    _badPlayer.dispose();
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

      if (level == 0) bpm = 60;
      else if (level == 1) bpm = 90;
      else bpm = 120;

      beatIntervalMs = 60000 / bpm;
      _levelStartTimeMs = _currentTime; // re-zero beat phase for this level
      feedbackText = "";
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
    Navigator.of(context).pop(grade());
  }

  // --- SKIP LOGIC ---
  void _onSkipPressed() {
    _ticker.stop();
    _levelTimer?.cancel();
    HapticFeedback.lightImpact(); // Feedback for skip
    Navigator.of(context).pop(null); // Returns null correctly
  }

  void _onTap() async {
    if (isGameOver) return;

    totalTaps++;

    double phase = (_currentTime - _levelStartTimeMs) % beatIntervalMs;
    double devFromStart = phase;
    double devFromEnd = beatIntervalMs - phase;
    double actualDeviation = min(devFromStart, devFromEnd);

    // Miss (outside window)
    if (actualDeviation > 250) {
      missHits++;
      deviations.add(250); // penalize precision too
      HapticFeedback.heavyImpact();
      _triggerFeedback("MISS", Colors.grey);
      await _badPlayer.stop();
      await _badPlayer.play(AssetSource('sounds/bad.mp3'));
      return;
    }

    deviations.add(actualDeviation.toInt());
    bool isLate = devFromStart < devFromEnd; // closer to beat-start => slightly after beat => "late"

    if (actualDeviation < 45) {
      perfectHits++;
      _triggerFeedback("PERFECT", Colors.green);
      await _perfectPlayer.stop();
      await _perfectPlayer.play(AssetSource('sounds/perfect.mp3'));
      HapticFeedback.heavyImpact();
    } else if (actualDeviation < 110) {
      goodHits++;
      _triggerFeedback(isLate ? "LATE" : "EARLY", Colors.orange);
      await _badPlayer.stop();
      await _badPlayer.play(AssetSource('sounds/bad.mp3'));
      HapticFeedback.mediumImpact();
    } else {
      badHits++;
      _triggerFeedback("BAD", Colors.red);
      await _badPlayer.stop();
      await _badPlayer.play(AssetSource('sounds/bad.mp3'));
      HapticFeedback.vibrate();
    }
  }


  void _triggerFeedback(String text, Color color) {
    setState(() {
      feedbackText = text;
      feedbackColor = color;
      showFeedback = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => showFeedback = false);
    });
  }

  Map<String, double> grade() {
    final int attempts = max(1, totalTaps);

    // Hit quality (don’t let spam tapping score well)
    final double hitRate = ((perfectHits + goodHits + badHits) / attempts).clamp(0.0, 1.0);

    // Timing precision (includes misses because we push 250ms into deviations on miss)
    final double avgDev = deviations.isEmpty
        ? 250.0
        : deviations.reduce((a, b) => a + b) / deviations.length;

    // 0ms perfect, 250ms worst (window edge)
    final double precision = (1.0 - (avgDev / 250.0)).clamp(0.0, 1.0);

    // Consistency (std dev) — conservative
    double stdDev = 250.0;
    if (deviations.length >= 2) {
      final double mean = avgDev;
      double varSum = 0.0;
      for (final d in deviations) {
        final diff = d - mean;
        varSum += diff * diff;
      }
      stdDev = sqrt(varSum / deviations.length);
    }
    final double consistency = (1.0 - (stdDev / 140.0)).clamp(0.0, 1.0);

    // --- Canonical skills ---
    // Auditory Rhythm: timing precision + consistency, gated by not missing constantly
    final double auditoryRhythm = (0.55 * precision + 0.25 * consistency + 0.20 * hitRate).clamp(0.0, 1.0);

    // Visuomotor Integration: converting the beat cue into a timed motor action
    final double visuomotor = (0.65 * hitRate + 0.35 * precision).clamp(0.0, 1.0);

    // Information Processing Speed: only “earned” if timing is accurate (anti-guess)
    final double infoSpeed = (precision * hitRate).clamp(0.0, 1.0);

    return {
      "Auditory Rhythm": auditoryRhythm,
      "Visuomotor Integration": visuomotor,
      "Information Processing Speed": infoSpeed,
    };
  }


  @override
  Widget build(BuildContext context) {
    double progress = (_currentTime % beatIntervalMs) / beatIntervalMs;
    double ringSize = 90 + (250 * (1.0 - progress));
    bool onBeat = progress > 0.9 || progress < 0.1;
    double centerSize = onBeat ? 100 : 90;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // LAYER 1: GAME AREA
          GestureDetector(
            onTapDown: (_) => _onTap(),
            behavior: HitTestBehavior.opaque, // Captures taps everywhere...
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Target Zone
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: centerSize, height: centerSize,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                        border: Border.all(
                            color: onBeat ? Colors.indigo : Colors.grey[300]!,
                            width: onBeat ? 6 : 4
                        ),
                        boxShadow: [
                          if (onBeat)
                            BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                        ]
                    ),
                  ),

                  // Shrinking Ring
                  IgnorePointer(
                    child: Container(
                      width: ringSize,
                      height: ringSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.indigoAccent,
                            width: 4
                        ),
                      ),
                    ),
                  ),

                  // Feedback (Below center)
                  Transform.translate(
                    offset: const Offset(0, 120),
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: showFeedback ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 50),
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
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2
                              )
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Static Instruction
                  Positioned(
                    bottom: 60,
                    child: Text(
                      "Tap to the beat",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LAYER 2: HEADER (This is the fix)
          // We wrap the header in a GestureDetector that swallows touches.
          Positioned(
            top: 0, left: 0, right: 0,
            child: GestureDetector(
              onTap: () {
                // DO NOTHING. This prevents taps here from reaching the Game Area.
              },
              behavior: HitTestBehavior.opaque, // Blocks touches
              child: Container(
                color: Colors.transparent, // Ensures it has hit test size
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("12. Beat Buddy ($remainingSeconds)",
                            style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)
                        ),

                        // SKIP BUTTON
                        TextButton(
                            onPressed: _onSkipPressed,
                            style: TextButton.styleFrom(
                              // Giving it a touch area boost
                              padding: const EdgeInsets.all(12),
                            ),
                            child: const Text("SKIP", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}