// lib/games/beat_buddy_game.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BeatBuddyGame extends StatefulWidget {
  const BeatBuddyGame({Key? key}) : super(key: key);

  @override
  State<BeatBuddyGame> createState() => _BeatBuddyGameState();
}

enum _Stage { pitch, rhythmDiscrimination, done }

class _BeatBuddyGameState extends State<BeatBuddyGame> with TickerProviderStateMixin {
  // --- THEME ---
  final Color colPrimary = const Color(0xFF3F51B5);
  final Color colAccent = const Color(0xFF00E5FF);
  final Color colBackground = const Color(0xFFF0F2F5);
  final Color colSurface = Colors.white;
  final Color colText = const Color(0xFF2D3436);
  final Color colDarkDisplay = const Color(0xFF1E1E2C);

  final Random rand = Random();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Tone player
  final AudioPlayer _clickPlayer = AudioPlayer(); // Click player

  // --- GAME STATE ---
  _Stage _stage = _Stage.pitch;
  bool _isGameOver = false;

  // --- GLOBAL TIMER ---
  Timer? _roundTimer;
  int _roundSecondsLeft = 0;

  // ==========================================
  // STAGE 1: PITCH MATCHING (2 Rounds)
  // ==========================================
  int _pitchRound = 0;
  final int _maxPitchRounds = 2;

  double _targetFreq = 440.0;
  double _userFreq = 440.0;
  bool _isPlayingTarget = false;
  bool _isPlayingUser = false;

  final List<double> _pitchErrorsCents = [];

  // ==========================================
  // STAGE 2: RHYTHM DISCRIMINATION (5 Rounds)
  // ==========================================
  int _trial = 0;
  final int _maxTrials = 5;

  bool _isPlayingRhythm = false;
  bool _awaitingAnswer = false;
  bool _isTransitioning = false;

  String _currentPatternLabel = "";

  List<int> _patternA = [];
  List<int> _patternB = [];

  // Logic
  List<bool> _answerDeck = [];
  bool _currentCorrectAnswer = true;

  // Feedback State
  bool? _lastChosenSame;
  bool? _lastAnswerCorrect;

  // Score
  int _rhythmCorrect = 0;
  int _rhythmTotal = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  BytesSource? _clickSource;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _clickPlayer.setReleaseMode(ReleaseMode.stop);
    _generateClickSound();

    _startPitchRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _audioPlayer.dispose();
    _clickPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ==========================================
  // AUDIO ENGINE
  // ==========================================
  void _generateClickSound() {
    const int sampleRate = 44100;
    const int durationMs = 40;
    final int numSamples = (sampleRate * (durationMs / 1000)).round();
    final Int16List pcm = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double decay = 1.0 - (i / numSamples);
      double sample = sin(2 * pi * 800 * t) * decay;
      pcm[i] = (sample * 0.8 * 32767).round().clamp(-32767, 32767);
    }

    final BytesBuilder bytes = BytesBuilder();
    void writeStr(String s) => bytes.add(s.codeUnits);
    void writeInt32(int v) => bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void writeInt16(int v) => bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    writeStr('RIFF'); writeInt32(36 + pcm.lengthInBytes); writeStr('WAVE');
    writeStr('fmt '); writeInt32(16); writeInt16(1); writeInt16(1);
    writeInt32(sampleRate); writeInt32(sampleRate * 2); writeInt16(2); writeInt16(16);
    writeStr('data'); writeInt32(pcm.lengthInBytes);
    bytes.add(pcm.buffer.asUint8List());

