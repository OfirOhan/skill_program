// lib/plan_push_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

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
  Timer? _gameTimer;
  int remainingSeconds = 30; // 30s to plan 3 days

  // Metrics
  int totalScore = 0;
  int maxPossibleScore = 0; // To calculate efficiency
  int perfectDays = 0;
  int overtimeErrors = 0; // Going over limit
  int underTimeErrors = 0; // Leaving too much gap

  @override
  void initState() {
    super.initState();
    _startLevel();
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

  void _startLevel() {
    if (level >= 3) {
      _finishGame();
      return;
    }

    setState(() {
      scheduledTasks = [];
      // Difficulty:
      // Lvl 0: 8 hours, Simple values
      // Lvl 1: 10 hours, Tight fit
      // Lvl 2: 12 hours, Distractors (High duration, low value)
      if (level == 0) {
        workDayHours = 8;
        availableTasks = _generateTasks(5, 8); // 5 tasks, easy fit
      } else if (level == 1) {
        workDayHours = 10;
        availableTasks = _generateTasks(7, 10); // More options
      } else {
        workDayHours = 12;
        availableTasks = _generateTasks(8, 12, withDistractors: true);
      }

      // Calculate optimal score for grading context (Approximate greedy)
      // (Real max score calculation is Knapsack problem, overkill for this,
      // so we just track raw accumulation vs potential).
      maxPossibleScore += availableTasks.fold(0, (sum, item) => sum + item.value);
    });
  }

  void _toggleTask(TaskItem task) {
    if (isGameOver) return;

    setState(() {
      if (scheduledTasks.contains(task)) {
        scheduledTasks.remove(task);
      } else {
        scheduledTasks.add(task);
      }
    });
  }

  void _submitDay() {
    int usedTime = scheduledTasks.fold(0, (sum, item) => sum + item.duration);
    int score = scheduledTasks.fold(0, (sum, item) => sum + item.value);

    if (usedTime > workDayHours) {
      // Overtime Penalty!
      overtimeErrors++;
      score = (score * 0.5).toInt(); // Massive penalty for burnout
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OVERTIME! Penalty applied."), backgroundColor: Colors.red, duration: Duration(milliseconds: 500))
      );
    } else if (workDayHours - usedTime > 2) {
      // Undertime (Inefficient)
      underTimeErrors++;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time wasted!"), backgroundColor: Colors.orange, duration: Duration(milliseconds: 500))
      );
    } else {
      // Perfect or near perfect
      perfectDays++;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Schedule Optimized!"), backgroundColor: Colors.green, duration: Duration(milliseconds: 500))
      );
    }

    setState(() {
      totalScore += score;
      level++;
      _startLevel();
    });
  }

  Map<String, double> grade() {
    // Normalize metrics
    // Efficiency: Did they fill the bar without breaking it?
    double timeMgmt = 1.0 - ((overtimeErrors + underTimeErrors) / 3.0);

    // Prioritization: Did they pick high value items?
    // A random pick gets ~50% of value. A good pick gets ~80-90%.
    // We normalize assuming 50% is 0.0 score.
    double rawRatio = maxPossibleScore == 0 ? 0 : totalScore / (maxPossibleScore * 0.6); // Approximate denominator
    double prioritization = (rawRatio - 0.5) * 2.0;

    return {
      "Planning & Prioritization": prioritization.clamp(0.0, 1.0),
      "Task Management": timeMgmt.clamp(0.0, 1.0),
      "Resource Allocation": timeMgmt, // Same core skill
      "Long-Term Strategy Building": (prioritization * 0.8 + timeMgmt * 0.2).clamp(0.0, 1.0),
      "Time Estimation Skill": (1.0 - (overtimeErrors / 3.0)).clamp(0.0, 1.0), // Did they avoid going over?
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
                onPressed: () => Navigator.of(context).pop(grade()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
              )
            ],
          ),
        ),
      );
    }

    int usedHours = scheduledTasks.fold(0, (sum, t) => sum + t.duration);
    double progress = (usedHours / workDayHours).clamp(0.0, 1.0);
    bool isOvertime = usedHours > workDayHours;

    return Scaffold(
      appBar: AppBar(
        title: Text("14. Plan Push ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))],
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
                // Capacity Bar
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

// --- DATA ---
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
    int d = rand.nextInt(4) + 1; // 1-4 hours
    // Value logic: Roughly correlated to time, but with variance
    // Normal: $10 per hour +/- random
    int v = (d * 10) + rand.nextInt(20) - 5;

    // Add "Distractors" (High Time, Low Value) or "Gems" (Low Time, High Value)
    if (withDistractors && i % 3 == 0) {
      if (rand.nextBool()) {
        // Distractor (Inefficient)
        d += 2;
        v -= 10;
      } else {
        // Gem (Efficient)
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