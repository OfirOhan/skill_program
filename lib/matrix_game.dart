// lib/matrix_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- VISUAL CONFIGURATION ---
// Added specific abstract shapes for Level 6
enum ShapeType {
  square, circle, triangle, diamond, arrow, star, plus, cross,
  lineVert, lineHorz, lineDiagF, lineDiagB, arc, none
}

class MatrixShape {
  final ShapeType shape;
  final Color color;
  final int count;
  final double rotation;
  final bool isOutline;

  const MatrixShape({
    this.shape = ShapeType.circle,
    this.color = Colors.blue,
    this.count = 1,
    this.rotation = 0.0,
    this.isOutline = false,
  });

  static const empty = MatrixShape(shape: ShapeType.none, color: Colors.transparent);
}

class MatrixSwipeWidget extends StatefulWidget {
  const MatrixSwipeWidget({Key? key}) : super(key: key);

  @override
  _MatrixSwipeWidgetState createState() => _MatrixSwipeWidgetState();
}

class _MatrixSwipeWidgetState extends State<MatrixSwipeWidget> {
  late List<VisualMatrixItem> items;
  int index = 0;
  bool isGameOver = false;

  int correctWeighted = 0;
  int totalDifficultyEncountered = 0;
  List<int> itemTimes = [];
  int correctRaw = 0;
  int startMs = 0;

