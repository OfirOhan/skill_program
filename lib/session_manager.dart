// lib/session_manager.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'game_intro_screen.dart'; // Make sure this file exists in lib/

// --- IMPORT ALL GAMES (From games/ directory) ---
import 'games/blink_game.dart';
import 'games/matrix_game.dart';
import 'games/digit_shuffle.dart';
import 'games/word_ladder_game.dart';
import 'games/brick_game.dart';
import 'games/split_tap_game.dart';
import 'games/logic_blocks_game.dart';
import 'games/chart_game.dart';
import 'games/spin_game.dart';
import 'games/precision_game.dart';
import 'games/color_cascade_game.dart';
import 'games/beat_buddy_game.dart';
import 'games/roleplay_game.dart';
import 'games/plan_push_game.dart';
import 'games/stress_sprint_game.dart';

// --- IMPORT ALL DEMOS (From demos/ directory) ---
import 'demos/blink_demo.dart';
import 'demos/matrix_demo.dart';

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

  // --- THE PLAYLIST (Wrapped with Intro Screens) ---
  final List<Widget> gameSequence = [
    // 1. Blink & Match
    const GameIntroScreen(
      title: "1. Blink & Match",
      icon: Icons.flash_on,
      instruction: "Memorize the position and color.\nTap MATCH if the current item matches the one from 2 steps ago.",
      gameWidget: BlinkMatchWidget(),
      demoWidget: BlinkDemoWidget(), // <--- ADDED THIS
    ),

    // 2. Matrix Swipe
    const GameIntroScreen(
      title: "2. Matrix Logic",
      icon: Icons.grid_on,
      instruction: "Identify the pattern in the grid.\nSelect the missing piece that completes the logic.",
      gameWidget: MatrixSwipeWidget(),
      demoWidget: MatrixDemoWidget(),
    ),

    // 3. Digit Shuffle
    const GameIntroScreen(
      title: "3. Digit Shuffle",
      icon: Icons.onetwothree,
      instruction: "Memorize the numbers shown.\nThen, type them back in reverse or sorted order as requested.",
      gameWidget: DigitShuffleWidget(),
    ),

    // 4. Logic Sprint
    const GameIntroScreen(
      title: "4. Logic Sprint",
      icon: Icons.lightbulb_outline,
      instruction: "Solve the visual analogies and logic puzzles.\nThink fast: 'A is to B as C is to...?'",
      gameWidget: WordLadderGame(),
    ),

    // 5. Brick Uses
    const GameIntroScreen(
      title: "5. Brick Uses",
      icon: Icons.construction,
      instruction: "Phase 1: Type as many creative uses for a brick as you can.\nPhase 2: Choose the most creative solution.",
      gameWidget: BrickGame(),
    ),

    // 6. Split Tap
    const GameIntroScreen(
      title: "6. Split Tap",
      icon: Icons.splitscreen,
      instruction: "Multitasking Test!\nTap the LEFT side when the color matches the rule.\nSolve Math on the RIGHT side.",
      gameWidget: SplitTapGame(),
    ),

    // 7. Pipe Flow
    const GameIntroScreen(
      title: "7. Pipe Flow",
      icon: Icons.water_drop,
      instruction: "Rotate the pipes to create a continuous path from the Blue Source to the Green Drain.",
      gameWidget: LogicBlocksGame(),
    ),

    // 8. Chart Dash
    const GameIntroScreen(
      title: "8. Chart Dash",
      icon: Icons.bar_chart,
      instruction: "Analyze the chart data quickly.\nAnswer the question about trends, max/min, or ratios.",
      gameWidget: ChartDashGame(),
    ),

    // 9. 3D Spin
    const GameIntroScreen(
      title: "9. 3D Spin",
      icon: Icons.view_in_ar,
      instruction: "Look at the rotating 3D object.\nIdentify which static option matches it (watch out for mirrored traps!).",
      gameWidget: SpinGame(),
    ),

    // 10. Precision Path
    const GameIntroScreen(
      title: "10. Precision Path",
      icon: Icons.fingerprint,
      instruction: "Trace the line from Green to Red.\nDo NOT touch the walls. Move smoothly.",
      gameWidget: PrecisionGame(),
    ),

    // 11. Color Cascade
    const GameIntroScreen(
      title: "11. Color Cascade",
      icon: Icons.palette,
      instruction: "Round 1: Sort shades from Light to Dark.\nRound 2: Find the odd color in the grid.",
      gameWidget: ColorCascadeGame(),
    ),

    // 12. Beat Buddy
    const GameIntroScreen(
      title: "12. Beat Buddy",
      icon: Icons.music_note,
      instruction: "Visual Rhythm.\nTap exactly when the shrinking ring hits the center target.",
      gameWidget: BeatBuddyGame(),
    ),

    // 13. Social Signal
    const GameIntroScreen(
      title: "13. Social Signal",
      icon: Icons.psychology,
      instruction: "Read the quote and the context.\nIdentify the true hidden meaning or social intent.",
      gameWidget: RoleplayGame(),
    ),

    // 14. Plan Push
    const GameIntroScreen(
      title: "14. Plan Push",
      icon: Icons.calendar_month,
      instruction: "Fill the schedule with tasks to maximize Value.\nDo not go overtime!",
      gameWidget: PlanPushGame(),
    ),

    // 15. Stress Sprint
    const GameIntroScreen(
      title: "15. Stress Sprint",
      icon: Icons.timer_off,
      instruction: "Solve simple math as the timer gets faster.\nPress CASH OUT to save points before you crash.",
      gameWidget: StressSprintGame(),
    ),
  ];

  final List<String> gameIds = [
    "blink_match", "matrix_reasoning", "digit_shuffle", "logic_sprint",
    "brick_uses", "split_tap", "pipe_flow", "chart_dash",
    "3d_spin", "precision_path", "color_cascade", "beat_buddy",
    "social_signal", "plan_push", "stress_sprint"
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
    // Loading Screen
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