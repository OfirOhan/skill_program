// lib/roleplay_game.dart
import 'dart:async';
import 'package:flutter/material.dart';

class RoleplayGame extends StatefulWidget {
  const RoleplayGame({Key? key}) : super(key: key);

  @override
  _RoleplayGameState createState() => _RoleplayGameState();
}

class _RoleplayGameState extends State<RoleplayGame> {
  late List<ScenarioItem> scenarios;
  int index = 0;
  bool isGameOver = false;

  // Timer
  Timer? _gameTimer;
  int remainingSeconds = 40; // 40s total for 2-3 scenarios

  // Metrics
  int scoreEmpathy = 0;
  int scoreDiplomacy = 0; // Persuasion/Negotiation
  int scoreLeadership = 0; // Instruction/Team
  int scoreAwareness = 0; // Cultural/Social
  int totalAnswered = 0;

  Color? feedbackColor;
  String? feedbackText;

  @override
  void initState() {
    super.initState();
    scenarios = _generateScenarios();
    _startTimer();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        _finishGame();
      }
    });
  }

  void _finishGame() {
    _gameTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _onOptionSelected(int optionIndex) {
    if (isGameOver || feedbackColor != null) return;

    final scenario = scenarios[index];
    final choice = scenario.options[optionIndex];

    // Accumulate scores based on the choice's attributes
    // 1.0 = Perfect, 0.5 = Okay, -0.5 = Bad
    if (choice.type == ResponseType.optimal) {
      scoreEmpathy += 2;
      scoreDiplomacy += 2;
      scoreLeadership += 2;
      scoreAwareness += 2;
      _showFeedback(true, "Great Choice!");
    } else if (choice.type == ResponseType.subOptimal) {
      scoreEmpathy += 1;
      scoreDiplomacy += 1; // Partial credit
      _showFeedback(true, "Okay, but could be better.");
    } else {
      // Bad choice (Aggressive or Passive)
      _showFeedback(false, "Too Aggressive/Passive");
    }

    totalAnswered++;
  }

  void _showFeedback(bool positive, String text) {
    setState(() {
      feedbackColor = positive ? Colors.green : Colors.orange;
      feedbackText = text;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        feedbackColor = null;
        index++;
      });

      if (index >= scenarios.length) {
        _finishGame();
      }
    });
  }

  // --- GRADING LOGIC ---
  Map<String, double> grade() {
    // Normalize scores (Max possible per question is approx 2)
    // If we have 3 questions, max score is 6.
    double maxScore = (scenarios.length * 2).toDouble();
    if (maxScore == 0) maxScore = 1;

    double empathyScore = (scoreEmpathy / maxScore).clamp(0.0, 1.0);
    double leadershipScore = (scoreLeadership / maxScore).clamp(0.0, 1.0);

    return {
      "Empathy Accuracy": empathyScore,
      "Active Listening": empathyScore * 0.9,
      "Social Awareness": (scoreAwareness / maxScore).clamp(0.0, 1.0),
      "Cultural Sensitivity": (scoreAwareness / maxScore).clamp(0.0, 1.0),

      "Persuasion Ability": (scoreDiplomacy / maxScore).clamp(0.0, 1.0),
      "Negotiation Ability": (scoreDiplomacy / maxScore).clamp(0.0, 1.0),
      "Conflict Resolution": (scoreDiplomacy / maxScore).clamp(0.0, 1.0),

      "Team Coordination": leadershipScore,
      "Instruction Ability": leadershipScore,
      "Public Speaking": leadershipScore * 0.8,
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
              const Icon(Icons.people, color: Colors.purpleAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Social Snap Done!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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

    final scenario = scenarios[index];

    return Scaffold(
      appBar: AppBar(
        title: Text("13. Social Snap ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- CHAT AREA ---
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, size: 40, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 10),
                      // Context
                      Text(scenario.context, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 15),
                      // The Message
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0,2))]
                        ),
                        child: Text(
                          scenario.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- RESPONSE OPTIONS ---
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text("Choose the best response:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...List.generate(scenario.options.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _onOptionSelected(i),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[50],
                                  foregroundColor: Colors.indigo[900],
                                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0
                              ),
                              child: Text(
                                scenario.options[i].text,
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Feedback Overlay
          if (feedbackColor != null)
            Container(
              color: feedbackColor!.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feedbackColor == Colors.green ? Icons.check_circle : Icons.warning, color: Colors.white, size: 80),
                    const SizedBox(height: 20),
                    Text(feedbackText!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- DATA MODELS ---

enum ResponseType { optimal, subOptimal, bad }

class ScenarioOption {
  final String text;
  final ResponseType type;
  ScenarioOption(this.text, this.type);
}

class ScenarioItem {
  final String context;
  final String message;
  final List<ScenarioOption> options;
  ScenarioItem(this.context, this.message, this.options);
}

// --- SCENARIO GENERATOR ---
List<ScenarioItem> _generateScenarios() {
  return [
    // Scenario 1: Team Conflict
    ScenarioItem(
        "Your teammate missed a deadline, delaying the project.",
        "I'm so sorry I missed the deadline! I had a family emergency.",
        [
          ScenarioOption(
              "That's unprofessional. You should have told me sooner.",
              ResponseType.bad // Aggressive
          ),
          ScenarioOption(
              "It's okay, don't worry about it.",
              ResponseType.subOptimal // Too Passive (ignores project impact)
          ),
          ScenarioOption(
              "I hope everything is okay. Let's check the schedule and see how we can catch up.",
              ResponseType.optimal // Empathetic + Problem Solving
          ),
        ]
    ),

    // Scenario 2: Negotiation / Disagreement
    ScenarioItem(
        "A client wants a feature that is impossible within the budget.",
        "We really need this AI feature added, or we can't sign the contract.",
        [
          ScenarioOption(
              "We can't do that. It's too expensive.",
              ResponseType.bad // Blunt/Dismissive
          ),
          ScenarioOption(
              "I understand this is important. We can add it if we extend the budget, or we can look at a simpler alternative?",
              ResponseType.optimal // Negotiation/Option generation
          ),
          ScenarioOption(
              "Okay, we will try to squeeze it in.",
              ResponseType.subOptimal // Passive/Over-promising (Dangerous)
          ),
        ]
    ),

    // Scenario 3: Cultural/Social Awareness
    ScenarioItem(
        "New international colleague looks confused during a meeting.",
        "(Silence in the meeting room)",
        [
          ScenarioOption(
              "Do you understand? Yes or No?",
              ResponseType.bad // Condescending
          ),
          ScenarioOption(
              "Let's pause. I want to make sure we are all aligned. Does anyone have questions?",
              ResponseType.optimal // Inclusive Leadership
          ),
          ScenarioOption(
              "Continue the meeting and email notes later.",
              ResponseType.subOptimal // Avoidant
          ),
        ]
    ),
  ];
}