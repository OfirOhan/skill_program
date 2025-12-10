import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- VISUAL CONFIGURATION ---
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

  // --- CHANGED: Precise Result Tracking ---
  // We now track exactly which items were correct to separate skills reliably.
  List<bool> itemResults = [];
  List<int> itemTimes = [];

  int startMs = 0;

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 15;

  @override
  void initState() {
    super.initState();
    items = _generateVisualItems();
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (index >= items.length) {
      _finishGame();
      return;
    }

    setState(() {
      remainingSeconds = 15;
      startMs = DateTime.now().millisecondsSinceEpoch;
    });

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _roundTimer?.cancel();
    HapticFeedback.vibrate();

    // Record explicit failure (False) and max time penalty
    itemResults.add(false);
    itemTimes.add(15000);

    setState(() => index++);
    _startRound();
  }

  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void onChoose(int optionIndex) {
    if (isGameOver) return;
    _roundTimer?.cancel();
    HapticFeedback.lightImpact();

    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    itemTimes.add(elapsed);

    final item = items[index];

    // Record specific result
    bool isCorrect = (optionIndex == item.correctIndex);
    itemResults.add(isCorrect);
    
    if (isCorrect) {
       HapticFeedback.mediumImpact();
    } else {
       HapticFeedback.heavyImpact();
    }

    setState(() => index++);
    _startRound();
  }

  // --- MODIFIED & VALIDATED SKILL EXTRACTION ---
  Map<String, double> grade() {
    // 1. Initialize Counters
    double logicScoreSum = 0;
    double logicMaxSum = 0;

    double numericScoreSum = 0;
    double numericMaxSum = 0;

    double correctWeighted = 0;
    double totalDifficulty = 0;
    int correctCount = 0;

    // 2. Iterate through EXACT results to categorize performance
    for (int i = 0; i < itemResults.length; i++) {
      VisualMatrixItem item = items[i];
      bool correct = itemResults[i];

      // Global stats
      totalDifficulty += item.difficulty;
      if (correct) {
        correctWeighted += item.difficulty;
        correctCount++;
      }

      // Categorization for Reliability
      // Items 2, 3, 5 are Numerical (Subtraction, Cyclic, Arithmetic)
      // Items 1, 4, 6 are Logic/Spatial (Rotation, Sudoku, XOR)
      bool isNumerical = ["Subtraction", "Cyclic Pattern", "Arithmetic"].contains(item.logicDescription);

      if (isNumerical) {
        numericMaxSum += item.difficulty;
        if (correct) numericScoreSum += item.difficulty;
      } else {
        logicMaxSum += item.difficulty;
        if (correct) logicScoreSum += item.difficulty;
      }
    }

    // 3. Calculate Core Metrics (0.0 - 1.0)
    double globalAccuracyWeighted = totalDifficulty == 0 ? 0.0 : correctWeighted / totalDifficulty;
    double globalAccuracyRaw = items.isEmpty ? 0.0 : correctCount / items.length;

    // 4. Calculate Specific Skill Scores
    // Use raw 0.0 if they didn't encounter any questions of that type (e.g., quit early)
    double logicalReasoningScore = logicMaxSum == 0 ? 0.0 : logicScoreSum / logicMaxSum;
    double numericalReasoningScore = numericMaxSum == 0 ? 0.0 : numericScoreSum / numericMaxSum;

    // 5. Time & Efficiency
    double avgTimeMs = itemTimes.isEmpty ? 15000 : itemTimes.reduce((a, b) => a + b) / itemTimes.length;
    double speedFactor = (1.0 - (avgTimeMs / 15000)).clamp(0.0, 1.0);
    double efficiency = globalAccuracyWeighted * (0.5 + (speedFactor * 0.5));

    return {
      // RELIABLE: Based strictly on "Rotation", "Sudoku", and "XOR" questions.
      "Logical Reasoning": logicalReasoningScore,

      // RELIABLE: Based strictly on "Subtraction", "Cyclic", and "Arithmetic" questions.
      // This is now a direct measurement, not a guess.
      "Numerical Reasoning": numericalReasoningScore,

      // RELIABLE: Matrix tests are the definition of abstract reasoning.
      // Weighted global accuracy is the standard metric here.
      "Abstract Reasoning": globalAccuracyWeighted,

      // RELIABLE: System understanding implies grasping the whole grid.
      // We weight the "Logic" questions higher here as they represent system rules (Sudoku/XOR)
      // more than the counting ones.
      "System Understanding": (logicalReasoningScore * 0.7) + (globalAccuracyWeighted * 0.3),

      // RELIABLE: Pattern rec requires seeing it (Accuracy) + seeing it fast (Speed).
      "Pattern Recognition": (globalAccuracyRaw * 0.7) + (speedFactor * 0.3),

      // RELIABLE: Visual perception is foundational. If you got *any* right, you have some perception.
      // Unweighted accuracy is best here (getting the easy visual ones counts).
      "Visual Perception Accuracy": globalAccuracyRaw,

      // RELIABLE: Efficiency (Accuracy + Speed) is the definition of analytical capability.
      "Analytical Thinking": efficiency,

      // RELIABLE: Decomposition is required for the hardest levels (Diff 5 & 6).
      // If the user reached and solved those, this score will be high.
      // If they failed the hard ones, this score naturally drops.
      "Problem Decomposition": globalAccuracyWeighted,

      // Note: "Mathematical Skill" and "Scientific Thinking" remain removed
      // as they are inextricably low-signal in this specific game format.
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_on, color: Colors.tealAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Matrix Test Complete!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // Updated to use the tracking list for display
              Text("Score: ${itemResults.where((b) => b).length} / ${items.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () { 
                   HapticFeedback.lightImpact(); 
                   Navigator.of(context).pop(grade());
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
              ),
            ],
          ),
        ),
      );
    }

    // ... (Rest of the UI build method remains exactly the same)
    final item = items[index];
    bool is3x3 = item.gridSize == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text("2. Matrix Logic (${index + 1}/${items.length})"),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
                child: Text(
                    "${remainingSeconds}s",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: remainingSeconds <= 5 ? Colors.red : Colors.indigo
                    )
                )
            ),
          ),
          TextButton(onPressed: () { 
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(null);
          }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
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
        ],
      ),
    );
  }

  // ... (Helper widgets _buildCell, _drawCellContent, etc. remain unchanged)
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
          double size = 50;
          if (!shape.isOutline && [ShapeType.plus, ShapeType.cross, ShapeType.star].contains(shape.shape)) {
            size = 30;
          }
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
    if ([ShapeType.lineVert, ShapeType.lineHorz, ShapeType.lineDiagF, ShapeType.lineDiagB].contains(shape.shape)) {
      double w = 4.0;
      double h = size * 0.8;
      double rotation = 0.0;
      if (shape.shape == ShapeType.lineHorz) { w = size * 0.8; h = 4.0; }
      if (shape.shape == ShapeType.lineDiagF) rotation = 0.125;
      if (shape.shape == ShapeType.lineDiagB) rotation = -0.125;

      return Transform.rotate(
        angle: rotation * 2 * pi,
        child: Container(
            width: w, height: h,
            decoration: BoxDecoration(color: shape.color, borderRadius: BorderRadius.circular(4))
        ),
      );
    } else if (shape.shape == ShapeType.arc) {
      return Icon(Icons.refresh, size: size, color: shape.color);
    }

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
        case ShapeType.triangle: icon = Icons.change_history; break;
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