  Timer? _gameTimer;
  int remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    items = _generateVisualItems();
    startMs = DateTime.now().millisecondsSinceEpoch;
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
      if (remainingSeconds <= 0) _finishGame();
    });
  }

  void _finishGame() {
    _gameTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void next() {
    if (index >= items.length - 1) {
      _finishGame();
      return;
    }
    startMs = DateTime.now().millisecondsSinceEpoch;
    setState(() => index++);
  }

  void onChoose(int optionIndex) {
    if (isGameOver) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    itemTimes.add(elapsed);

    final item = items[index];
    totalDifficultyEncountered += item.difficulty;

    if (optionIndex == item.correctIndex) {
      correctWeighted += item.difficulty;
      correctRaw++;
    }
    next();
  }

  Map<String, double> grade() {
    double weightedAccuracy = totalDifficultyEncountered == 0 ? 0.0 : correctWeighted / totalDifficultyEncountered;
    double rawAccuracy = (index + 1) == 0 ? 0.0 : correctRaw / (index + 1);
    double avgTime = itemTimes.isEmpty ? 5000 : itemTimes.reduce((a,b)=>a+b) / itemTimes.length;
    double fluency = (1.0 - (avgTime / 25000)).clamp(0.0, 1.0);
    double deepLogic = weightedAccuracy > 0.65 ? 1.0 : weightedAccuracy * 0.6;

    return {
      "Logical Reasoning": weightedAccuracy,
      "Analytical Thinking": (weightedAccuracy * 0.6 + deepLogic * 0.4).clamp(0.0, 1.0),
      "Abstract Reasoning": deepLogic,
      "Pattern Recognition": fluency,
      "Problem Decomposition": weightedAccuracy * 0.9,
      "Numerical Reasoning": weightedAccuracy * 0.8,
      "Mathematical Skill": weightedAccuracy * 0.8,
      "System Understanding": weightedAccuracy,
      "Scientific Thinking": (weightedAccuracy * 0.7 + (1.0 - fluency) * 0.3).clamp(0.0, 1.0),
      "Visual Perception Accuracy": rawAccuracy,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (index >= items.length && !isGameOver) return const Scaffold(body: Center(child: Text("Done! Waiting...")));
    final item = items[index];
    bool is3x3 = item.gridSize == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text("2. Matrix Logic ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: item.gridSize,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: item.gridSize * item.gridSize,
                          itemBuilder: (context, i) {
                            if (i == (item.gridSize * item.gridSize) - 1) return _buildQuestionMark(is3x3);
                            if (i >= item.grid.length) return Container();
                            return _buildCell(item.grid[i]);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text("Difficulty ${item.difficulty} / 6", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  flex: 4,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: item.options.length,
                    itemBuilder: (context, i) {
                      return GestureDetector(
                        onTap: () => onChoose(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.indigo.withOpacity(0.3), width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _drawCellContent(item.options[i]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isGameOver)
            Container(
              color: Colors.black87,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(grade()),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("NEXT GAME"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(List<MatrixShape> shapes) {
    bool isEmpty = shapes.isEmpty || shapes.every((s) => s.shape == ShapeType.none);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isEmpty ? null : _drawCellContent(shapes),
    );
  }

  Widget _drawCellContent(List<MatrixShape> shapes) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Stack(
        alignment: Alignment.center,
        children: shapes.map((shape) {
          // Standardize size
          double size = 50;
          // If it's a small solid symbol inside a large outline, shrink it
          if (!shape.isOutline && [ShapeType.plus, ShapeType.cross, ShapeType.star].contains(shape.shape)) {
            size = 30;
          }
          // Level 6 abstract lines should be large
          if ([ShapeType.lineVert, ShapeType.lineHorz, ShapeType.lineDiagF, ShapeType.lineDiagB, ShapeType.arc].contains(shape.shape)) {
            size = 50;
          }
          return _drawSingleShape(shape, size);
        }).toList(),
      ),
    );
  }

  Widget _buildQuestionMark(bool isSmall) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        border: Border.all(color: Colors.indigo, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text("?", style: TextStyle(fontSize: isSmall ? 24 : 40, fontWeight: FontWeight.bold, color: Colors.indigo))),
    );
  }

  Widget _drawSingleShape(MatrixShape shape, double size) {
    if (shape.shape == ShapeType.none) return const SizedBox();

    IconData icon;
    // Map abstract shapes for Level 6
    if ([ShapeType.lineVert, ShapeType.lineHorz, ShapeType.lineDiagF, ShapeType.lineDiagB].contains(shape.shape)) {
      // Using simple rotation of a bar for all lines
      icon = Icons.remove; // Horizontal bar is the base
      double rotation = 0.0;
      if (shape.shape == ShapeType.lineVert) rotation = 0.25;
      if (shape.shape == ShapeType.lineDiagF) rotation = 0.125;
      if (shape.shape == ShapeType.lineDiagB) rotation = -0.125;

      return Transform.rotate(
        angle: rotation * 2 * pi,
        child: Icon(Icons.remove, size: size, color: shape.color), // Using remove (dash) as line
      );
    } else if (shape.shape == ShapeType.arc) {
      return Icon(Icons.refresh, size: size, color: shape.color);
    }

    // Standard Shapes
    if (shape.isOutline) {
      switch (shape.shape) {
        case ShapeType.square: icon = Icons.check_box_outline_blank; break;
        case ShapeType.circle: icon = Icons.circle_outlined; break;
        case ShapeType.triangle: icon = Icons.change_history; break;
        case ShapeType.diamond: icon = Icons.diamond_outlined; break;
        default: icon = Icons.check_box_outline_blank;
      }
    } else {
      switch (shape.shape) {
        case ShapeType.square: icon = Icons.square_rounded; break;
        case ShapeType.circle: icon = Icons.circle; break;
        case ShapeType.triangle: icon = Icons.change_history; break; // Solid triangle approx
        case ShapeType.diamond: icon = Icons.diamond; break;
        case ShapeType.arrow: icon = Icons.arrow_upward_rounded; break;
        case ShapeType.star: icon = Icons.star_rounded; break;
        case ShapeType.plus: icon = Icons.add_rounded; break;
        case ShapeType.cross: icon = Icons.close_rounded; break;
        default: icon = Icons.help;
      }
    }

    Widget baseIcon = Transform.rotate(
      angle: shape.rotation * 2 * pi,
      child: Icon(icon, size: size, color: shape.color),
    );

    if (shape.count > 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(shape.count, (i) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Transform.rotate(
                  angle: shape.rotation * 2 * pi,
                  child: Icon(icon, size: size * 0.8, color: shape.color)
              ),
            )
        ),
      );
    }
    return baseIcon;
  }
}

class VisualMatrixItem {
  final int difficulty;
  final int gridSize;
  final String logicDescription;
  final List<List<MatrixShape>> grid;
  final List<List<MatrixShape>> options;
  final int correctIndex;
  VisualMatrixItem({required this.difficulty, required this.gridSize, required this.logicDescription, required this.grid, required this.options, required this.correctIndex});
}
// --- FIXED GENERATOR LOGIC ---
List<VisualMatrixItem> _generateVisualItems() {
  return [
    // LVL 1: Rotation
    VisualMatrixItem(
        difficulty: 1, gridSize: 2, logicDescription: "Rotation",
        grid: [
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.0)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.25)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.5)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.0)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.12)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.25)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.red, rotation: 0.75)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.black)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.75)], // Correct (Left)
        ],
        correctIndex: 5
    ),

    // LVL 2: Subtraction
    VisualMatrixItem(
        difficulty: 2, gridSize: 2, logicDescription: "Subtraction",
        grid: [
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 4)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 3)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 2)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 3)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 4)],
          [MatrixShape(shape: ShapeType.none, color: Colors.transparent)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 1)], // Correct
          [MatrixShape(shape: ShapeType.square, color: Colors.blue, count: 1)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, count: 1)],
        ],
        correctIndex: 3
    ),

    // LVL 3: Cyclic Pattern
    VisualMatrixItem(
        difficulty: 3, gridSize: 3, logicDescription: "Cyclic Pattern",
        grid: [
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 1)], [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 2)], [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 3)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 2)], [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 3)], [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 1)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 3)], [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 1)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 1)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 3)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 2)], // Correct
          [MatrixShape(shape: ShapeType.square, color: Colors.black, count: 2)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.red, count: 2)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 4)],
        ],
        correctIndex: 2
    ),

    // LVL 4: Sudoku Logic (FIXED: Decoupled Shapes/Symbols)
    // Rules: Unique Shape, Unique Color, Unique Symbol per Row/Col.
    // Shapes: Sq, Cir, Dia.
    // Symbols: Plus, Cross, Star.
    VisualMatrixItem(
        difficulty: 4, gridSize: 3, logicDescription: "Sudoku Logic (Unique Row/Col)",
        grid: [
          // R1: Sq+, Cir x, Dia *
          [MatrixShape(shape: ShapeType.square, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
          [MatrixShape(shape: ShapeType.diamond, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],

          // R2: Dia x, Sq *, Cir +  <-- Fixed: Square is now Star, Diamond is Cross
          [MatrixShape(shape: ShapeType.diamond, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],

          // R3: Cir *, Dia +, ? (Sq x) <-- Fixed: Square must be Cross
          [MatrixShape(shape: ShapeType.circle, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],
          [MatrixShape(shape: ShapeType.diamond, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.square, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)], // Correct (Sq, Red, Cross)
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],
          [MatrixShape(shape: ShapeType.diamond, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
        ],
        correctIndex: 1
    ),

    // LVL 5: Sum Columns
    VisualMatrixItem(
        difficulty: 5, gridSize: 3, logicDescription: "Arithmetic (C1 + C2 = C3)",
        grid: [
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 3)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 4)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)],
          [MatrixShape(shape: ShapeType.square, color: Colors.teal, count: 2)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], // Correct (1+1=2)
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 3)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, count: 2)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 4)],
        ],
        correctIndex: 2
    ),