    _clickSource = BytesSource(bytes.toBytes());
  }

  Future<void> _playTone(double freq, {int durationMs = 800, required bool isTarget}) async {
    await _audioPlayer.stop();
    if (!mounted) return;

    setState(() {
      if (isTarget) { _isPlayingTarget = true; _isPlayingUser = false; }
      else { _isPlayingUser = true; _isPlayingTarget = false; }
    });

    final int sampleRate = 44100;
    final int numSamples = (sampleRate * (durationMs / 1000)).round();
    final Int16List pcm = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double sample = sin(2 * pi * freq * t);
      double env = 1.0;
      if (i < 500) env = i / 500;
      if (i > numSamples - 500) env = (numSamples - i) / 500;
      pcm[i] = (sample * env * 0.6 * 32767).round().clamp(-32767, 32767);
    }

    final BytesBuilder bytes = BytesBuilder();
    void writeStr(String s) => bytes.add(s.codeUnits);
    void writeInt32(int v) => bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void writeInt16(int v) => bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    writeStr('RIFF'); writeInt32(36 + pcm.lengthInBytes); writeStr('WAVE');
    writeStr('fmt '); writeInt32(16); writeInt16(1); writeInt16(1);
    writeInt32(sampleRate); writeInt32(sampleRate * 2); writeInt16(2); writeInt16(16);
    writeStr('data'); writeInt32(pcm.lengthInBytes);
    bytes.add(pcm.buffer.asUint8List());

    await _audioPlayer.play(BytesSource(bytes.toBytes()));
    await Future.delayed(Duration(milliseconds: durationMs + 50));

    if (mounted) {
      setState(() { _isPlayingTarget = false; _isPlayingUser = false; });
    }
  }

  Future<void> _click() async {
    if (_clickSource != null) {
      await _clickPlayer.stop();
      await _clickPlayer.play(_clickSource!);
    }
    if (mounted) _pulseController.forward(from: 0.0);
  }

  // ==========================================
  // TIMER LOGIC
  // ==========================================
  void _startTimer(int seconds, VoidCallback onTimeout) {
    _roundTimer?.cancel();
    _roundSecondsLeft = seconds;

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _isGameOver) { t.cancel(); return; }
      setState(() => _roundSecondsLeft--);
      if (_roundSecondsLeft <= 0) {
        t.cancel();
        onTimeout();
      }
    });
  }

  // ==========================================
  // STAGE 1: PITCH MATCHING
  // ==========================================
  void _startPitchRound() {
    setState(() {
      _targetFreq = 300 + rand.nextDouble() * 400;
      _userFreq = 440.0;
    });
    _startTimer(20, _submitPitch);
  }

  void _submitPitch() {
    _roundTimer?.cancel();
    final double ratio = _userFreq / _targetFreq;
    final double cents = (1200 * log(ratio) / log(2)).abs();
    _pitchErrorsCents.add(cents);

    HapticFeedback.mediumImpact();

    if (_pitchRound < _maxPitchRounds - 1) {
      _pitchRound++;
      _startPitchRound();
    } else {
      _prepareRhythmStage();
    }
  }

  // ==========================================
  // STAGE 2: RHYTHM DISCRIMINATION
  // ==========================================

  void _prepareRhythmStage() {
    setState(() { _stage = _Stage.rhythmDiscrimination; });

    // Balanced deck: 2 Same, 3 Different (or vice versa)
    int sameCount = 2 + rand.nextInt(2);
    _answerDeck = List.generate(_maxTrials, (i) => i < sameCount);
    _answerDeck.shuffle();

    _startRhythmTrial();
  }

  // --- DIFFICULTY CURVE LOGIC ---
  int _getBeatsForRound(int r) {
    // Round 0-1: 4 beats (Simple)
    // Round 2-3: 5 beats (Medium)
    // Round 4: 6 beats (Complex)
    if (r < 2) return 4;
    if (r < 4) return 5;
    return 6;
  }

  int _getDeltaForRound(int r) {
    // Round 0: 300ms (Very Obvious)
    // Round 1: 200ms (Easy)
    // Round 2: 150ms (Medium)
    // Round 3: 100ms (Hard)
    // Round 4: 60ms (Expert)
    switch(r) {
      case 0: return 300;
      case 1: return 200;
      case 2: return 150;
      case 3: return 100;
      default: return 60;
    }
  }

  List<int> _makeBasePattern({required int beats}) {
    final int intervalsCount = max(3, beats - 1);
    final List<int> intervals = [];
    for (int i = 0; i < intervalsCount; i++) {
      int interval = 300 + rand.nextInt(501);
      interval = (interval / 50).round() * 50;
      intervals.add(interval);
    }
    return intervals;
  }

  List<int> _makeComparisonPattern(List<int> a, {required bool makeSame, required int deltaMs}) {
    if (makeSame) return List<int>.from(a);
    final List<int> b = List<int>.from(a);
    final int idx = rand.nextInt(b.length);
    final int sign = rand.nextBool() ? 1 : -1;

    int changed = b[idx] + sign * deltaMs;
    // Keep reasonable tempo
    changed = changed.clamp(250, 900);
    // Snap to grid
    changed = (changed / 50).round() * 50;

    // Safety check: if change failed (e.g. clamp hit), force a shift
    if (changed == b[idx]) changed = (changed + 50).clamp(250, 900);

    b[idx] = changed;
    return b;
  }

  void _startRhythmTrial() {
    _roundTimer?.cancel();

    // Reset visual feedback
    _lastChosenSame = null;
    _lastAnswerCorrect = null;

    // --- DIFFICULTY ---
    final int beats = _getBeatsForRound(_trial);
    final int delta = _getDeltaForRound(_trial);

    _currentCorrectAnswer = _answerDeck[_trial];

    _patternA = _makeBasePattern(beats: beats);
    _patternB = _makeComparisonPattern(_patternA, makeSame: _currentCorrectAnswer, deltaMs: delta);

    setState(() {
      _isPlayingRhythm = true;
      _awaitingAnswer = false;
      _isTransitioning = false;
      _currentPatternLabel = "GET READY...";
    });

    _startTimer(12, _timeoutRhythmTrial);
    _playRhythmAB();
  }

  Future<void> _playRhythmAB() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1000));

    // Play A
    setState(() => _currentPatternLabel = "PATTERN A");
    await _playIntervalPattern(_patternA);

    // Gap
    setState(() => _currentPatternLabel = "...");
    await Future.delayed(const Duration(milliseconds: 1200));

    // Play B
    setState(() => _currentPatternLabel = "PATTERN B");
    await _playIntervalPattern(_patternB);

    if (!mounted) return;
    setState(() {
      _isPlayingRhythm = false;
      _awaitingAnswer = true;
      _currentPatternLabel = "SAME or DIFFERENT?";
    });
  }

  Future<void> _playIntervalPattern(List<int> intervals) async {
    await _click();
    for (final int interval in intervals) {
      await Future.delayed(Duration(milliseconds: interval));
      if (!mounted) return;
      await _click();
    }
  }

  void _timeoutRhythmTrial() {
    _registerRhythmAnswer(isSameChosen: null);
  }

  void _registerRhythmAnswer({bool? isSameChosen}) {
    if (_stage != _Stage.rhythmDiscrimination || _isTransitioning) return;
    _roundTimer?.cancel();

    final bool hadAnswer = isSameChosen != null;
    final bool correct = hadAnswer && (isSameChosen == _currentCorrectAnswer);

    _rhythmTotal += 1;
    if (correct) _rhythmCorrect += 1;

    setState(() {
      _isTransitioning = true;
      _awaitingAnswer = false;
      _lastChosenSame = isSameChosen;
      _lastAnswerCorrect = correct;
    });

    if (hadAnswer) HapticFeedback.lightImpact(); else HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_trial < _maxTrials - 1) {
        setState(() { _trial++; });
        _startRhythmTrial();
      } else {
        _finishGame();
      }
    });
  }

  // ==========================================
  // GRADING
  // ==========================================
  void _finishGame() {
    setState(() { _isGameOver = true; _stage = _Stage.done; });
  }

  Map<String, double> grade() {
    final double avgCents = _pitchErrorsCents.isEmpty
        ? 500 : _pitchErrorsCents.reduce((a, b) => a + b) / _pitchErrorsCents.length;
    final double pitchScore = (1.0 - (avgCents / 300)).clamp(0.0, 1.0);
    final double rhythmScore = (_rhythmTotal == 0) ? 0.0 : (_rhythmCorrect / _rhythmTotal);

    return {
      "Auditory Pitch/Tone": double.parse(pitchScore.toStringAsFixed(2)),
      "Auditory Rhythm": double.parse(rhythmScore.toStringAsFixed(2)),
    };
  }

  // ==========================================
  // UI
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isGameOver) {
      final scores = grade();
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.graphic_eq, color: Colors.tealAccent, size: 80),
              const SizedBox(height: 20),
              const Text("SESSION COMPLETE", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              _ScoreRow("Pitch Accuracy", scores["Auditory Pitch/Tone"]!),
              const SizedBox(height: 10),
              _ScoreRow("Rhythm Accuracy", scores["Auditory Rhythm"]!),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, scores),
                style: ElevatedButton.styleFrom(backgroundColor: colPrimary, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16)),
                child: const Text("FINISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colBackground,
      appBar: AppBar(
        title: const Text("Beat Buddy"),
        backgroundColor: Colors.transparent,
        foregroundColor: colText,
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                "$_roundSecondsLeft s",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _roundSecondsLeft < 5 ? Colors.red : colPrimary),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: _stage == _Stage.pitch ? _buildPitchUI() : _buildRhythmDiscriminationUI(),
      ),
    );
  }

  // --- STAGE 1: PITCH UI ---
  Widget _buildPitchUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          LinearProgressIndicator(value: (_pitchRound + 1) / _maxPitchRounds, color: colPrimary, backgroundColor: Colors.black12),
          const SizedBox(height: 20),
          _Header("Pitch Match", "Match the target frequency."),
          const SizedBox(height: 30),

          // Target
          _ControlDeck(
            label: "TARGET",
            color: colDarkDisplay,
            labelColor: Colors.white54,
            child: _AudioPlayerWidget(
              label: "REFERENCE",
              isPlaying: _isPlayingTarget,
              freq: _targetFreq,
              onPlay: () => _playTone(_targetFreq, isTarget: true),
              color: colAccent,
            ),
          ),

          const SizedBox(height: 20),

          // User
          _ControlDeck(
            label: "YOUR TONE",
            color: colSurface,
            labelColor: Colors.black45,
            child: Column(
              children: [
                _AudioPlayerWidget(
                  label: "PREVIEW",
                  isPlaying: _isPlayingUser,
                  freq: _userFreq,
                  onPlay: () => _playTone(_userFreq, isTarget: false),
                  color: colPrimary,
                  isMini: true,
                ),
                const SizedBox(height: 20),
                const Divider(),
                _CustomSlider(
                  label: "Frequency",
                  value: _userFreq,
                  min: 200,
                  max: 800,
                  onChanged: (v) => setState(() => _userFreq = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _submitPitch,
              style: ElevatedButton.styleFrom(backgroundColor: colPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("SUBMIT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- STAGE 2: RHYTHM DISCRIMINATION UI ---
  Widget _buildRhythmDiscriminationUI() {
    final double progress = (_trial + 1) / _maxTrials;

    // Determine button colors based on feedback
    Color sameBtnColor = colPrimary;
    Color diffBtnColor = Colors.deepOrange;

    if (_isTransitioning) {
      if (_lastChosenSame == true) {
        sameBtnColor = (_lastAnswerCorrect == true) ? Colors.green : Colors.red;
        diffBtnColor = Colors.grey.shade300;
      } else if (_lastChosenSame == false) {
        diffBtnColor = (_lastAnswerCorrect == true) ? Colors.green : Colors.red;
        sameBtnColor = Colors.grey.shade300;
      } else {
        // Timeout
        sameBtnColor = Colors.grey;
        diffBtnColor = Colors.grey;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          LinearProgressIndicator(value: progress, color: colAccent, backgroundColor: Colors.black12),
          const SizedBox(height: 20),
          _Header("Rhythm Check", "Same or Different?"),
          const SizedBox(height: 25),

          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isPlayingRhythm
                          ? [Colors.grey.shade300, Colors.grey.shade400]
                          : [colAccent.withOpacity(0.9), const Color(0xFF00B8D4)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: (_isPlayingRhythm ? Colors.grey : colAccent).withOpacity(0.35), blurRadius: 30, spreadRadius: 5)]
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isPlayingRhythm ? Icons.hearing : Icons.compare_arrows, size: 60, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                          _currentPatternLabel,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 35),
          const SizedBox(height: 24),

          // Answer Buttons
          Row(
            children: [
              Expanded(
                  child: _AnswerButton(
                      label: "SAME",
                      // Enabled if awaiting answer OR if we are showing feedback for THIS button
                      enabled: _awaitingAnswer || (_isTransitioning && _lastChosenSame == true),
                      color: sameBtnColor,
                      onTap: () => _registerRhythmAnswer(isSameChosen: true)
                  )
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: _AnswerButton(
                      label: "DIFFERENT",
                      enabled: _awaitingAnswer || (_isTransitioning && _lastChosenSame == false),
                      color: diffBtnColor,
                      onTap: () => _registerRhythmAnswer(isSameChosen: false)
                  )
              ),
            ],
          ),

          const SizedBox(height: 18),
          Text("Trial ${_trial + 1}/$_maxTrials", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text("Level: ${_trial < 2 ? "EASY" : (_trial < 4 ? "MEDIUM" : "HARD")}", style: TextStyle(color: colPrimary, fontWeight: FontWeight.bold, fontSize: 12)),

          const SizedBox(height: 18),
          // REMOVED START BUTTON - Auto flow only
        ],
      ),
    );
  }
}

// =====================================================
// SHARED WIDGETS
// =====================================================

class _Header extends StatelessWidget {
  final String title, subtitle;
  const _Header(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey))]);
  }
}

