// lib/roleplay_game.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../grading/roleplay_grading.dart';

class RoleplayGame extends StatefulWidget {
  const RoleplayGame({Key? key}) : super(key: key);

  @override
  _RoleplayGameState createState() => _RoleplayGameState();
}

class _RoleplayGameState extends State<RoleplayGame> {
  late List<SocialCue> cues;
  int index = 0;
  bool isGameOver = false;

  static const int timePerRound = 25;
  static const int timeoutPenaltyMs = 25000;

  Timer? _roundTimer;
  int remainingSeconds = timePerRound;

  int correctCount = 0;
  Color? feedbackColor;
  String? feedbackText;

  int startMs = 0;
  List<int> reactionTimes = [];
  List<bool> results = [];

  @override
  void initState() {
    super.initState();
    cues = _generateCues();
    _shuffleOptions(); // Randomize answer positions
    _startRound();
  }

  // Shuffle options to prevent pattern recognition
  void _shuffleOptions() {
    for (var cue in cues) {
      cue.options.shuffle();
    }
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
      remainingSeconds = timePerRound;
      startMs = DateTime.now().millisecondsSinceEpoch;
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
    if (isGameOver || feedbackColor != null) return;
    _roundTimer?.cancel();

    reactionTimes.add(timeoutPenaltyMs);
    results.add(false);

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

    final rt = DateTime.now().millisecondsSinceEpoch - startMs;
    reactionTimes.add(rt);

    final isCorrect = choice.isCorrect;
    results.add(isCorrect);

    if (isCorrect) {
      correctCount++;
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

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        index++;
      });
      _startRound();
    });
  }

  // --- WORD COUNT HELPERS ---

  int _countWords(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int _contextWordCount(SocialCue cue) => _countWords(cue.context);

  int _quoteWordCount(SocialCue cue) => _countWords(cue.quote);

  /// Total words across all answer options for this cue.
  /// (Grading can give this less weight than context/quote if desired.)
  int _optionsWordCount(SocialCue cue) {
    int sum = 0;
    for (final opt in cue.options) {
      sum += _countWords(opt.text);
    }
    return sum;
  }

  Map<String, double> grade() {
    final List<bool> isPragmatic =
    cues.map((c) => c.type == CueType.pragmatic).toList();
    final List<bool> isSocialContext =
    cues.map((c) => c.type == CueType.socialContext).toList();

    // Per-cue word counts (context / quote / options)
    final List<int> contextWordCounts =
    cues.map(_contextWordCount).toList();
    final List<int> quoteWordCounts =
    cues.map(_quoteWordCount).toList();
    final List<int> optionsWordCounts =
    cues.map(_optionsWordCount).toList();

    return RoleplayGrading.grade(
      totalCues: cues.length,
      results: results,
      reactionTimes: reactionTimes,
      isPragmatic: isPragmatic,
      isSocialContext: isSocialContext,
      contextWordCounts: contextWordCounts,
      quoteWordCounts: quoteWordCounts,
      optionsWordCounts: optionsWordCounts,
    );
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
              const Icon(Icons.visibility,
                  color: Colors.purpleAccent, size: 80),
              const SizedBox(height: 20),
              const Text(
                "Social Cues Analyzed",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Accuracy: $correctCount / ${cues.length}",
                style: const TextStyle(
                    color: Colors.white70, fontSize: 18),
              ),
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
        title: const Text("Read the Room",
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: remainingSeconds <= 5
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$remainingSeconds s",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: remainingSeconds <= 5
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF5C6BC0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Progress indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${index + 1} / ${cues.length}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF78909C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // CONTEXT BOX
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8EAF6), Color(0xFFF3E5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: Color(0xFF5C6BC0),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Situation",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5C6BC0),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        cue.context,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // THE QUOTE
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFE0E0E0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        cue.hasVisual
                            ? Icons.emoji_emotions_outlined
                            : Icons.format_quote,
                        color: const Color(0xFF9E9E9E),
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        cue.quote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                          height: 1.4,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Text(
                  cue.type == CueType.pragmatic
                      ? "What do they really mean?"
                      : "What's the real signal here?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // OPTIONS
                ...List.generate(cue.options.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onOptionSelected(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color:
                                Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            cue.options[i].text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF424242),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
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
                    Icon(
                      feedbackColor == Colors.green
                          ? Icons.check_circle
                          : Icons.warning,
                      color: Colors.white,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      feedbackText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

enum CueType {
  pragmatic, // Linguistic: what they MEAN vs what they SAY
  socialContext, // Situational: WHO/WHERE/WHEN determines meaning
}

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
  final bool hasVisual; // For future: indicates if this uses emoji/images

  SocialCue(
      this.type,
      this.quote,
      this.context,
      this.options, {
        this.hasVisual = false,
      });
}

// --- CONTENT GENERATOR ---
/// Cues are ordered to create a difficulty ramp:
/// 1–4: Pragmatics (easiest → hardest)
/// 5–8: Social Context (easiest → hardest)
List<SocialCue> _generateCues() {
  return [
    // ================= PRAGMATIC CUES (1–4) =================

    // 1. Mild sarcasm about lateness (EASY)
    SocialCue(
      CueType.pragmatic,
      "Thanks for finally replying.",
      "A close friend messages you after you answered them many hours late.",
      [
        CueOption(
          "They're a bit annoyed but also glad you're responding now.",
          true,
        ),
        CueOption(
          "They're genuinely relieved and unbothered by the delay.",
          false,
        ),
        CueOption(
          "They're seriously hurt and reconsidering the friendship.",
          false,
        ),
      ],
      hasVisual: false,
    ),

    // 2. "Interesting choice" about appearance (EASY–MEDIUM)
    SocialCue(
      CueType.pragmatic,
      "That's… an interesting choice.",
      "You show a new outfit to a friend who pauses before saying this.",
      [
        CueOption(
          "They think it's odd or risky and avoid calling it bad directly.",
          true,
        ),
        CueOption(
          "They're genuinely intrigued and trying to form an opinion.",
          false,
        ),
        CueOption(
          "They think it's bold in a good way but wouldn't wear it themselves.",
          false,
        ),
      ],
      hasVisual: false,
    ),

    // 3. Reluctant agreement (MEDIUM)
    SocialCue(
      CueType.pragmatic,
      "I mean… if you really want to.",
      "You ask a friend if they're okay with you joining plans they made with others.",
      [
        CueOption(
          "They feel pressured to say yes and would actually prefer you not join.",
          true,
        ),
        CueOption(
          "They're fine with it but want to make sure you're genuinely interested.",
          false,
        ),
        CueOption(
          "They genuinely don't mind either way and want you to decide for yourself.",
          false,
        ),
      ],
      hasVisual: false,
    ),

    // 4. Delegating a hard call (HARDEST PRAGMATIC)
    SocialCue(
      CueType.pragmatic,
      "Do what you think is best.",
      "You ask your manager whether to take a risky shortcut on an important project.",
      [
        CueOption(
          "They're avoiding clear guidance so the outcome rests mostly on you.",
          true,
        ),
        CueOption(
          "They trust your expertise and will fully support whatever you decide.",
          false,
        ),
        CueOption(
          "They want you to think it through more deeply before asking again.",
          false,
        ),
      ],
      hasVisual: false,
    ),

    // ================ SOCIAL CONTEXT CUES (5–8) ================

    // 5. Casual celebration (EASY, positive)
    SocialCue(
      CueType.socialContext,
      "We should grab coffee sometime.",
      "After you help with a tricky task, a coworker smiles and says this.",
      [
        CueOption(
          "They appreciate your help and want a friendly one-on-one to connect.",
          true,
        ),
        CueOption(
          "They're just being polite and don't really plan to follow up.",
          false,
        ),
        CueOption(
          "They want to discuss work concerns in a more private setting.",
          false,
        ),
      ],
      hasVisual: false,
    ),

    // 6. Words vs body language (EASY–MEDIUM)
    SocialCue(
      CueType.socialContext,
      "I'm totally fine with it. 😊",
      "After you change a plan they cared about, your colleague looks tense and avoids eye contact.",
      [
        CueOption(
          "They're not actually okay but don't feel safe saying so directly.",
          true,
        ),
        CueOption(
          "They're fine with the change; the tense look is about something else entirely.",
          false,
        ),
        CueOption(
          "They're adapting to the change and the tension will pass quickly.",
          false,
        ),
      ],
      hasVisual: true,
    ),

    // 7. Stopping conflict in the room (MEDIUM–HARD)
    SocialCue(
      CueType.socialContext,
      "Let's talk after this.",
      "In a team meeting, you challenge your manager's idea. They cut you off and say this.",
      [
        CueOption(
          "They want to stop the clash in front of everyone and handle it privately later.",
          true,
        ),
        CueOption(
          "They're genuinely interested but the meeting isn't the right venue for deep discussion.",
          false,
        ),
        CueOption(
          "They need time to consider your point and want to revisit with fresh perspective.",
          false,
        ),
      ],
      hasVisual: false,
    ),

    // 8. First-draft evaluation vs peers (HARDEST SOCIAL)
    SocialCue(
      CueType.socialContext,
      "For now, this will do.",
      "You show a first draft to your supervisor. Peers just got strong praise on their work.",
      [
        CueOption(
          "They find it acceptable for the moment but expect stronger work or revisions later.",
          true,
        ),
        CueOption(
          "They're being pragmatic about deadlines and think it's good enough to move forward.",
          false,
        ),
        CueOption(
          "Your work is different in scope, so direct comparison to peers isn't relevant here.",
          false,
        ),
      ],
      hasVisual: false,
    ),
  ];
}


