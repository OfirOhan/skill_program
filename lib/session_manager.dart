// lib/session_manager.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'blink_game.dart';
import 'matrix_game.dart';
import 'digit_shuffle.dart';

class SessionManager extends StatefulWidget {
  const SessionManager({Key? key}) : super(key: key);

  @override
  _SessionManagerState createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  // This Map lives in RAM.
  Map<String, dynamic> sessionData = {
    "user_id": "guest_debug_01",
    "timestamp": DateTime.now().toIso8601String(),
    "games": {}
  };

  int currentGameIndex = 0;
  bool isTesting = true;

  // The Playlist
  final List<Widget> gameSequence = [
    const BlinkMatchWidget(),
    const MatrixSwipeWidget(),
    const DigitShuffleWidget(),
  ];

  final List<String> gameIds = [
    "blink_match",
    "matrix_reasoning",
    "digit_shuffle",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchCurrentGame());
  }

  Future<void> _launchCurrentGame() async {
    if (currentGameIndex >= gameSequence.length) {
      _finishAssessment();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameSequence[currentGameIndex]),
    );

    String gameKey = gameIds[currentGameIndex];
    sessionData['games'][gameKey] = result ?? "SKIPPED";

    setState(() { currentGameIndex++; });
    _launchCurrentGame();
  }

  void _finishAssessment() {
    // 1. Stop the loading spinner
    setState(() {
      isTesting = false;
    });

    // 2. DEBUG PRINT: This sends the data to your Computer's Console
    print("\n\n");
    print("================== DEBUG OUTPUT START ==================");
    print("Use this JSON to verify your grading logic:");
    print("");

    // Pretty print the JSON so it's readable in the console
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    String prettyJson = encoder.convert(sessionData);
    print(prettyJson);

    print("================== DEBUG OUTPUT END ==================");
    print("\n\n");
  }

  @override
  Widget build(BuildContext context) {
    if (isTesting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Debug Results")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.bug_report, color: Colors.amber, size: 80),
            const SizedBox(height: 20),
            const Text("Assessment Finished", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Check your computer's terminal/console\nfor the full copy-pasteable JSON.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 30),
            Expanded(
              child: SingleChildScrollView(
                // We also show it here just in case
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(sessionData),
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      ),
    );
  }
}