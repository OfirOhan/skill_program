// lib/demos/plan_push_demo.dart
import 'dart:async';
import 'package:flutter/material.dart';

class PlanPushDemoWidget extends StatefulWidget {
  const PlanPushDemoWidget({Key? key}) : super(key: key);

  @override
  _PlanPushDemoWidgetState createState() => _PlanPushDemoWidgetState();
}

class _PlanPushDemoWidgetState extends State<PlanPushDemoWidget> {
  // Demo State
  int step = 0;
  Timer? _loopTimer;

  // Demo Data (Sum of first two = 8 Hours. Third one causes Overtime.)
  final int maxHours = 8;
  final List<Map<String, dynamic>> demoTasks = [
    {"name": "Deep Work", "hours": 4, "value": 100}, // Select
    {"name": "Team Sync", "hours": 4, "value": 80},  // Select
    {"name": "Busy Work", "hours": 3, "value": 30},  // SKIP this one!
  ];

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
    setState(() => step = 0);

    // Step 0: IDLE (0s - 1.0s)
    _loopTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      // Step 1: SELECT TASK 1 (1.0s) -> 4/8 Hours
      setState(() => step = 1);

      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;

        // Step 2: SELECT TASK 2 (2.0s) -> 8/8 Hours (PERFECT)
        setState(() => step = 2);

        Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;

          // Step 3: SUCCESS (3.0s)
          // We DO NOT select Task 3. We go straight to success.
          setState(() => step = 3);

          // RESTART (5.0s)
          Timer(const Duration(milliseconds: 2000), _startDemoLoop);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats based on selection logic
    int usedHours = 0;

    // Logic: If step >= 1, Task 0 is selected. If step >= 2, Task 1 is selected.
    // Task 2 is NEVER selected in this successful run.
    if (step >= 1) usedHours += (demoTasks[0]['hours'] as int);
    if (step >= 2) usedHours += (demoTasks[1]['hours'] as int);

    // Progress Bar Logic
    double progress = (usedHours / maxHours).clamp(0.0, 1.0);
    bool isPerfect = usedHours == maxHours;
    Color barColor = isPerfect ? Colors.green : Colors.indigo;

    return Container(
      width: 300,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Fill the Day", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              Text("$usedHours / $maxHours Hrs", style: TextStyle(color: barColor, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Task List
          Column(
            children: List.generate(demoTasks.length, (i) {
              final task = demoTasks[i];

              // Selection Logic for Visuals
              bool isSelected = false;
              if (i == 0 && step >= 1) isSelected = true;
              if (i == 1 && step >= 2) isSelected = true;
              // i == 2 is never selected

              // Visuals
              Color bg = isSelected ? Colors.indigo[50]! : Colors.white;
              Color border = isSelected ? Colors.indigo : Colors.grey[200]!;
              Color iconColor = isSelected ? Colors.indigo : Colors.grey;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                        : null
                ),
                child: Row(
                  children: [
                    Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: iconColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("${task['hours']} Hours", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                      child: Text("\$${task['value']}", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
              );
            }),
          ),

          // 3. Success Badge
          SizedBox(
            height: 30,
            child: step == 3
                ? AnimatedOpacity(
              opacity: step == 3 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                child: const Text("OPTIMIZED!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
                : null,
          )
        ],
      ),
    );
  }
}