// lib/session_manager.dart
import 'dart:convert';
import 'package:flutter/material.dart';

// --- IMPORT ALL GAMES HERE ---
import 'blink_game.dart';       // Game 1
import 'matrix_game.dart';      // Game 2
import 'digit_shuffle.dart';    // Game 3
import 'word_ladder_game.dart'; // Game 4
import 'brick_game.dart';       // Game 5
import 'split_tap_game.dart';
import 'logic_blocks_game.dart';
import 'chart_game.dart';
import 'spin_game.dart';


class SessionManager extends StatefulWidget {
  const SessionManager({Key? key}) : super(key: key);

  @override
  _SessionManagerState createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  // Master Record (RAM only)
  Map<String, dynamic> sessionData = {
    "user_id": "guest_debug_01",
    "timestamp": DateTime.now().toIso8601String(),
    "games": {}
  };

  int currentGameIndex = 0;
  bool isTesting = true;

  // --- THE PLAYLIST ---
  final List<Widget> gameSequence = [
    const BlinkMatchWidget(),   // 1. Blink & Match
    const MatrixSwipeWidget(),  // 2. Matrix Swipe
    const DigitShuffleWidget(), // 3. Digit Shuffle
    const WordLadderGame(),     // 4. Logic Sprint
    const BrickGame(),          // 5. Brick Uses
    const SplitTapGame(),
    const LogicBlocksGame(),
    const ChartDashGame(),
    const SpinGame(),
  ];

  final List<String> gameIds = [
    "blink_match",
    "matrix_reasoning",
    "digit_shuffle",
    "logic_sprint",
    "brick_uses",
    "split_tap",
    "logic_blocks",
    "chart_dash",
    "3d_spin",
  ];

  @override
  void initState() {
    super.initState();
    // Start the sequence
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchCurrentGame());
  }

  Future<void> _launchCurrentGame() async {
    // 1. Check if we finished all games
    if (currentGameIndex >= gameSequence.length) {
      _finishAssessment();
      return;
    }

    // 2. Launch current game and WAIT for result
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => gameSequence[currentGameIndex]),
      );

      // 3. Record Data
      String gameKey = gameIds[currentGameIndex];
      sessionData['games'][gameKey] = result ?? "SKIPPED";

      // 4. Move to next index
      if (mounted) {
        setState(() { currentGameIndex++; });
        // 5. Recursively call next game
        _launchCurrentGame();
      }
    } catch (e) {
      print("Error launching game: $e");
      // If a game crashes, skip it and move on
      setState(() { currentGameIndex++; });
      _launchCurrentGame();
    }
  }

  void _finishAssessment() {
    if (!mounted) return;
    setState(() {
      isTesting = false;
    });

    // DEBUG PRINT
    print("\n\n");
    print("================== ASSESSMENT COMPLETE ==================");
    print(const JsonEncoder.withIndent('  ').convert(sessionData));
    print("=========================================================");
    print("\n\n");
  }

  @override
  Widget build(BuildContext context) {
    // Loading Screen (This is what you saw stuck)
    if (isTesting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.indigo),
              SizedBox(height: 20),
              Text("Loading next module...", style: TextStyle(color: Colors.grey))
            ],
          ),
        ),
      );
    }

    // Final Results Screen
    return Scaffold(
      appBar: AppBar(title: const Text("Session Results")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.psychology_alt, color: Colors.indigo, size: 80),
            const SizedBox(height: 20),
            const Text("Assessment Complete!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Data has been generated in the debug console.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 40),

            // JSON Preview Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!)
                ),
                child: SingleChildScrollView(
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(sessionData),
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white
              ),
              child: const Text("RETURN TO MENU"),
            )
          ],
        ),
      ),
    );
  }
}