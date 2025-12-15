// lib/session_manager.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'game_intro_screen.dart';
import 'skill_aggregator.dart';
import 'derived_skill_engine.dart';

// --- IMPORT ALL GAMES ---
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
import 'games/signal_decode_game.dart';

// --- DEMOS ---
import 'demos/blink_demo.dart';
import 'demos/matrix_demo.dart';
import 'demos/digit_demo.dart';
import 'demos/word_ladder_demo.dart';
import 'demos/brick_demo.dart';
import 'demos/split_tap_demo.dart';
import 'demos/logic_block_demo.dart';
import 'demos/chart_demo.dart';
import 'demos/spin_demo.dart';
import 'demos/precision_demo.dart';
import 'demos/color_cascade_demo.dart';
import 'demos/beat_buddy_demo.dart';
import 'demos/roleplay_demo.dart';
import 'demos/plan_push_demo.dart';
import 'demos/stress_split_demo.dart';

class SessionManager extends StatefulWidget {
  const SessionManager({Key? key}) : super(key: key);

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  final Map<String, dynamic> sessionData = {
    "user_id": "guest_debug_01",
    "timestamp": DateTime.now().toIso8601String(),
    "games": {}
  };

  int currentGameIndex = 0;
  bool finished = false;

  // --- GAME SEQUENCE ---
  final List<Widget> gameSequence = [
    const GameIntroScreen(
      title: "1. Blink & Match",
      icon: Icons.flash_on,
      instruction: "Memorize the position and color.\nTap MATCH if the current item matches the one from 2 steps ago.",
      gameWidget: BlinkMatchWidget(),
      demoWidget: BlinkDemoWidget(),
    ),
    const GameIntroScreen(
      title: "2. Matrix Logic",
      icon: Icons.grid_on,
      instruction: "Identify the pattern in the grid.",
      gameWidget: MatrixSwipeWidget(),
      demoWidget: MatrixDemoWidget(),
    ),
    const GameIntroScreen(
      title: "3. Digit Shuffle",
      icon: Icons.onetwothree,
      instruction: "Memorize the numbers shown.",
      gameWidget: DigitShuffleWidget(),
      demoWidget: DigitShuffleDemoWidget(),
    ),
    const GameIntroScreen(
      title: "4. Logic Sprint",
      icon: Icons.lightbulb_outline,
      instruction: "Solve logic puzzles.",
      gameWidget: WordLadderGame(),
      demoWidget: WordLadderDemoWidget(),
    ),
    const GameIntroScreen(
      title: "5. Object Brainstorm",
      icon: Icons.construction,
      instruction: "Generate creative uses.",
      gameWidget: BrickGame(),
      demoWidget: BrickDemoWidget(),
    ),
    const GameIntroScreen(
      title: "6. Split Tap",
      icon: Icons.splitscreen,
      instruction: "Multitasking test.",
      gameWidget: SplitTapGame(),
      demoWidget: SplitTapDemoWidget(),
    ),
    const GameIntroScreen(
      title: "7. Pipe Flow",
      icon: Icons.water_drop,
      instruction: "Connect the flow.",
      gameWidget: LogicBlocksGame(),
      demoWidget: LogicBlocksDemoWidget(),
    ),
    const GameIntroScreen(
      title: "8. Chart Dash",
      icon: Icons.bar_chart,
      instruction: "Analyze charts.",
      gameWidget: ChartDashGame(),
      demoWidget: ChartDashDemoWidget(),
    ),
    const GameIntroScreen(
      title: "9. 3D Spin",
      icon: Icons.view_in_ar,
      instruction: "Match the 3D object.",
      gameWidget: SpinGame(),
      demoWidget: SpinDemoWidget(),
    ),
    const GameIntroScreen(
      title: "10. Precision Path",
      icon: Icons.fingerprint,
      instruction: "Trace carefully.",
      gameWidget: PrecisionGame(),
      demoWidget: PrecisionDemoWidget(),
    ),
    const GameIntroScreen(
      title: "11. Color Cascade",
      icon: Icons.palette,
      instruction: "Color perception.",
      gameWidget: ColorCascadeGame(),
      demoWidget: ColorCascadeDemoWidget(),
    ),
    const GameIntroScreen(
      title: "12. Beat Buddy",
      icon: Icons.music_note,
      instruction: "Rhythm tapping.",
      gameWidget: BeatBuddyGame(),
      demoWidget: BeatBuddyDemoWidget(),
    ),
    const GameIntroScreen(
      title: "13. Social Signal",
      icon: Icons.psychology,
      instruction: "Interpret social intent.",
      gameWidget: RoleplayGame(),
      demoWidget: RoleplayDemoWidget(),
    ),
    const GameIntroScreen(
      title: "14. Plan Push",
      icon: Icons.calendar_month,
      instruction: "Optimize planning.",
      gameWidget: PlanPushGame(),
      demoWidget: PlanPushDemoWidget(),
    ),
    const GameIntroScreen(
      title: "15. Stress Sprint",
      icon: Icons.timer_off,
      instruction: "Fast math under stress.",
      gameWidget: StressSprintGame(),
      demoWidget: StressSprintDemoWidget(),
    ),
    const GameIntroScreen(
      title: "16. Signal Decode",
      icon: Icons.radar,
      instruction: "Decode multi-modal signals.",
      gameWidget: SignalDecodeGame(),
      demoWidget: Placeholder(),
    ),
  ];

  final List<String> gameIds = [
    "blink_match",
    "matrix_reasoning",
    "digit_shuffle",
    "logic_sprint",
    "brick_uses",
    "split_tap",
    "pipe_flow",
    "chart_dash",
    "3d_spin",
    "precision_path",
    "color_cascade",
    "beat_buddy",
    "social_signal",
    "plan_push",
    "stress_sprint",
    "signal_decode",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAssessment());
  }

  Future<void> _runAssessment() async {
    for (int i = 0; i < gameSequence.length && mounted; i++) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => gameSequence[i]),
      );
      sessionData["games"][gameIds[i]] = result ?? "SKIPPED";
    }

    _finalize();
  }

  void _finalize() {
    final direct = SkillAggregator.aggregate(sessionData["games"]);
    final derived = DerivedSkillEngine.derive(direct);

    sessionData["final_skills"] = {
      ...direct,
      ...derived,
    };

    setState(() {
      finished = true;
    });

    print("\n===== ASSESSMENT COMPLETE =====");
    print(const JsonEncoder.withIndent("  ").convert(sessionData));
  }

  @override
  Widget build(BuildContext context) {
    if (!finished) {
      // IMPORTANT: do NOT block navigation with a spinner
      return const Scaffold(
        body: Center(
          child: Text(
            "Assessment in progress…",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // FINAL RESULTS SCREEN
    return Scaffold(
      appBar: AppBar(title: const Text("Session Results")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.psychology_alt, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              "Assessment Complete!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  const JsonEncoder.withIndent("  ").convert(sessionData),
                  style: const TextStyle(fontFamily: "Courier", fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
