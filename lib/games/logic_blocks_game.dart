// lib/logic_blocks_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED FOR HAPTICS & SOUND

class LogicBlocksGame extends StatefulWidget {
  const LogicBlocksGame({Key? key}) : super(key: key);

  @override
  _LogicBlocksGameState createState() => _LogicBlocksGameState();
}

class _LogicBlocksGameState extends State<LogicBlocksGame> {
  late List<List<PipeTile>> grid;
  int gridSize = 3;
  bool isGameOver = false;

  // Lock to prevent double-winning
  bool isProcessingWin = false;

  static const int totalLevels = 3;
  int currentLevelIndex = 0;

  Timer? _levelTimer;
  int remainingSeconds = 15;

  int levelsSolved = 0;
  int moves = 0;

  // --- NEW: per-level evidence (tracking only) ---
  int _levelStartMs = 0;
  int _levelMoves = 0;
  final Map<int, int> _tileTapCounts = {}; // key = r*gridSize + c

  final List<int> _playedGridSizes = [];
  final List<bool> _levelSolved = [];
  final List<int> _levelTimeMs = [];
  final List<int> _levelMovesList = [];
  final List<int> _levelWastedCycles = [];

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  int _computeWastedCycles() {
    int cycles = 0;
    for (final c in _tileTapCounts.values) {
      cycles += (c ~/ 4); // 4 taps returns to same rotation => definite wasted loop(s)
    }
    return cycles;
  }

  void _recordLevelResult({required bool solved}) {
    final int limitMs = remainingSeconds <= 0 ? 15000 : 15000; // fixed level limit
    final int now = DateTime.now().millisecondsSinceEpoch;

    final int timeTaken = solved
        ? (now - _levelStartMs).clamp(0, limitMs)
        : limitMs;

    _playedGridSizes.add(gridSize);
    _levelSolved.add(solved);
    _levelTimeMs.add(timeTaken);
    _levelMovesList.add(_levelMoves);
    _levelWastedCycles.add(_computeWastedCycles());
  }