// --- FIXED GENERATOR LOGIC (Unchanged) ---
List<VisualMatrixItem> _generateVisualItems() {
  return [
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
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.75)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.black, rotation: 0.25)],
          [MatrixShape(shape: ShapeType.arrow, color: Colors.red, rotation: 0.75)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.black)],
        ],
        correctIndex: 2
    ),
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
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, count: 1)],
          [MatrixShape(shape: ShapeType.square, color: Colors.blue, count: 1)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, count: 1)],
        ],
        correctIndex: 3
    ),
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
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 2)],
          [MatrixShape(shape: ShapeType.square, color: Colors.black, count: 2)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.red, count: 2)],
          [MatrixShape(shape: ShapeType.triangle, color: Colors.black, count: 4)],
        ],
        correctIndex: 2
    ),
    VisualMatrixItem(
        difficulty: 4, gridSize: 3, logicDescription: "Sudoku Logic (Unique Row/Col)",
        grid: [
          [MatrixShape(shape: ShapeType.square, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
          [MatrixShape(shape: ShapeType.diamond, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],

          [MatrixShape(shape: ShapeType.diamond, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],

          [MatrixShape(shape: ShapeType.circle, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],
          [MatrixShape(shape: ShapeType.diamond, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.square, color: Colors.orange, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.star, color: Colors.black)],
          [MatrixShape(shape: ShapeType.diamond, color: Colors.red, isOutline: true), MatrixShape(shape: ShapeType.plus, color: Colors.black)],
          [MatrixShape(shape: ShapeType.square, color: Colors.blue, isOutline: true), MatrixShape(shape: ShapeType.cross, color: Colors.black)],
        ],
        correctIndex: 1
    ),
    VisualMatrixItem(
        difficulty: 5, gridSize: 3, logicDescription: "Arithmetic",
        grid: [
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 3)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 4)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)], [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)],
        ],
        options: [
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 1)],
          [MatrixShape(shape: ShapeType.square, color: Colors.teal, count: 2)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 2)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 3)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.red, count: 2)],
          [MatrixShape(shape: ShapeType.circle, color: Colors.teal, count: 4)],
        ],
        correctIndex: 2
    ),
    VisualMatrixItem(
      difficulty: 6,
      gridSize: 3,
      logicDescription: "Column XOR",
      grid: [
        [MatrixShape(shape: ShapeType.circle, color: Colors.red), MatrixShape(shape: ShapeType.triangle, color: Colors.blue, rotation: 0.25)],
        [MatrixShape(shape: ShapeType.square, color: Colors.orange), MatrixShape(shape: ShapeType.plus, color: Colors.purple, rotation: 0.1)],
        [MatrixShape(shape: ShapeType.diamond, color: Colors.yellow), MatrixShape(shape: ShapeType.lineHorz, color: Colors.black, rotation: 0.0)],
        [MatrixShape(shape: ShapeType.triangle, color: Colors.blue, rotation: 0.25), MatrixShape(shape: ShapeType.star, color: Colors.green)],
        [MatrixShape(shape: ShapeType.diamond, color: Colors.teal), MatrixShape(shape: ShapeType.plus, color: Colors.purple, rotation: 0.1)],
        [MatrixShape(shape: ShapeType.lineHorz, color: Colors.black, rotation: 0.0), MatrixShape(shape: ShapeType.arc, color: Colors.brown, rotation: 0.5)],
        [MatrixShape(shape: ShapeType.circle, color: Colors.red), MatrixShape(shape: ShapeType.star, color: Colors.green)],
        [MatrixShape(shape: ShapeType.square, color: Colors.orange), MatrixShape(shape: ShapeType.diamond, color: Colors.teal)],
      ],
      options: [
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