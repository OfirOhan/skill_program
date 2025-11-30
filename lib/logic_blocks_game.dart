// lib/logic_blocks_game.dart
import 'dart:async';
import 'dart:math'; // <--- THIS WAS MISSING
import 'package:flutter/material.dart';

class LogicBlocksGame extends StatefulWidget {
  const LogicBlocksGame({Key? key}) : super(key: key);

  @override
  _LogicBlocksGameState createState() => _LogicBlocksGameState();
}

class _LogicBlocksGameState extends State<LogicBlocksGame> {
  int level = 0; // 0 to 2
  bool isGameOver = false;

  // Timer
  Timer? _gameTimer;
  int remainingSeconds = 45; // 45s for complex logic

  // Metrics
  int levelsCompleted = 0;
  int movesCount = 0; // Efficiency
  int mistakes = 0;   // Failed submissions
  int timeSpent = 0;

  // Circuit State (Level specific)
  late List<GateState> currentGates;
  late CircuitConfig currentConfig;

  @override
  void initState() {
    super.initState();
    _loadLevel(0);
    _startGameTimer();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      timeSpent++;
      if (remainingSeconds <= 0) _finishGame();
    });
  }

  void _finishGame() {
    _gameTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _loadLevel(int lvl) {
    if (lvl >= _levels.length) {
      _finishGame();
      return;
    }
    level = lvl;
    currentConfig = _levels[lvl];
    // Initialize gates with "Unknown" or pre-set types
    currentGates = List.generate(
        currentConfig.gateCount,
            (i) => GateState(id: i, type: GateType.none)
    );
  }

  void _toggleGate(int index) {
    if (isGameOver) return;
    setState(() {
      // Cycle: AND -> OR -> XOR -> None
      switch (currentGates[index].type) {
        case GateType.none: currentGates[index].type = GateType.AND; break;
        case GateType.AND: currentGates[index].type = GateType.OR; break;
        case GateType.OR: currentGates[index].type = GateType.XOR; break;
        case GateType.XOR: currentGates[index].type = GateType.none; break;
        default: currentGates[index].type = GateType.none;
      }
      movesCount++;
    });
  }

  void _checkCircuit() {
    bool success = currentConfig.validator(currentGates);
    if (success) {
      levelsCompleted++;
      _showFeedback(true);
    } else {
      mistakes++;
      _showFeedback(false);
    }
  }

  void _showFeedback(bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? "CIRCUIT ACTIVE!" : "SHORT CIRCUIT! Try again."),
      backgroundColor: success ? Colors.green : Colors.red,
      duration: const Duration(milliseconds: 800),
    ));

    if (success) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        _loadLevel(level + 1);
      });
    }
  }

  Map<String, double> grade() {
    // 1. Programming Logic (Completion rate)
    double completion = levelsCompleted / _levels.length.toDouble();

    // 2. Efficiency (Algorithmic Thinking)
    // Fewer moves = better planning.
    // Ideal moves is roughly gateCount. If moves > gateCount * 3, efficiency drops.
    double efficiency = 1.0;
    if (levelsCompleted > 0) {
      efficiency = (1.0 - (movesCount / (levelsCompleted * 5))).clamp(0.0, 1.0);
    }

    // 3. Debugging (Inverse of mistakes)
    double debugging = (1.0 - (mistakes / 5.0)).clamp(0.0, 1.0);

    return {
      "Programming Logic": completion,
      "Algorithmic Thinking": (completion * 0.7 + efficiency * 0.3),
      "Debugging & Troubleshooting": debugging,
      "System Understanding": completion * 0.9,
      "Technical Documentation Understanding": 0.8, // Implied by understanding symbols
      "Problem Decomposition": completion,
      "Planning & Prioritization": efficiency,
      "Decision-Making Under Pressure": (1.0 - (mistakes / max(1, levelsCompleted + mistakes))).clamp(0.0, 1.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) return _buildResultsScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text("7. Logic Blocks ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
      ),
      body: Column(
        children: [
          // 1. Goal Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo[50],
            width: double.infinity,
            child: Column(
              children: [
                Text("LEVEL ${level + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 5),
                Text(currentConfig.goalDescription, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),

          // 2. Circuit Board Area
          Expanded(
            child: Center(
              child: SingleChildScrollView( // Allow scroll for small screens
                child: currentConfig.buildUI(context, currentGates, _toggleGate),
              ),
            ),
          ),

          // 3. Control Panel
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _checkCircuit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.power_settings_new),
                label: const Text("ACTIVATE CIRCUIT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text("7. Logic Blocks"), automaticallyImplyLeading: false),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.developer_board, color: Colors.teal, size: 80),
            const SizedBox(height: 20),
            const Text("System Check Complete", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Levels Solved: $levelsCompleted / ${_levels.length}", style: const TextStyle(color: Colors.grey, fontSize: 18)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(grade()),
              icon: const Icon(Icons.arrow_forward),
              label: const Text("NEXT GAME"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOGIC GATE ENGINE ---

enum GateType { none, AND, OR, XOR }

class GateState {
  final int id;
  GateType type;
  GateState({required this.id, required this.type});
}

class CircuitConfig {
  final int gateCount;
  final String goalDescription;
  final bool Function(List<GateState>) validator;
  final Widget Function(BuildContext, List<GateState>, Function(int)) buildUI;

  CircuitConfig({
    required this.gateCount,
    required this.goalDescription,
    required this.validator,
    required this.buildUI
  });
}

// --- LEVELS DEFINITION ---
final List<CircuitConfig> _levels = [
  // LEVEL 1: Basic Logic
  CircuitConfig(
      gateCount: 1,
      goalDescription: "Make the Light turn ON.\nInput A is ON, Input B is OFF.",
      validator: (gates) {
        // Goal: 1 ? 0 = 1.
        // AND(1,0)=0. OR(1,0)=1. XOR(1,0)=1.
        return gates[0].type == GateType.OR || gates[0].type == GateType.XOR;
      },
      buildUI: (context, gates, toggle) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildInputs(true, false), // 1, 0
            _buildWire(height: 30),
            _buildGate(gates[0], toggle),
            _buildWire(height: 30),
            _buildOutput(false), // Initially off
          ],
        );
      }
  ),

  // LEVEL 2: 3-Input Cascade
  CircuitConfig(
      gateCount: 2,
      goalDescription: "Route the power to the end.\nInputs: ON, OFF, ON",
      validator: (gates) {
        // Logic: (1 ? 0) ? 1 = 1
        // If Gate 1 is AND -> 0. Then 0 ? 1 = 1 -> Needs OR/XOR.
        // If Gate 1 is OR -> 1. Then 1 ? 1 = 1 -> Needs AND/OR.

        bool g1Result;
        if (gates[0].type == GateType.AND) g1Result = false;
        else if (gates[0].type == GateType.OR || gates[0].type == GateType.XOR) g1Result = true;
        else return false;

        // Gate 2 Input: g1Result, 1
        if (gates[1].type == GateType.AND) return g1Result && true;
        if (gates[1].type == GateType.OR) return g1Result || true;
        if (gates[1].type == GateType.XOR) return g1Result ^ true;
        return false;
      },
      buildUI: (context, gates, toggle) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(children: [_buildInputBox(true), SizedBox(height: 5), _buildWire(height: 20)]),
                SizedBox(width: 40),
                Column(children: [_buildInputBox(false), SizedBox(height: 5), _buildWire(height: 20)]),
              ],
            ),
            _buildGate(gates[0], toggle),
            _buildWire(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 20, child: Divider(thickness: 4, color: Colors.grey)), // Connector from top
                SizedBox(width: 40),
                Column(children: [_buildInputBox(true), SizedBox(height: 5), _buildWire(height: 10)]), // Input 3
              ],
            ),
            _buildGate(gates[1], toggle),
            _buildWire(height: 20),
            _buildOutput(false),
          ],
        );
      }
  ),

  // LEVEL 3: Complex Debugging
  CircuitConfig(
      gateCount: 3,
      goalDescription: "Fix the broken circuit.\nInputs: OFF, OFF, ON, OFF",
      validator: (gates) {
        // Tree: (0 ? 0) -> Res1. (1 ? 0) -> Res2.  Res1 ? Res2 = 1.
        // Gate 0 (Left): Inputs 0,0. AND/OR/XOR -> Result ALWAYS 0.
        bool res1 = false;

        // Gate 1 (Right): Inputs 1,0.
        // AND=0. OR=1. XOR=1.
        bool res2;
        if (gates[1].type == GateType.AND) res2 = false;
        else if (gates[1].type == GateType.OR || gates[1].type == GateType.XOR) res2 = true;
        else return false; // Right branch failed

        // Gate 2 (Bottom): Inputs 0, Res2.
        // We need Final = 1.
        // Since Left is 0, we MUST have Res2=1 AND Gate2 must be OR or XOR.

        if (!res2) return false; // Right branch must be true

        if (gates[2].type == GateType.OR || gates[2].type == GateType.XOR) return true;

        return false;
      },
      buildUI: (context, gates, toggle) {
        return Column(
          children: [
            Row( // Top Inputs
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInputBox(false), _buildInputBox(false), // For Gate 0
                _buildInputBox(true), _buildInputBox(false),  // For Gate 1
              ],
            ),
            Row( // Top Gates
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGate(gates[0], toggle),
                _buildGate(gates[1], toggle),
              ],
            ),
            // Visual wiring is tricky in pure code without a canvas, simplified layout:
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(height: 40),
                // Left wire diagonal
                Positioned(left: 100, child: Transform.rotate(angle: -0.5, child: Container(width: 4, height: 50, color: Colors.grey))),
                // Right wire diagonal
                Positioned(right: 100, child: Transform.rotate(angle: 0.5, child: Container(width: 4, height: 50, color: Colors.grey))),
              ],
            ),
            _buildGate(gates[2], toggle),
            _buildWire(height: 20),
            _buildOutput(false),
          ],
        );
      }
  ),
];

// --- UI HELPERS ---

Widget _buildGate(GateState gate, Function(int) onToggle) {
  Color color = Colors.grey[300]!;
  String text = "?";

  if (gate.type == GateType.AND) { color = Colors.purple[100]!; text = "AND"; }
  if (gate.type == GateType.OR) { color = Colors.orange[100]!; text = "OR"; }
  if (gate.type == GateType.XOR) { color = Colors.blue[100]!; text = "XOR"; }

  return GestureDetector(
    onTap: () => onToggle(gate.id),
    child: Container(
      width: 80, height: 60,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black54, width: 2),
          boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12, offset: Offset(2,2))]
      ),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
    ),
  );
}

Widget _buildInputs(bool a, bool b) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _buildInputBox(a),
      _buildInputBox(b),
    ],
  );
}

Widget _buildInputBox(bool isOn) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
        color: isOn ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(4)
    ),
    child: Text(isOn ? "ON" : "OFF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  );
}

Widget _buildWire({required double height}) {
  return Container(width: 4, height: height, color: Colors.grey[700]);
}

Widget _buildOutput(bool active) {
  return Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
        border: Border.all(color: Colors.black, width: 2)
    ),
    child: Icon(Icons.lightbulb, color: Colors.grey, size: 40),
  );
}