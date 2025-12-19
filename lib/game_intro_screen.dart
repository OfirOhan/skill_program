// lib/game_intro_screen.dart
import 'package:flutter/material.dart';

class GameIntroScreen extends StatefulWidget {
  final String title;
  final String instruction;
  final IconData icon;
  final Widget gameWidget;
  final Widget? demoWidget; // Optional Demo

  const GameIntroScreen({
    Key? key,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.gameWidget,
    this.demoWidget,
  }) : super(key: key);

  @override
  _GameIntroScreenState createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends State<GameIntroScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      return widget.gameWidget;
    }

    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TITLE (Restored)
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 20),

                  // 2. INSTRUCTIONS
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text("MISSION", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                      const SizedBox(height: 12),
                      Text(
                        widget.instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, height: 1.4, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. DEMO OR ICON (Moved Down, Expanded to fill space)
              Expanded(
                flex: 4,
                child: widget.demoWidget != null
                    ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.withOpacity(0.1), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.demoWidget,
                  ),
                )
                    : CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(widget.icon, size: 80, color: Colors.indigo),
                ),
              ),

              const SizedBox(height: 30),

              // 4. START BUTTON
              SizedBox(
                height: 60,
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
                    elevation: 4,
                  ),
                  child: const Text("START", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
      // SKIP BUTTON OVERLAY
      Positioned(
        top: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
             padding: const EdgeInsets.all(8.0),
             child: TextButton(
               onPressed: () => Navigator.of(context).pop(null),
               child: const Text("SKIP", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
             ),
          ),
        ),
      ),
    ],
  ),
);
  }
}