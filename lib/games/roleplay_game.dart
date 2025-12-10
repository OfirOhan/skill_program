// lib/roleplay_game.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoleplayGame extends StatefulWidget {
  const RoleplayGame({Key? key}) : super(key: key);

  @override
  _RoleplayGameState createState() => _RoleplayGameState();
}

class _RoleplayGameState extends State<RoleplayGame> {
  late List<SocialCue> cues;
  int index = 0;
  bool isGameOver = false;

  // Timer
  Timer? _roundTimer;
  int remainingSeconds = 10; // Fast! Instinct reaction.

  // Metrics
  int correctCount = 0;
  int eqScore = 0;       // Emotional Quotient points
  int sqScore = 0;       // Social Quotient points (Power dynamics)

  Color? feedbackColor;
  String? feedbackText;

  @override
  void initState() {
    super.initState();
    cues = _generateCues();
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (index >= cues.length) {
      _finishGame();
      return;
    }

    setState(() {
      remainingSeconds = 12;
      feedbackColor = null;
      feedbackText = null;
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
    _showFeedback(false, "Too Slow!");
  }

  void _finishGame() {
    _roundTimer?.cancel();
    setState(() => isGameOver = true);
  }

  void _onOptionSelected(int optionIndex) {
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();

    final cue = cues[index];
    final choice = cue.options[optionIndex];

    if (choice.isCorrect) {
      correctCount++;
      // Weight scoring based on difficulty type
      if (cue.type == CueType.subtext) eqScore += 2;
      if (cue.type == CueType.cultural) sqScore += 2;
      HapticFeedback.mediumImpact();
      _showFeedback(true, "Spot On.");
    } else {
      HapticFeedback.heavyImpact();
      _showFeedback(false, "Misread.");
    }
  }

  void _showFeedback(bool positive, String text) {
    setState(() {
      feedbackColor = positive ? Colors.green : Colors.red;
      feedbackText = text;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        index++;
      });
      _startRound();
    });
  }

  Map<String, double> grade() {
    double accuracy = cues.isEmpty ? 0.0 : correctCount / cues.length;

    return {
      "Empathy Accuracy": accuracy, // Reading emotions
      "Social Awareness": accuracy * 0.9, // Understanding dynamics
      "Cultural Sensitivity": (sqScore / 5.0).clamp(0.0, 1.0), // Indirectness check
      "Active Listening": accuracy, // Context attention
      "Conflict Resolution": accuracy * 0.8, // Identifying root cause
      "Persuasion Ability": accuracy * 0.7,
      "Team Coordination": accuracy * 0.8,
      "Negotiation Ability": accuracy * 0.8,
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
              const Icon(Icons.visibility, color: Colors.purpleAccent, size: 80),
              const SizedBox(height: 20),
              const Text("Subtext Analyzed", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Accuracy: $correctCount / ${cues.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
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

    final cue = cues[index];

    return Scaffold(
      appBar: AppBar(
        title: Text("13. Read the Room ($remainingSeconds)"),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () { 
             HapticFeedback.lightImpact();
             Navigator.of(context).pop(null);
          }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // 1. THE QUOTE (Big)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.format_quote, color: Colors.grey, size: 40),
                      Text(
                        cue.quote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. THE CONTEXT (The Key)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo[100]!)
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                        children: [
                          const TextSpan(text: "CONTEXT: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          TextSpan(text: cue.context),
                        ]
                    ),
                  ),
                ),

                const Spacer(),
                const Text("What is the TRUE intent?", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // 3. OPTIONS
                ...List.generate(cue.options.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _onOptionSelected(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          cue.options[i].text,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),

          if (feedbackColor != null)
            Container(
              color: feedbackColor!.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feedbackColor == Colors.green ? Icons.check_circle : Icons.warning, color: Colors.white, size: 80),
                    const SizedBox(height: 20),
                    Text(feedbackText!, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
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

enum CueType { subtext, power, cultural }

class CueOption {
  final String text;
  final bool isCorrect;
  CueOption(this.text, this.isCorrect);
}

class SocialCue {
  final CueType type;
  final String quote;
  final String context;
  final List<CueOption> options;
  SocialCue(this.type, this.quote, this.context, this.options);
}

// --- HARD CONTENT GENERATOR ---
List<SocialCue> _generateCues() {
  return [
    // 1. Passive Aggression (Workplace)
    SocialCue(
        CueType.subtext,
        "I guess that's one way to do it.",
        "A senior colleague says this after you present your new strategy.",
        [
          CueOption("Endorsement", false),
          CueOption("Confusion", false),
          CueOption("Disapproval", true), // Correct: "I guess" + "one way" = subtle insult
          CueOption("Indifference", false),
        ]
    ),

    // 2. The Double Bind (Relationship)
    SocialCue(
        CueType.subtext,
        "Do whatever you want.",
        "Partner says this abruptly and turns away during an argument.",
        [
          CueOption("Permission", false),
          CueOption("A Test / Trap", true), // Correct: They want you to choose THEM, not the thing
          CueOption("Fatigue", false),
          CueOption("Agreement", false),
        ]
    ),

    // 3. Power Dynamics (Boss)
    SocialCue(
        CueType.power,
        "I'm sure you did your best.",
        "Your perfectionist boss says this after reviewing a project that missed targets.",
        [
          CueOption("Consolation", false),
          CueOption("Condescension", true), // Correct: "Your best wasn't good enough"
          CueOption("Gratitude", false),
          CueOption("Pride", false),
        ]
    ),

    // 4. Damage Control / De-escalation (REPLACED)
    // Logic: Public arguments are bad. "Offline" means "Stop talking now."
    SocialCue(
        CueType.power,
        "Let's take this offline.",
        "A manager interrupts you during a heated debate in a team meeting.",
        [
          CueOption("Schedule a later meeting", false), // Literal interpretation (Naive)
          CueOption("Stop the public argument", true), // Correct: Immediate de-escalation
          CueOption("They are interested", false),
          CueOption("Agreement", false),
        ]
    ),

    // 5. Deflection (Social)
    SocialCue(
        CueType.subtext,
        "Wow, you're so brave for wearing that.",
        "An acquaintance says this at a formal dinner.",
        [
          CueOption("Compliment", false),
          CueOption("Insult / Judgment", true), // Correct: "Brave" implies it breaks norms negatively
          CueOption("Envy", false),
          CueOption("Support", false),
        ]
    ),
  ];
}