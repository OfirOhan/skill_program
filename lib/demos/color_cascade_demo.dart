// lib/demos/color_cascade_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ColorCascadeDemoWidget extends StatefulWidget {
  const ColorCascadeDemoWidget({Key? key}) : super(key: key);

  @override
  _ColorCascadeDemoWidgetState createState() => _ColorCascadeDemoWidgetState();
}

class _ColorCascadeDemoWidgetState extends State<ColorCascadeDemoWidget> {
  // Demo State
  // 0: Sort Phase - Unsorted (Show "Sort Light -> Dark")
  // 1: Sort Phase - Sorting (Animate Swap)
  // 2: Sort Phase - Success ("Perfect!")
  // 3: Grid Phase - Unsolved (Show "Find Odd One")
  // 4: Grid Phase - Selecting (Highlight Odd Tile)
  // 5: Grid Phase - Success ("Correct!")
  int step = 0;
  Timer? _loopTimer;

  // SORT DATA (Teal Gradient)
  // Initial: [Light, Dark, Medium] -> Wrong
  // Target:  [Light, Medium, Dark] -> Correct
  List<Color> sortColors = [
    Colors.teal[100]!, // Lightest
    Colors.teal[900]!, // Darkest (Out of place)
    Colors.teal[500]!, // Medium
  ];

  // GRID DATA (Indigo)
  // Base: Indigo 500
  // Odd: Indigo 300 (Top Right)
  final Color gridBase = Colors.indigo;
  final Color gridOdd = Colors.indigo[300]!;

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
      // Reset sort list to "Wrong" state
      sortColors = [Colors.teal[100]!, Colors.teal[900]!, Colors.teal[500]!];
    });

    // Step 0: SORT INTRO (0s - 1.5s)
    _loopTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // Step 1: PERFORM SORT (1.5s)
      setState(() {
        step = 1;
        // Swap items 1 and 2 visually
        final temp = sortColors[1];
        sortColors[1] = sortColors[2];
        sortColors[2] = temp;
      });

      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;

        // Step 2: SORT SUCCESS (2.5s)
        setState(() => step = 2);

        Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;

          // Step 3: SWITCH TO GRID (3.5s)
          setState(() => step = 3);

          Timer(const Duration(milliseconds: 1500), () {
            if (!mounted) return;

            // Step 4: SELECT ODD TILE (5.0s)
            setState(() => step = 4);

            Timer(const Duration(milliseconds: 800), () {
              if (!mounted) return;

              // Step 5: GRID SUCCESS (5.8s)
              setState(() => step = 5);

              // RESTART (7.5s)
              Timer(const Duration(milliseconds: 1500), _startDemoLoop);
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSortPhase = step < 3;

    return Container(
      width: 280,
      height: 320,
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
        children: [
          // 1. Header (Switches based on phase)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(isSortPhase),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: isSortPhase ? Colors.teal[50] : Colors.indigo[50],
                  borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                isSortPhase ? "Sort: Light ➜ Dark" : "Find the ODD Color",
                style: TextStyle(
                    color: isSortPhase ? Colors.teal[800] : Colors.indigo[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Content Area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: isSortPhase ? _buildSortDemo() : _buildGridDemo(),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Feedback Badge
          SizedBox(
            height: 30,
            child: AnimatedOpacity(
              opacity: (step == 2 || step == 5) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                child: const Text("PERFECT!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SORT UI ---
  Widget _buildSortDemo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < sortColors.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutBack,
            height: 45,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: sortColors[i],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0,2))]
            ),
            child: Row(
              children: [
                const Spacer(),
                Container(
                  width: 40,
                  height: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))
                  ),
                  child: const Icon(Icons.drag_handle, color: Colors.white70, size: 20),
                )
              ],
            ),
          ),
      ],
    );
  }

  // --- GRID UI ---
  Widget _buildGridDemo() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: List.generate(4, (index) {
          // Odd one is Index 1 (Top Right)
          bool isOdd = index == 1;
          bool isSelected = (step >= 4) && isOdd;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isOdd ? gridOdd : gridBase,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: Colors.white, width: 4) : null,
              boxShadow: isSelected ? [const BoxShadow(color: Colors.black26, blurRadius: 8)] : null,
            ),
            child: isSelected && step == 5
                ? const Center(child: Icon(Icons.check, color: Colors.white, size: 32))
                : null,
          );
        }),
      ),
    );
  }
}