  void _startTimer() {
    remainingSeconds = 15;
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _finishGame() {
    _levelTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _handleTimeout() {
    if (isProcessingWin) return;
    _levelTimer?.cancel();
    _recordLevelResult(solved: false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Time's Up! Moving to next level..."),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 800),
        )
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        currentLevelIndex++;
        _startLevel();
      });
    });
  }

  void _startLevel() {
    isProcessingWin = false; // Unlock for new level

    if (currentLevelIndex >= totalLevels) {
      _finishGame();
      return;
    }

    if (currentLevelIndex == 0) gridSize = 3;
    else if (currentLevelIndex == 1) gridSize = 4;
    else gridSize = 6;

    grid = _generateMazeGrid(gridSize);

    final rand = Random();
    for (var row in grid) {
      for (var tile in row) {
        if (tile.type == PipeType.empty) continue;

        if (tile.type == PipeType.straight) {
          tile.rotation = (tile.rotation + 1) % 4;
        } else if (tile.type == PipeType.cross) {
          tile.rotation = rand.nextInt(4);
        } else {
          int rotations = rand.nextInt(3) + 1;
          tile.rotation = (tile.rotation + rotations) % 4;
        }
      }
    }
    _levelStartMs = DateTime.now().millisecondsSinceEpoch;
    _levelMoves = 0;
    _tileTapCounts.clear();

    _checkFlow();
    _startTimer();
  }

  void _onTileTap(int r, int c) {
    if (isGameOver || isProcessingWin) return;

    // --- FEEDBACK SECTION ---
    // 1. Vibration (Requires real device + permission)
    HapticFeedback.lightImpact();

    // 2. Sound (System "Click" sound)
    // SystemSound.play(SystemSoundType.click); // Removed to avoid double feedback or keep audio logic separate
    // ------------------------

    setState(() {
      _levelMoves++;
      final key = r * gridSize + c;
      _tileTapCounts[key] = (_tileTapCounts[key] ?? 0) + 1;
      grid[r][c].rotation = (grid[r][c].rotation + 1) % 4;
      moves++;
    });

    _checkFlow();
  }

  void _checkFlow() {
    if (isProcessingWin) return;

    for (var row in grid) {
      for (var tile in row) tile.hasFlow = false;
    }

    List<Point> queue = [const Point(0,0)];
    grid[0][0].hasFlow = true;
    bool reachedEnd = false;

    while (queue.isNotEmpty) {
      Point p = queue.removeAt(0);
      PipeTile current = grid[p.x.toInt()][p.y.toInt()];

      List<Point> neighbors = [
        Point(p.x - 1, p.y), Point(p.x, p.y + 1),
        Point(p.x + 1, p.y), Point(p.x, p.y - 1)
      ];

      for (Point n in neighbors) {
        if (n.x >= 0 && n.x < gridSize && n.y >= 0 && n.y < gridSize) {
          PipeTile neighbor = grid[n.x.toInt()][n.y.toInt()];

          if (!neighbor.hasFlow && _isConnected(current, neighbor, p, n)) {
            neighbor.hasFlow = true;
            queue.add(n);
            if (n.x == gridSize - 1 && n.y == gridSize - 1) reachedEnd = true;
          }
        }
      }
    }

    if (reachedEnd) {
      _triggerWin();
    }
  }

  void _triggerWin() {
    if (isProcessingWin) return;
    isProcessingWin = true; // LOCK
    _recordLevelResult(solved: true);
    // Optional: Win Sound/Vibration
    HapticFeedback.vibrate();

    _levelTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("FLOW STABLE!"), backgroundColor: Colors.green, duration: Duration(milliseconds: 500))
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          levelsSolved++;
          currentLevelIndex++;
          _startLevel();
        });
      }
    });
  }

  bool _isConnected(PipeTile curr, PipeTile next, Point currP, Point nextP) {
    int dirToNext = 0;
    if (nextP.x > currP.x) dirToNext = 2;
    if (nextP.x < currP.x) dirToNext = 0;
    if (nextP.y > currP.y) dirToNext = 1;
    if (nextP.y < currP.y) dirToNext = 3;

    if (!curr.hasOpening(dirToNext)) return false;
    int dirFromPrev = (dirToNext + 2) % 4;
    if (!next.hasOpening(dirFromPrev)) return false;

    return true;
  }

  Map<String, double> grade() {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    final int n = [
      _playedGridSizes.length,
      _levelSolved.length,
      _levelTimeMs.length,
      _levelMovesList.length,
      _levelWastedCycles.length,
    ].reduce((a, b) => a < b ? a : b);

    if (n <= 0) {
      return {
        "Deductive Reasoning": 0.0,
        "Algorithmic Logic": 0.0,
        "Information Processing Speed": 0.0,
      };
    }

    // --- Completion weighted by problem size (tiles = gridSize^2) ---
    double totalW = 0.0;
    double solvedW = 0.0;

    for (int i = 0; i < n; i++) {
      final int size = _playedGridSizes[i];
      final double w = (size * size).toDouble(); // defensible difficulty weight
      totalW += w;
      if (_levelSolved[i]) solvedW += w;
    }

    final double completion = totalW <= 0 ? 0.0 : clamp01(solvedW / totalW);

    // --- Deductive Reasoning: solving these constraint puzzles is the direct evidence ---
    final double deductiveReasoning = completion;

    // --- Algorithmic Logic: efficiency, using only non-arbitrary evidence ---
    // 1) moves-per-tile (lower is better)
    // 2) wasted full-cycles (4 taps return to same state => definite dithering)
    double algoSum = 0.0;

    for (int i = 0; i < n; i++) {
      final int size = _playedGridSizes[i];
      final int tiles = size * size;

      final int mv = _levelMovesList[i];
      final int cycles = _levelWastedCycles[i];

      final double movesPerTile = tiles == 0 ? 999.0 : (mv / tiles);
      final double movesScore = 1.0 / (1.0 + movesPerTile);     // 0..1, no magic thresholds
      final double cyclesScore = 1.0 / (1.0 + cycles.toDouble()); // 0..1, conservative

      // Combine; only count strongly if they solved (avoid rewarding random spinning)
      final double perLevelAlgo = _levelSolved[i]
          ? sqrt(movesScore * cyclesScore)
          : 0.0;

      algoSum += perLevelAlgo;
    }

    final double algorithmicLogic = clamp01(algoSum / n);

    // --- Information Processing Speed: median level time, earned & gated by completion ---
    double informationProcessingSpeed = 0.0;
    {
      final times = _levelTimeMs.take(n).toList()..sort();
      final int mid = times.length ~/ 2;
      final double medianMs = times.length.isOdd
          ? times[mid].toDouble()
          : ((times[mid - 1] + times[mid]) / 2.0);

      const double limitMs = 15000.0;
      final double rawSpeed = clamp01(1.0 - (medianMs / limitMs));

      // Earned: no speed points if they didn't complete levels
      informationProcessingSpeed = clamp01(rawSpeed * completion);
    }

    return {
      "Deductive Reasoning": deductiveReasoning,
      "Algorithmic Logic": algorithmicLogic,
      "Information Processing Speed": informationProcessingSpeed,
    };
  }



  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, color: Colors.blueAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Pipeline Secure!", style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Levels Solved: $levelsSolved / $totalLevels", style: const TextStyle(color: Colors.grey, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(grade()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("7. Pipe Flow"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
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
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo[50],
            width: double.infinity,
            child: const Text("Connect the BLUE source to the GREEN drain.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo[100]!, width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      crossAxisSpacing: 0,
                      mainAxisSpacing: 0,
                    ),
                    itemCount: gridSize * gridSize,
                    itemBuilder: (context, i) {
                      int r = i ~/ gridSize;
                      int c = i % gridSize;
                      return _buildTile(grid[r][c], r, c);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(PipeTile tile, int r, int c) {
    bool isStart = (r == 0 && c == 0);
    bool isEnd = (r == gridSize - 1 && c == gridSize - 1);

    Color pipeColor = Colors.blueGrey[100]!;
    if (tile.hasFlow) pipeColor = Colors.blue;

    return GestureDetector(
      onTap: () => _onTileTap(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: AnimatedRotation(
          turns: tile.rotation * 0.25,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: CustomPaint(
            painter: PipePainter(tile.type, pipeColor, isStart, isEnd, tile.hasFlow),
          ),
        ),
      ),
    );
  }
}

// --- DATA STRUCTURES ---
enum PipeType { straight, elbow, tee, cross, empty }

class PipeTile {
  PipeType type;
  int rotation;
  bool hasFlow;
  PipeTile({required this.type, this.rotation = 0, this.hasFlow = false});

  bool hasOpening(int dir) {
    int effectiveDir = (dir - rotation + 4) % 4;
    switch (type) {
      case PipeType.straight: return effectiveDir == 0 || effectiveDir == 2;
      case PipeType.elbow: return effectiveDir == 2 || effectiveDir == 3;
      case PipeType.tee: return effectiveDir != 0;
      case PipeType.cross: return true;
      default: return false;
    }
  }
}

// --- MAZE GENERATOR ---
List<List<PipeTile>> _generateMazeGrid(int size) {
  var g = List.generate(size, (_) => List.generate(size, (_) => PipeTile(type: PipeType.empty)));
  List<Point<int>> stack = [const Point(0, 0)];
  List<List<bool>> visited = List.generate(size, (_) => List.filled(size, false));
  visited[0][0] = true;
  final rand = Random();
  var connections = List.generate(size, (_) => List.generate(size, (_) => [false, false, false, false]));

  while (stack.isNotEmpty) {
    Point<int> current = stack.last;
    List<int> neighbors = [];
    if (current.x > 0 && !visited[current.x - 1][current.y]) neighbors.add(0);
    if (current.y < size - 1 && !visited[current.x][current.y + 1]) neighbors.add(1);
    if (current.x < size - 1 && !visited[current.x + 1][current.y]) neighbors.add(2);
    if (current.y > 0 && !visited[current.x][current.y - 1]) neighbors.add(3);

    if (neighbors.isNotEmpty) {
      int dir = neighbors[rand.nextInt(neighbors.length)];
      int nx = current.x, ny = current.y;
      if (dir == 0) nx--; if (dir == 1) ny++; if (dir == 2) nx++; if (dir == 3) ny--;
      connections[current.x][current.y][dir] = true;
      connections[nx][ny][(dir + 2) % 4] = true;
      visited[nx][ny] = true;
      stack.add(Point(nx, ny));
    } else {
      stack.removeLast();
    }
  }

  for(int r=0; r<size; r++) {
    for(int c=0; c<size; c++) {
      var conn = connections[r][c];
      int count = conn.where((b) => b).length;
      if (count == 1) {
        g[r][c].type = PipeType.elbow;
        if (conn[0]) g[r][c].rotation = 1;
        if (conn[1]) g[r][c].rotation = 2;
        if (conn[2]) g[r][c].rotation = 3;
        if (conn[3]) g[r][c].rotation = 0;
      }
      else if (count == 2) {
        if (conn[0] && conn[2]) {
          g[r][c].type = PipeType.straight;
          g[r][c].rotation = 0;
        } else if (conn[1] && conn[3]) {
          g[r][c].type = PipeType.straight;
          g[r][c].rotation = 1;
        } else {
          g[r][c].type = PipeType.elbow;
          if (conn[2] && conn[3]) g[r][c].rotation = 0;
          if (conn[3] && conn[0]) g[r][c].rotation = 1;
          if (conn[0] && conn[1]) g[r][c].rotation = 2;
          if (conn[1] && conn[2]) g[r][c].rotation = 3;
        }
      }
      else if (count == 3) {
        g[r][c].type = PipeType.tee;
        if (!conn[0]) g[r][c].rotation = 0;
        if (!conn[1]) g[r][c].rotation = 1;
        if (!conn[2]) g[r][c].rotation = 2;
        if (!conn[3]) g[r][c].rotation = 3;
      }
      else {
        g[r][c].type = PipeType.cross;
      }
    }
  }
  return g;
}

// --- PAINTER ---
class PipePainter extends CustomPainter {
  final PipeType type;
  final Color color;
  final bool isStart;
  final bool isEnd;
  final bool hasFlow;

  PipePainter(this.type, this.color, this.isStart, this.isEnd, this.hasFlow);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width / 3.0
      ..strokeCap = StrokeCap.round;

    double cx = size.width / 2;
    double cy = size.height / 2;
    double ext = 2.0;

    if (type != PipeType.empty) {
      canvas.drawCircle(Offset(cx, cy), size.width / 6.0, paint);
    }

    if (type == PipeType.straight) {
      canvas.drawLine(Offset(cx, -ext), Offset(cx, size.height + ext), paint);
    }
    else if (type == PipeType.elbow) {
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height + ext), paint);
      canvas.drawLine(Offset(cx, cy), Offset(-ext, cy), paint);
    }
    else if (type == PipeType.tee) {
      canvas.drawLine(Offset(cx, cy), Offset(size.width + ext, cy), paint);
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height + ext), paint);
      canvas.drawLine(Offset(cx, cy), Offset(-ext, cy), paint);
    }
    else if (type == PipeType.cross) {
      canvas.drawLine(Offset(cx, -ext), Offset(cx, size.height + ext), paint);
      canvas.drawLine(Offset(-ext, cy), Offset(size.width + ext, cy), paint);
    }

    if (isStart) {
      final p = Paint()..color = Colors.blue..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), size.width/2.5, p);
      final border = Paint()..color = Colors.white..style=PaintingStyle.stroke..strokeWidth=3;
      canvas.drawCircle(Offset(cx, cy), size.width/2.5, border);
    }

    if (isEnd) {
      final bg = Paint()..color = Colors.green..style=PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), size.width/2.5, bg);

      final ring = Paint()..color = hasFlow ? Colors.greenAccent : Colors.white
        ..style = PaintingStyle.stroke..strokeWidth = 4;
      canvas.drawCircle(Offset(cx, cy), size.width/2.5, ring);

      if (hasFlow) {
        final glow = Paint()..color = Colors.greenAccent.withOpacity(0.8)..style=PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), size.width/3.5, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}