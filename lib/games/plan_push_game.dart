// lib/plan_push_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlanPushGame extends StatefulWidget {
  const PlanPushGame({Key? key}) : super(key: key);

  @override
  _PlanPushGameState createState() => _PlanPushGameState();
}

class _PlanPushGameState extends State<PlanPushGame> {
  // Game State
  int level = 0;
  bool isGameOver = false;

  // Level Data
  late int workDayHours;
  late List<TaskItem> availableTasks;
  List<TaskItem> scheduledTasks = [];

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 30;

  // Metrics
  int totalScore = 0;
  int maxPossibleScore = 0;
  int perfectDays = 0;
  int overtimeErrors = 0;
  int underTimeErrors = 0;

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRoundTimer() {
    remainingSeconds = 30; // Reset to 30s every round
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _handleTimeout() {
    _roundTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Day ended automatically!"), duration: Duration(milliseconds: 800))
    );
    // Auto-submit whatever they have selected
    _submitDay();
  }

  void _startLevel() {
    if (level >= 3) {
      _finishGame();
      return;
    }

    setState(() {
      scheduledTasks = [];
      // Difficulty scaling
      if (level == 0) {
        workDayHours = 8;
        availableTasks = _generateTasks(5, 8);
      } else if (level == 1) {
        workDayHours = 10;
        availableTasks = _generateTasks(7, 10);
      } else {
        workDayHours = 12;
        availableTasks = _generateTasks(8, 12, withDistractors: true);
      }

      maxPossibleScore += availableTasks.fold(0, (sum, item) => sum + item.value);
    });

    _startRoundTimer(); // Start new timer for this level
  }

  void _toggleTask(TaskItem task) {
    if (isGameOver) return;
    HapticFeedback.selectionClick();

    setState(() {
      if (scheduledTasks.contains(task)) {
        scheduledTasks.remove(task);
      } else {
        scheduledTasks.add(task);
      }
    });
  }

  void _submitDay() {
    // Stop timer immediately to prevent double-firing
    _roundTimer?.cancel();

    int usedTime = scheduledTasks.fold(0, (sum, item) => sum + item.duration);
    int score = scheduledTasks.fold(0, (sum, item) => sum + item.value);

    if (usedTime > workDayHours) {
      overtimeErrors++;
      score = (score * 0.5).toInt();
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OVERTIME! Penalty applied."), backgroundColor: Colors.red, duration: Duration(milliseconds: 500))
        );
      }
    } else if (workDayHours - usedTime > 2) {
      underTimeErrors++;
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Time wasted!"), backgroundColor: Colors.orange, duration: Duration(milliseconds: 500))
        );
      }
    } else {
      perfectDays++;
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Schedule Optimized!"), backgroundColor: Colors.green, duration: Duration(milliseconds: 500))
        );
      }
    }

    // Delay slightly to show snackbar before next level refresh
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          totalScore += score;
          level++;
          _startLevel();
        });
      }
    });
  }

  Map<String, double> grade() {
    double timeMgmt = 1.0 - ((overtimeErrors + underTimeErrors) / 3.0);
    double rawRatio = maxPossibleScore == 0 ? 0 : totalScore / (maxPossibleScore * 0.6);
    double prioritization = (rawRatio - 0.5) * 2.0;

    return {
      "Planning & Prioritization": prioritization.clamp(0.0, 1.0),
      "Task Management": timeMgmt.clamp(0.0, 1.0),
      "Resource Allocation": timeMgmt,
      "Long-Term Strategy Building": (prioritization * 0.8 + timeMgmt * 0.2).clamp(0.0, 1.0),
      "Time Estimation Skill": (1.0 - (overtimeErrors / 3.0)).clamp(0.0, 1.0),
      "Process Optimization": (perfectDays / 3.0).clamp(0.0, 1.0),
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
              const Icon(Icons.calendar_month, color: Colors.purpleAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Schedule Locked!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Value Generated: $totalScore", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                   HapticFeedback.lightImpact();
                   Navigator.of(context).pop(grade());
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
              )
            ],
          ),
        ),
      );
    }

    int usedHours = scheduledTasks.fold(0, (sum, t) => sum + t.duration);
    double progress = workDayHours == 0 ? 0 : (usedHours / workDayHours).clamp(0.0, 1.0);
    bool isOvertime = usedHours > workDayHours;

    return Scaffold(
      appBar: AppBar(
        title: Text("14. Plan Push ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () {
           HapticFeedback.lightImpact();
           Navigator.of(context).pop(null);
        }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
      ),
      body: Column(
        children: [
          // --- HUD ---
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.indigo[50],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Day ${level + 1}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("$usedHours / $workDayHours Hours", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOvertime ? Colors.red : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: isOvertime ? 1.0 : progress,
                    minHeight: 15,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation(isOvertime ? Colors.red : (progress == 1.0 ? Colors.green : Colors.indigo)),
                  ),
                ),
                const SizedBox(height: 5),
                if (isOvertime)
                  const Text("OVERTIME! Remove tasks!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                else
                  const Text("Fill the day with high value tasks.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          // --- TASK LIST ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: availableTasks.length,
              itemBuilder: (context, i) {
                final task = availableTasks[i];
                final isSelected = scheduledTasks.contains(task);
                return Card(
                  elevation: isSelected ? 8 : 2,
                  color: isSelected ? Colors.indigo[50] : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected ? const BorderSide(color: Colors.indigo, width: 2) : BorderSide.none
                  ),
                  child: ListTile(
                    onTap: () => _toggleTask(task),
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? Colors.indigo : Colors.grey[200],
                      child: Icon(Icons.access_time, color: isSelected ? Colors.white : Colors.black54),
                    ),
                    title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${task.duration} Hours"),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text("\$${task.value}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- SUBMIT BUTTON ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submitDay,
                style: ElevatedButton.styleFrom(
                    backgroundColor: isOvertime ? Colors.grey : Colors.indigo,
                    foregroundColor: Colors.white
                ),
                child: const Text("LOCK SCHEDULE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class TaskItem {
  final String name;
  final int duration;
  final int value;
  TaskItem(this.name, this.duration, this.value);
}

List<TaskItem> _generateTasks(int count, int maxHours, {bool withDistractors = false}) {
  List<TaskItem> tasks = [];
  final rand = Random();
  List<String> verbs = ["Write", "Review", "Fix", "Call", "Plan", "Design", "Code", "Meet"];
  List<String> nouns = ["Report", "Client", "Bug", "Team", "Strategy", "UI", "API", "Budget"];

  for (int i = 0; i < count; i++) {
    int d = rand.nextInt(4) + 1;
    int v = (d * 10) + rand.nextInt(20) - 5;

    if (withDistractors && i % 3 == 0) {
      if (rand.nextBool()) {
        d += 2;
        v -= 10;
      } else {
        d = max(1, d - 1);
        v += 20;
      }
    }

    tasks.add(TaskItem(
        "${verbs[rand.nextInt(verbs.length)]} ${nouns[rand.nextInt(nouns.length)]}",
        d,
        v
    ));
  }
  return tasks;
}