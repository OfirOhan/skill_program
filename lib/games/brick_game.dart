// lib/brick_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- DATA & CONFIG (Preserved) ---

// --- NEW: timing evidence (tracking only) ---
int divergentUsedMs = 0;           // how long they actually brainstormed
int convergentStartMs = 0;         // when decision phase begins
int convergentDecisionMs = -1;     // time-to-pick within decision phase; -1 = no decision

final Set<String> _englishWords = {
  "door", "doorstop", "weapon", "build", "pedestal", "paint", "powder",
  "crush", "pigment", "throw", "window", "art", "sculpture", "support",
  "press", "hold", "paperweight", "display", "wall", "design", "color",
  "decorate", "stack", "heat", "warm", "insulate", "tool", "plant",
  "garden", "planter", "seat", "step", "bench", "anchor", "weight",
  "exercise", "paper", "book", "bookend"
};

final Set<String> _commonIdeas = {
  "doorstop", "paperweight", "build wall", "build", "throw", "weapon", "bookend", "step",
};

final Map<String, String> _keywordToCategory = {
  "door": "practical", "doorstop": "practical", "paper": "practical", "paperweight": "practical",
  "book": "practical", "bookend": "practical", "build": "construction", "wall": "construction",
  "stack": "construction", "paint": "art", "pigment": "art", "powder": "art", "crush": "art",
  "sculpture": "art", "seat": "furniture", "bench": "furniture", "step": "furniture",
  "weapon": "danger", "throw": "danger", "heat": "survival", "warm": "survival",
  "plant": "garden", "planter": "garden", "anchor": "utility", "weight": "utility", "exercise": "utility",
};

// --- HELPERS ---
bool _containsRealWord(String idea) {
  final parts = idea.toLowerCase().split(RegExp(r'[^a-z]+'));
  return parts.any((w) => _englishWords.contains(w));
}

List<String> _extractKeywords(String idea) {
  return idea.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty && _englishWords.contains(w)).toList();
}

String? _detectCategory(String idea) {
  final kws = _extractKeywords(idea);
  for (final k in kws) {
    if (_keywordToCategory.containsKey(k)) return _keywordToCategory[k];
  }
  return null;
}

bool _isCommonIdea(String idea) {
  final lowered = idea.toLowerCase();
  for (final c in _commonIdeas) {
    if (lowered.contains(c)) return true;
  }
  return false;
}

double _elaborationScore(String idea) {
  final kws = _extractKeywords(idea).length;
  return min(kws / 6.0, 1.0);
}

double _originalityForIdea(String idea, Map<String, int> freq) {
  if (!_containsRealWord(idea)) return 0.0;
  if (_isCommonIdea(idea)) return 0.0;
  final kws = _extractKeywords(idea);
  if (kws.isEmpty) return 0.0;
  final primary = kws.first;
  final f = freq[primary] ?? 0;
  if (f <= 1) return 1.0;
  return (1.0 / (f)).clamp(0.0, 1.0);
}

class BrickGame extends StatefulWidget {
  const BrickGame({Key? key}) : super(key: key);

  @override
  _BrickGameState createState() => _BrickGameState();
}

class _BrickGameState extends State<BrickGame> {
  // phases
  bool isDivergentPhase = true;
  bool isGameOver = false;

  // user inputs
  final TextEditingController _textController = TextEditingController();
  List<String> ideas = [];
  List<int> ideaTimestamps = [];
  int ideaCount = 0;

  // convergent
  int selectedOptionIndex = -1;
  bool convergentChosen = false;

  // timers
  Timer? _timer;
  int currentSeconds = 45;
  int divergentDuration = 45;
  int convergentDuration = 10;
  int startTime = 0;

  final Map<String, int> keywordFrequency = {};

