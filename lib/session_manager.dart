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
import 'games/word_group_game.dart';
import 'games/signal_decode_game.dart';

// --- IMPORT DEMOS ---
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
import 'demos/word_group_demo.dart';

class SessionManager extends StatefulWidget {
  const SessionManager({Key? key}) : super(key: key);

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  // -----------------------------
  // SESSION STATE
  // -----------------------------
  final Map<String, dynamic> sessionData = {
    "user_id": "guest_debug_01",
    "timestamp": DateTime.now().toIso8601String(),
    "games": <String, dynamic>{},
  };

  int currentGameIndex = 0;
  bool isTesting = true;
  bool _isLaunching = false;

  // -----------------------------
  // GAME SEQUENCE
  // -----------------------------
  final List<Widget> gameSequence = [
    const GameIntroScreen(
      title: "1. Blink & Match",
      icon: Icons.flash_on,
      instruction:
      "Memorize the position and color.\nTap MATCH if the current item matches the one from 2 steps ago.",
      gameWidget: BlinkMatchWidget(),
      demoWidget: BlinkDemoWidget(),
    ),
    const GameIntroScreen(
      title: "2. Matrix Logic",
      icon: Icons.grid_on,
      instruction:
      "Identify the pattern in the grid.\nSelect the missing piece.",
      gameWidget: MatrixSwipeWidget(),
      demoWidget: MatrixDemoWidget(),
    ),
    const GameIntroScreen(
      title: "3. Digit Shuffle",
      icon: Icons.onetwothree,
      instruction:
      "Memorize numbers.\nType them back in reverse or sorted order.",
      gameWidget: DigitShuffleWidget(),
      demoWidget: DigitShuffleDemoWidget(),
    ),
    const GameIntroScreen(
      title: "4. Logic Sprint",
      icon: Icons.lightbulb_outline,
      instruction:
      "Solve logic analogies.\nThink fast.",
      gameWidget: WordLadderGame(),
      demoWidget: WordLadderDemoWidget(),
    ),
    const GameIntroScreen(
      title: "5. Object Brainstorm",
      icon: Icons.construction,
      instruction:
      "Generate creative uses.\nChoose the best one.",
      gameWidget: BrickGame(),
      demoWidget: BrickDemoWidget(),
    ),
    const GameIntroScreen(
      title: "6. Split Tap",
      icon: Icons.splitscreen,
      instruction:
      "Multitask tapping + math.",
      gameWidget: SplitTapGame(),
      demoWidget: SplitTapDemoWidget(),
    ),
    const GameIntroScreen(
      title: "7. Pipe Flow",
      icon: Icons.water_drop,
      instruction:
      "Rotate pipes to connect flow.",
      gameWidget: LogicBlocksGame(),
      demoWidget: LogicBlocksDemoWidget(),
    ),
    const GameIntroScreen(
      title: "8. Chart Dash",
      icon: Icons.bar_chart,
      instruction:
      "Analyze chart trends.",
      gameWidget: ChartDashGame(),
      demoWidget: ChartDashDemoWidget(),
    ),
    const GameIntroScreen(
      title: "9. 3D Spin",
      icon: Icons.view_in_ar,
      instruction:
      "Match rotating 3D shapes.",
      gameWidget: SpinGame(),
      demoWidget: SpinDemoWidget(),
    ),
    const GameIntroScreen(
      title: "10. Precision Path",
      icon: Icons.fingerprint,
      instruction:
      "Trace carefully.\nDo not touch walls.",
      gameWidget: PrecisionGame(),
      demoWidget: PrecisionDemoWidget(),
    ),
    const GameIntroScreen(
      title: "11. Color Cascade",
      icon: Icons.palette,
      instruction:
      "Color sorting and odd-one-out.",
      gameWidget: ColorCascadeGame(),
      demoWidget: ColorCascadeDemoWidget(),
    ),
    const GameIntroScreen(
      title: "12. Beat Buddy",
      icon: Icons.music_note,
      instruction:
      "Tap in rhythm.",
      gameWidget: BeatBuddyGame(),
      demoWidget: BeatBuddyDemoWidget(),
    ),
    const GameIntroScreen(
      title: "13. Social Signal",
      icon: Icons.psychology,
      instruction:
      "Infer social meaning.",
      gameWidget: RoleplayGame(),
      demoWidget: RoleplayDemoWidget(),
    ),
    const GameIntroScreen(
      title: "14. Plan Push",
      icon: Icons.calendar_month,
      instruction:
      "Optimize schedule.",
      gameWidget: PlanPushGame(),
      demoWidget: PlanPushDemoWidget(),
    ),
    const GameIntroScreen(
      title: "15. Stress Sprint",
      icon: Icons.timer_off,
      instruction:
      "Math under pressure.",
      gameWidget: WordGroupsGame(),
      demoWidget: WordGroupsDemoWidget(),
    ),
    const GameIntroScreen(
      title: "16. Signal Decode",
      icon: Icons.radar,
      instruction:
      "Decode signals under time pressure.",
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
    "word_group",
    "signal_decode",
  ];

  // -----------------------------
  // LIFECYCLE
  // -----------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchCurrentGame();
    });
  }

  // -----------------------------
  // GAME FLOW
  // -----------------------------
  Future<void> _launchCurrentGame() async {
    if (_isLaunching) return;
    _isLaunching = true;

    while (mounted && currentGameIndex < gameSequence.length) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => gameSequence[currentGameIndex],
        ),
      );

      sessionData['games'][gameIds[currentGameIndex]] =
          result ?? "SKIPPED";

      currentGameIndex++;
    }

    _isLaunching = false;
    if (!mounted) return;
    _finishAssessment();
  }

  // -----------------------------
  // FINALIZATION (FIXED)
  // -----------------------------
  void _finishAssessment() {
    if (!mounted) return;

    Map<String, double?> directSkills = {};
    Map<String, double?> derivedSkills = {};

    try {
      directSkills = SkillAggregator.aggregate(
        (sessionData['games'] as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      sessionData['aggregation_error'] = e.toString();
    }

    try {
      final Map<String, double> nonNullDirect = {};
      directSkills.forEach((k, v) {
        if (v != null) nonNullDirect[k] = v;
      });

      derivedSkills = DerivedSkillEngine.derive(nonNullDirect);
    } catch (e) {
      sessionData['derivation_error'] = e.toString();
    }

    final Map<String, double?> finalSkills = {
      ...derivedSkills,
    };

    directSkills.forEach((k, v) {
      if (v != null) finalSkills[k] = v;
    });

    sessionData['final_skills'] = finalSkills;

    setState(() {
      isTesting = false;
    });

    debugPrint(
      const JsonEncoder.withIndent('  ').convert(sessionData),
    );
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    if (isTesting) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Assessment in progress...",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Session Results")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            const JsonEncoder.withIndent('  ')
                .convert(sessionData),
            style: const TextStyle(fontFamily: 'Courier'),
          ),
        ),
      ),
    );
  }
}
