// lib/game_intro_screen.dart
import 'package:flutter/material.dart';

class GameIntroScreen extends StatefulWidget {
  final String title;
  final String instruction;
  final IconData icon;
  final List<String> skills; // Kept for backend tracking, but hidden from UI
  final Widget gameWidget;

  const GameIntroScreen({
    Key? key,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.skills,
    required this.gameWidget,
  }) : super(key: key);

  @override
  _GameIntroScreenState createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends State<GameIntroScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    // 1. If user clicked Start, show the Game Widget directly.
    if (_isPlaying) {
      return widget.gameWidget;
    }

    // 2. Otherwise, show the Intro UI (HIDDEN SKILLS VERSION)
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: Icon(widget.icon, size: 60, color: Colors.indigo),
            ),
            const SizedBox(height: 40),

            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 30),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    const Text("MISSION", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                    const SizedBox(height: 20),
                    Text(
                      widget.instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, height: 1.5, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

            // SKILLS SECTION REMOVED HERE

            const Spacer(),

            SizedBox(
              height: 70,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isPlaying = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: const Text("START", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}