// LVL 6: XOR Logic (Complex, Harder, Readable)
    VisualMatrixItem(
      difficulty: 6,
      gridSize: 3,
      logicDescription: "Column XOR (Top ^ Mid = Bot, Complex Shapes)",
      grid: [
        // Row 1 (Top)
        [MatrixShape(shape: ShapeType.circle, color: Colors.red), MatrixShape(shape: ShapeType.triangle, color: Colors.blue, rotation: 0.25)], // Cell 0
        [MatrixShape(shape: ShapeType.square, color: Colors.orange), MatrixShape(shape: ShapeType.plus, color: Colors.purple, rotation: 0.1)], // Cell 1
        [MatrixShape(shape: ShapeType.diamond, color: Colors.yellow), MatrixShape(shape: ShapeType.lineHorz, color: Colors.black, rotation: 0.0)], // Cell 2

        // Row 2 (Mid)
        [MatrixShape(shape: ShapeType.triangle, color: Colors.blue, rotation: 0.25), MatrixShape(shape: ShapeType.star, color: Colors.green)], // Cell 3
        [MatrixShape(shape: ShapeType.diamond, color: Colors.teal), MatrixShape(shape: ShapeType.plus, color: Colors.purple, rotation: 0.1)], // Cell 4
        [MatrixShape(shape: ShapeType.lineHorz, color: Colors.black, rotation: 0.0), MatrixShape(shape: ShapeType.arc, color: Colors.brown, rotation: 0.5)], // Cell 5

        // Row 3 (Bottom) = XOR(Top ^ Mid)
        [MatrixShape(shape: ShapeType.circle, color: Colors.red), MatrixShape(shape: ShapeType.star, color: Colors.green)], // Cell 6
        [MatrixShape(shape: ShapeType.square, color: Colors.orange), MatrixShape(shape: ShapeType.diamond, color: Colors.teal)], // Cell 7
        [MatrixShape(shape: ShapeType.diamond, color: Colors.yellow), MatrixShape(shape: ShapeType.arc, color: Colors.brown, rotation: 0.5)], // Cell 8
      ],
      options: [
        // Correct XOR result
        [MatrixShape(shape: ShapeType.circle, color: Colors.red), MatrixShape(shape: ShapeType.star, color: Colors.green)],
        [MatrixShape(shape: ShapeType.square, color: Colors.orange), MatrixShape(shape: ShapeType.diamond, color: Colors.teal)],
        [MatrixShape(shape: ShapeType.circle, color: Colors.red), MatrixShape(shape: ShapeType.triangle, color: Colors.blue, rotation: 0.25)],
        [MatrixShape(shape: ShapeType.star, color: Colors.green), MatrixShape(shape: ShapeType.plus, color: Colors.purple, rotation: 0.1)],
        [MatrixShape(shape: ShapeType.diamond, color: Colors.yellow), MatrixShape(shape: ShapeType.arc, color: Colors.brown, rotation: 0.5)],
        [MatrixShape(shape: ShapeType.square, color: Colors.orange), MatrixShape(shape: ShapeType.arc, color: Colors.brown, rotation: 0.5)],
      ],
      correctIndex: 4,
    ),


  ];
}