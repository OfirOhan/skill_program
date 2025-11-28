// main.dart
import 'package:flutter/material.dart';
import 'blink_game.dart'; // This imports the game file below

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitive Test Suite',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String lastScore = "No test taken yet";

  void _startGame(BuildContext context) async {
    // Navigate to the separate game file and wait for the result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BlinkMatchWidget()),
    );

    // If we received a result back from the game
    if (result != null && result is Map) {
      setState(() {
        // Format the result nicely
        lastScore = "Last Score:\n"
            "Working Memory: ${(result['Working Memory'] * 100).toStringAsFixed(1)}%\n"
            "Hits: ${result['Raw Hits']}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cognitive Assessment")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "N-Back Test",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text("START 2-BACK GAME"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () => _startGame(context),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[200],
              child: Text(lastScore, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}