// blink_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class BlinkMatchWidget extends StatefulWidget {
  final int durationSeconds;
  final int nBack;

  const BlinkMatchWidget({
    this.durationSeconds = 30,
    this.nBack = 2,
    Key? key,
  }) : super(key: key);

  @override
  _BlinkMatchWidgetState createState() => _BlinkMatchWidgetState();
}

class _BlinkMatchWidgetState extends State<BlinkMatchWidget> {
  final rand = Random();
  final List<_Stim> seq = [];
  Timer? _timer;

  int gridSize = 9;
  int tickInterval = 1000; // 1 second per step

  int hits = 0;
  int misses = 0;
  int falseAlarms = 0;
  List<int> rts = [];
  int longestStreak = 0;
  int currentStreak = 0;

  int? currentCell;
  bool running = false;
  int lastStimTime = 0;
  Color? feedbackColor;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    running = true;
    lastStimTime = DateTime.now().millisecondsSinceEpoch;

    _timer = Timer.periodic(Duration(milliseconds: tickInterval), (t) {
      if (t.tick > widget.durationSeconds * 1000 ~/ tickInterval) {
        _stop();
        return;
      }
      _nextStim();
    });
  }

  void _nextStim() {
    // Check if the previous item was a match that the user missed
    if (seq.isNotEmpty) {
      int prevIndex = seq.length - 1;
      if (_isMatch(prevIndex) && !seq[prevIndex].userClaimed) {
        misses++;
        currentStreak = 0;
        setState(() => feedbackColor = Colors.orange.withOpacity(0.3)); // Warning flash
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => feedbackColor = null);
        });
      }
    }

    // Generate new stimulus
    int nextVal;
    // Force a match ~30% of the time
    bool forceMatch = rand.nextInt(100) < 30 && seq.length >= widget.nBack;

    if (forceMatch) {
      nextVal = seq[seq.length - widget.nBack].cell;
    } else {
      nextVal = rand.nextInt(gridSize);
    }

    seq.add(_Stim(nextVal));
    currentCell = nextVal;
    lastStimTime = DateTime.now().millisecondsSinceEpoch;
    setState(() {});

    // Turn off the square halfway through the interval (blinking effect)
    Future.delayed(Duration(milliseconds: tickInterval ~/ 2), () {
      if (mounted && running) setState(() { currentCell = null; });
    });
  }

  bool _isMatch(int index) {
    if (index - widget.nBack < 0) return false;
    return seq[index].cell == seq[index - widget.nBack].cell;
  }

  void onMatchButtonTap() {
    if (!running || seq.isEmpty) return;

    final currentIndex = seq.length - 1;
    if (seq[currentIndex].userClaimed) return;

    seq[currentIndex].userClaimed = true;

    final now = DateTime.now().millisecondsSinceEpoch;
    final rt = now - lastStimTime;

    bool correct = _isMatch(currentIndex);

    if (correct) {
      hits++;
      rts.add(rt);
      currentStreak++;
      longestStreak = max(longestStreak, currentStreak);
      setState(() => feedbackColor = Colors.green.withOpacity(0.3));
    } else {
      falseAlarms++;
      currentStreak = 0;
      setState(() => feedbackColor = Colors.red.withOpacity(0.3));
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => feedbackColor = null);
    });
  }

  void _stop() {
    running = false;
    _timer?.cancel();
    final result = grade();
    // Return the result to the main screen
    Navigator.of(context).pop(result);
  }

  Map<String, double> grade() {
    int totalTargets = 0;
    for (int i = 0; i < seq.length; i++) {
      if (_isMatch(i)) totalTargets++;
    }

    final precision = hits / max(1, hits + falseAlarms);
    final recall = hits / max(1, totalTargets);
    final f1 = (2 * precision * recall) / max(0.001, precision + recall);

    return {
      "Working Memory": f1,
      "Raw Hits": hits.toDouble(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("2-Back Challenge")),
      body: Stack(
        children: [
          if (feedbackColor != null)
            Positioned.fill(child: Container(color: feedbackColor)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Tap MATCH if the blue square\nis in the same spot as 2 steps ago.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: GridView.count(
                    crossAxisCount: 3,
                    children: List.generate(9, (i) {
                      final isActive = i == currentCell;
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.blueAccent : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: isActive ? Border.all(color: Colors.blue[900]!, width: 2) : null,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: onMatchButtonTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("MATCH!",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stim {
  final int cell;
  bool userClaimed = false;
  _Stim(this.cell);
}