class _ControlDeck extends StatelessWidget {
  final String label; final Widget child; final Color color; final Color labelColor;
  const _ControlDeck({required this.label, required this.child, required this.color, this.labelColor = Colors.black54});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor, letterSpacing: 1.0)), const SizedBox(height: 15), child]),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String label; final bool isPlaying; final VoidCallback onPlay; final Color color; final bool isMini; final double freq;
  const _AudioPlayerWidget({required this.label, required this.isPlaying, required this.onPlay, required this.color, this.isMini = false, required this.freq});
  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  @override
  void initState() { super.initState(); _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(); }
  @override
  void dispose() { _waveController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Row(children: [
        GestureDetector(
          onTap: widget.onPlay,
          child: Container(
            width: widget.isMini ? 40 : 50, height: widget.isMini ? 40 : 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isPlaying ? widget.color.withOpacity(0.2) : Colors.transparent, border: Border.all(color: widget.isPlaying ? widget.color : Colors.white38, width: 2)),
            child: Icon(widget.isPlaying ? Icons.stop : Icons.play_arrow, color: widget.isPlaying ? widget.color : Colors.white70, size: widget.isMini ? 24 : 30),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          SizedBox(height: 24, child: AnimatedBuilder(animation: _waveController, builder: (context, _) {
            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(15, (i) {
              final double waveSpeed = widget.freq / 200.0; final double waveOffset = i * 0.5; final double t = _waveController.value * 2 * pi * waveSpeed; final double val = sin(t + waveOffset); final double heightPct = widget.isPlaying ? (0.3 + 0.5 * (0.5 + 0.5 * val)) : 0.1;
              return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), height: 24 * heightPct, decoration: BoxDecoration(color: widget.isPlaying ? widget.color : Colors.white12, borderRadius: BorderRadius.circular(2))));
            }));
          })),
        ]))
      ]),
    );
  }
}

class _CustomSlider extends StatelessWidget {
  final String label; final double value, min, max; final Function(double) onChanged;
  const _CustomSlider({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
      SliderTheme(data: SliderThemeData(trackHeight: 6, activeTrackColor: const Color(0xFF3F51B5), inactiveTrackColor: Colors.indigo.withOpacity(0.1), thumbColor: Colors.white, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3), overlayShape: const RoundSliderOverlayShape(overlayRadius: 20)), child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
    ]);
  }
}

class _ScoreRow extends StatelessWidget {
  final String label; final double value;
  const _ScoreRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white70)), Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 18))]),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label; final bool enabled; final Color color; final VoidCallback onTap;
  const _AnswerButton({required this.label, required this.enabled, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(backgroundColor: enabled ? color : Colors.grey.shade300, foregroundColor: Colors.white, disabledForegroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: enabled ? 2 : 0),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ),
    );
  }
}