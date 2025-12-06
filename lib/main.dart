// lib/main.dart
import 'package:flutter/material.dart';
import 'session_manager.dart'; // Import the new manager
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 🔒 Lock orientation (e.g., portrait only)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // optionally: DeviceOrientation.portraitDown
  ]);

  // 🎨 Your existing UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // make flutter draw behind navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cognitive Test',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade900, Colors.blue.shade800],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "Cognitive Battery",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Text(
              "15 Micro-Games • 6 Minutes",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 60),

            // THE PLAY BUTTON
            ElevatedButton(
              onPressed: () {
                // Start the Session Manager
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SessionManager()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(30),
                elevation: 10,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 60),
            ),
            const SizedBox(height: 20),
            const Text("Tap to Start", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}