// lib/demos/logic_blocks_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

// --- ENUMS ---
enum DemoPipeType { straight, elbow, tee, cross, empty }

class LogicBlocksDemoWidget extends StatefulWidget {
  const LogicBlocksDemoWidget({Key? key}) : super(key: key);

  @override
  _LogicBlocksDemoWidgetState createState() => _LogicBlocksDemoWidgetState();
}

class _LogicBlocksDemoWidgetState extends State<LogicBlocksDemoWidget> {
  // Demo Layout (2x2)
  // [0,0] START (Fixed) -> Connects Right
  // [0,1] TURN (Rotate) -> Needs Left & Bottom
  // [1,0] DUMMY         -> Distractor
  // [1,1] END (Fixed)   -> Connects Top

  // Rotation Logic (Painter Default: 0 = Left & Bottom)
  // 0: Left & Bottom (TARGET for [0,1])
  // 1: Top & Left    (Target for [1,1] End)
  // 2: Right & Top
  // 3: Bottom & Right (Target for [0,0] Start)

  int rotTurn = 2; // Starts at 2 (Right/Top) -> Broken

  bool flowTurn = false;
  bool flowEnd = false;

  int step = 0;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _startDemoLoop();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  void _startDemoLoop() {
    // RESET
    setState(() {
      step = 0;
      rotTurn = 2; // Pointing Right/Top (Disconnected from Start on Left)
      flowTurn = false;
      flowEnd = false;
    });

    // Step 0: WAIT (1.0s)
    _loopTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      // Step 1: ROTATE TURN TILE (1.0s)
      // Cycle 2 -> 3 (Bottom/Right)
      // Connects Bottom (to End) but NOT Left (to Start).
      // Still no flow.
      setState(() {
        step = 1;
        rotTurn = 3;
      });

      Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;

        // Step 2: ROTATE TURN TILE (1.8s)
        // Cycle 3 -> 0 (Left/Bottom)
        // Connects Left (to Start) AND Bottom (to End).
        // FLOW COMPLETE!
        setState(() {
          step = 2;
          rotTurn = 0;
          flowTurn = true;
          flowEnd = true;
        });

        // Step 3: SUCCESS BADGE (1.0s delay)
        Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          setState(() => step = 3);

          // RESTART (2.0s delay)
          Timer(const Duration(milliseconds: 2000), _startDemoLoop);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wraps content tightly
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
            child: const Text("CONNECT THE FLOW", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(height: 16),

          // Grid
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo[100]!, width: 4),
              ),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
                children: [
                  // [0,0] START (Blue Source)
                  _buildTile(
                      type: DemoPipeType.elbow,
                      rotation: 3,
                      isStart: true,
                      hasFlow: true
                  ),

                  // [0,1] TURN TILE (Rotatable)
                  _buildTile(
                      type: DemoPipeType.elbow,
                      rotation: rotTurn,
                      hasFlow: flowTurn,
                      isHighlight: step < 2
                  ),

                  // [1,0] DUMMY
                  _buildTile(
                      type: DemoPipeType.elbow,
                      rotation: 1,
                      hasFlow: true
                  ),

                  // [1,1] END (Green Target)
                  _buildTile(
                      type: DemoPipeType.elbow,
                      rotation: 1,
                      isEnd: true,
                      hasFlow: flowEnd
                  ),
                ],
              ),
            ),
          ),

          // Added Spacer here to push the text down a little
          const SizedBox(height: 12),

          AnimatedOpacity(
            opacity: step == 3 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                  "FLOW STABLE!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTile({
    required DemoPipeType type,
    required int rotation,
    bool isStart = false,
    bool isEnd = false,
    bool hasFlow = false,
    bool isHighlight = false,
  }) {
    Color pipeColor = hasFlow ? Colors.blue : Colors.blueGrey[100]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          border: isHighlight
              ? Border.all(color: Colors.indigo.withOpacity(0.3), width: 2)
              : Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(4)
      ),
      child: AnimatedRotation(
        turns: rotation * 0.25,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        child: CustomPaint(
          painter: DemoPipePainter(type, pipeColor, isStart, isEnd, hasFlow),
        ),
      ),
    );
  }
}

// --- EXACT PAINTER (Light Theme) ---
class DemoPipePainter extends CustomPainter {
  final DemoPipeType type;
  final Color color;
  final bool isStart;
  final bool isEnd;
  final bool hasFlow;

  DemoPipePainter(this.type, this.color, this.isStart, this.isEnd, this.hasFlow);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = size.width / 3.5..strokeCap = StrokeCap.round;
    double cx = size.width / 2;
    double cy = size.height / 2;

    if (type != DemoPipeType.empty) canvas.drawCircle(Offset(cx, cy), size.width/7, paint);

    if (type == DemoPipeType.straight) canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    else if (type == DemoPipeType.elbow) {
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint); // Bottom
      canvas.drawLine(Offset(cx, cy), Offset(0, cy), paint);          // Left
    }

    if (isStart) {
      final p = Paint()..color = Colors.blue..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), size.width/3, p);
      final border = Paint()..color = Colors.white..style=PaintingStyle.stroke..strokeWidth=3;
      canvas.drawCircle(Offset(cx, cy), size.width/3, border);
    }

    if (isEnd) {
      final bg = Paint()..color = Colors.green..style=PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), size.width/3, bg);

      final ring = Paint()..color = hasFlow ? Colors.greenAccent : Colors.white..style = PaintingStyle.stroke..strokeWidth = 4;
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