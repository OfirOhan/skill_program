// lib/logic_blocks_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class LogicBlocksGame extends StatefulWidget {
  const LogicBlocksGame({Key? key}) : super(key: key);

  @override
  _LogicBlocksGameState createState() => _LogicBlocksGameState();
}

class _LogicBlocksGameState extends State<LogicBlocksGame> {
  late List<List<PipeTile>> grid;
  int gridSize = 3;
  bool isGameOver = false;

  static const int totalLevels = 3;
  int currentLevelIndex = 0;

  Timer? _levelTimer;
  int remainingSeconds = 15; // Fixed 15s start

  int levelsSolved = 0;
  int moves = 0;

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

  void _startTimer() {
    remainingSeconds = 15; // FORCE 15 SECONDS PER ROUND
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
    _levelTimer?.cancel();
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
    if (currentLevelIndex >= totalLevels) {
      _finishGame();
      return;
    }

    // Difficulty scaling (Size increases, Time stays 15s)
    if (currentLevelIndex == 0) gridSize = 3;
    else if (currentLevelIndex == 1) gridSize = 4;
    else gridSize = 6; // Expert Size

    grid = _generateMazeGrid(gridSize);

    final rand = Random();
    for (var row in grid) {
      for (var tile in row) {
        if (tile.type != PipeType.empty) {
          int rotations = rand.nextInt(4);
          tile.rotation = (tile.rotation + rotations) % 4;
        }
      }
    }

    _checkFlow();
    _startTimer();
  }

  void _onTileTap(int r, int c) {
    if (isGameOver) return;

    setState(() {
      grid[r][c].rotation = (grid[r][c].rotation + 1) % 4;
      moves++;
    });

    _checkFlow();
  }

  void _checkFlow() {
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
    double completion = levelsSolved / totalLevels.toDouble();
    // Efficiency calculation adjusted for high speed play
    double efficiency = levelsSolved == 0 ? 0.0 : (1.0 - (moves / (levelsSolved * 25))).clamp(0.0, 1.0);

    return {
      "Programming Logic": completion,
      "Algorithmic Thinking": (completion * 0.7 + efficiency * 0.3).clamp(0.0, 1.0),
      "Debugging & Troubleshooting": efficiency,
      "System Understanding": completion * 0.9,
      "Technical Documentation Understanding": 0.5,
      "Problem Decomposition": completion,
      "Planning & Prioritization": efficiency,
      "Decision-Making Under Pressure": completion,
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
              const Icon(Icons.water_drop, color: Colors.blueAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Pipeline Secure!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Levels Solved: $levelsSolved / $totalLevels", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(grade()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("7. Pipe Flow (${currentLevelIndex + 1}/$totalLevels)"),
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
                        color: remainingSeconds <= 5 ? Colors.red : Colors.orangeAccent
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
            color: Colors.blue[50],
            width: double.infinity,
            child: const Text("Connect the BLUE source to the GREEN drain.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!, width: 4)
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
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

    Color pipeColor = Colors.grey[600]!;
    if (tile.hasFlow) pipeColor = Colors.blueAccent;

    return GestureDetector(
      onTap: () => _onTileTap(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black12,
        ),
        child: AnimatedRotation(
          turns: tile.rotation * 0.25,
          duration: const Duration(milliseconds: 100),
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

// --- MAZE GENERATOR (DFS for complexity) ---
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

      if (count == 1) g[r][c].type = PipeType.elbow;
      else if (count == 2) {
        if ((conn[0] && conn[2]) || (conn[1] && conn[3])) g[r][c].type = PipeType.straight;
        else g[r][c].type = PipeType.elbow;
      } else if (count == 3) g[r][c].type = PipeType.tee;
      else g[r][c].type = PipeType.cross;

      if (count < 4 && rand.nextDouble() < 0.3) {
        if (g[r][c].type == PipeType.straight) g[r][c].type = PipeType.tee;
        else if (g[r][c].type == PipeType.elbow) g[r][c].type = PipeType.tee;
        else if (g[r][c].type == PipeType.tee) g[r][c].type = PipeType.cross;
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
    final paint = Paint()..color = color..strokeWidth = size.width / 3.5..strokeCap = StrokeCap.round;
    double cx = size.width / 2;
    double cy = size.height / 2;

    if (type != PipeType.empty) canvas.drawCircle(Offset(cx, cy), size.width/7, paint);

    if (type == PipeType.straight) canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    else if (type == PipeType.elbow) {
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
      canvas.drawLine(Offset(cx, cy), Offset(0, cy), paint);
    }
    else if (type == PipeType.tee) {
      canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), paint);
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
      canvas.drawLine(Offset(cx, cy), Offset(0, cy), paint);
    }
    else if (type == PipeType.cross) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
      canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    }

    if (isStart) {
      final p = Paint()..color = Colors.blue..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), size.width/3, p);
      final border = Paint()..color = Colors.white..style=PaintingStyle.stroke..strokeWidth=3;
      canvas.drawCircle(Offset(cx, cy), size.width/3, border);
    }

    if (isEnd) {
      final bg = Paint()..color = Colors.green[900]!..style=PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), size.width/3, bg);
      final ring = Paint()..color = hasFlow ? Colors.greenAccent : Colors.green..style = PaintingStyle.stroke..strokeWidth = 4;
      canvas.drawCircle(Offset(cx, cy), size.width/3, ring);
      if (hasFlow) {
        final glow = Paint()..color = Colors.greenAccent.withOpacity(0.8)..style=PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), size.width/4, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}