  @override
  void initState() {
    super.initState();
    currentSeconds = divergentDuration;
    startTime = DateTime.now().millisecondsSinceEpoch;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        currentSeconds--;
      });

      if (currentSeconds <= 0) {
        if (isDivergentPhase) {
          _switchToConvergent();
        } else {
          _finishGame();
        }
      }
    });
  }

  void _switchToConvergent() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // If user ends early, use actual time spent (not the full 45s)
    divergentUsedMs = now - startTime;

    setState(() {
      isDivergentPhase = false;
      currentSeconds = convergentDuration;
      convergentStartMs = now;
      convergentDecisionMs = -1;
    });
  }

  void _submitIdea() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - startTime;

    setState(() {
      ideas.insert(0, text);
      ideaTimestamps.insert(0, elapsed);
      ideaCount++;
      _textController.clear();

      final kws = _extractKeywords(text);
      if (kws.isNotEmpty) {
        final primary = kws.first;
        keywordFrequency[primary] = (keywordFrequency[primary] ?? 0) + 1;
      }
    });
  }

  void _selectConvergent(int index) {
    if (selectedOptionIndex != -1) return;
    if (index < 0 || index >= ideas.length) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    HapticFeedback.selectionClick();
    setState(() {
      selectedOptionIndex = index;
      convergentChosen = true;

      // Evidence: time-to-commit during the short decision window
      if (convergentStartMs > 0) {
        convergentDecisionMs = (now - convergentStartMs).clamp(0, convergentDuration * 1000);
      }
    });

    Future.delayed(const Duration(milliseconds: 500), _finishGame);
  }

  void _finishGame() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => isGameOver = true);
  }

  void _onSkipPressed() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(calculateScores());
  }

  Map<String, double> calculateScores() {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    bool isValidIdea(String s) => _containsRealWord(s);

    if (ideas.isEmpty) {
      return {
        "Ideation Fluency": 0.0,
        "Divergent Thinking": 0.0,
        "Cognitive Flexibility": 0.0,
        "Planning & Prioritization": 0.0,
        "Decision Under Pressure": 0.0,
      };
    }

    final List<String> validIdeas = ideas.where(isValidIdea).toList();
    final int validCount = validIdeas.length;

    // No valid ideas => no defensible creativity evidence
    if (validCount == 0) {
      return {
        "Ideation Fluency": 0.0,
        "Divergent Thinking": 0.0,
        "Cognitive Flexibility": 0.0,
        "Planning & Prioritization": 0.0,
        "Decision Under Pressure": 0.0,
      };
    }

    // -----------------------------------
    // 1) Ideation Fluency (valid idea rate)
    // -----------------------------------
    // Normalize to "1 valid idea per ~5 seconds" as a reasonable target,
    // derived from the actual time used (no fixed magic 9 count).
    final int usedMs = (divergentUsedMs > 0)
        ? divergentUsedMs.clamp(1, divergentDuration * 1000)
        : (divergentDuration * 1000);

    final double usedSeconds = usedMs / 1000.0;
    final double targetIdeas = usedSeconds / 5.0; // 1 idea / 5s target
    final double ideationFluency = clamp01(validCount / (targetIdeas <= 0 ? 1.0 : targetIdeas));

    // -------------------------------------------
    // 2) Divergent Thinking (originality of ideas)
    // -------------------------------------------
    // Only defensible if there are multiple valid ideas (stability).
    double divergentThinking = 0.0;
    if (validCount >= 2) {
      double sumOrig = 0.0;
      for (final idea in validIdeas) {
        sumOrig += _originalityForIdea(idea, keywordFrequency);
      }
      divergentThinking = clamp01(sumOrig / validCount);
    } else {
      divergentThinking = 0.0;
    }

    // ---------------------------------------------------
    // 3) Cognitive Flexibility (semantic category diversity)
    // ---------------------------------------------------
    // Use normalized Shannon entropy across detected categories (0..1).
    // Requires enough categorized evidence.
    double cognitiveFlexibility = 0.0;
    {
      final Map<String, int> catFreq = {};
      int categorized = 0;

      for (final idea in validIdeas) {
        final cat = _detectCategory(idea);
        if (cat != null) {
          categorized++;
          catFreq[cat] = (catFreq[cat] ?? 0) + 1;
        }
      }

      final int K = _keywordToCategory.values.toSet().length; // max possible categories in your map

      if (categorized >= 2 && catFreq.length >= 2 && K >= 2) {
        double h = 0.0;
        catFreq.forEach((_, c) {
          final double p = c / categorized;
          h += -p * log(p);
        });
        final double hMax = log(K.toDouble());
        cognitiveFlexibility = clamp01(hMax <= 0 ? 0.0 : (h / hMax));
      } else {
        cognitiveFlexibility = 0.0;
      }
    }

    // ----------------------------------------------------
    // 4) Planning & Prioritization (picked best-of-own-ideas)
    // ----------------------------------------------------
    // Evidence only if they actually chose an option.
    // Score = selectedQuality / bestQuality among their valid ideas.
    double planningPrioritization = 0.0;
    double selectedQualityRatio = 0.0;

    double qualityOf(String idea) {
      // objective: originality + elaboration (both derived from typed content)
      final double o = _originalityForIdea(idea, keywordFrequency);
      final double e = _elaborationScore(idea);
      return clamp01(0.65 * o + 0.35 * e);
    }

    if (convergentChosen &&
        selectedOptionIndex >= 0 &&
        selectedOptionIndex < ideas.length &&
        isValidIdea(ideas[selectedOptionIndex])) {
      final String selected = ideas[selectedOptionIndex];

      double best = 0.0;
      for (final v in validIdeas) {
        final q = qualityOf(v);
        if (q > best) best = q;
      }

      final double selQ = qualityOf(selected);

      selectedQualityRatio = (best <= 0.0) ? 0.0 : clamp01(selQ / best);
      planningPrioritization = selectedQualityRatio;
    } else {
      planningPrioritization = 0.0;
      selectedQualityRatio = 0.0;
    }

    // ------------------------------------------
    // 5) Decision Under Pressure (commit quickly)
    // ------------------------------------------
    // Direct evidence: made a decision in the short convergent window,
    // and did so quickly, AND the choice was good (quality ratio).
    double decisionUnderPressure = 0.0;
    if (convergentChosen && convergentDecisionMs >= 0) {
      final double timeScore = clamp01(1.0 - (convergentDecisionMs / (convergentDuration * 1000.0)));
      decisionUnderPressure = clamp01(timeScore * selectedQualityRatio);
    } else {
      decisionUnderPressure = 0.0;
    }

    return {
      "Ideation Fluency": ideationFluency,
      "Divergent Thinking": divergentThinking,
      "Cognitive Flexibility": cognitiveFlexibility,
      "Planning & Prioritization": planningPrioritization,
      "Decision Under Pressure": decisionUnderPressure,
    };
  }



  @override
  Widget build(BuildContext context) {
    // --- UPDATED RESULT SCREEN (White Theme) ---
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 80),
              const SizedBox(height: 20),
              const Text("Sprint Complete!", style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Ideas Generated: $ideaCount", style: const TextStyle(color: Colors.grey, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(calculateScores()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
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
        title: const Text("5. Object Brainstorm"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "${currentSeconds}s",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: currentSeconds <= 5 ? Colors.red : Colors.indigo
                )
              )
            ),
          ),
          TextButton(onPressed: () {
             HapticFeedback.lightImpact();
             Navigator.of(context).pop(null);
          }, child: const Text("SKIP", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isDivergentPhase ? _buildDivergentUI() : _buildConvergentUI(),
      ),
    );
  }

  Widget _buildDivergentUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.withOpacity(0.1))
          ),
          child: const Column(
            children: [
              Text("PHASE 1: BRAINSTORM", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              SizedBox(height: 8),
              Text("List uses for a BRICK", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text("(Quantity over quality)", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                autofocus: true,
                onSubmitted: (_) => _submitIdea(),
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                    hintText: "Type idea here...",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!)
                    ),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!)
                    ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.indigo, width: 2)
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _submitIdea,
              icon: const Icon(Icons.arrow_upward),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(12)
              ),
            )
          ],
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Ideas: $ideaCount", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
            Text("Time: ${currentSeconds}s", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: currentSeconds < 10 ? Colors.red : Colors.indigo)),
          ],
        ),

        const SizedBox(height: 12),

        // List
        Expanded(
          child: ListView.builder(
            itemCount: ideas.length,
            itemBuilder: (context, idx) {
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!)
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo[50],
                    foregroundColor: Colors.indigo,
                    child: Text("${ideaCount - idx}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(ideas[idx], style: const TextStyle(fontSize: 16, color: Colors.black87)),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: _switchToConvergent,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[50],
              foregroundColor: Colors.indigo,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: const Text("DONE BRAINSTORMING", style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildConvergentUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.2))
          ),
          child: const Column(
            children: [
              Text("PHASE 2: DECISION", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              SizedBox(height: 8),
              Text("Pick your BEST idea.", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: ideas.isEmpty
              ? Center(child: Text("No ideas were created.", style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
            itemCount: ideas.length,
            itemBuilder: (context, idx) {
              final idea = ideas[idx];
              final isSelected = selectedOptionIndex == idx;

              return GestureDetector(
                onTap: () => _selectConvergent(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: isSelected ? Colors.green[50] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? Colors.green : Colors.grey[200]!,
                          width: isSelected ? 2 : 1
                      ),
                      boxShadow: [
                        if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isSelected ? Colors.green : Colors.grey[100],
                        foregroundColor: isSelected ? Colors.white : Colors.grey,
                        radius: 16,
                        child: Text("${ideaCount - idx}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(idea, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                      if (isSelected) const Icon(Icons.check_circle, color: Colors.green)
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}