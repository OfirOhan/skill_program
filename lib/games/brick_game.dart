// lib/brick_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- DATA & CONFIG (Preserved) ---

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
  bool isGameOver = false; // Triggers CLEAN results screen

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
          _finishGame(); // Time out triggers Result Screen
        }
      }
    });
  }

  void _switchToConvergent() {
    setState(() {
      isDivergentPhase = false;
      currentSeconds = convergentDuration;
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
    setState(() {
      selectedOptionIndex = index;
      convergentChosen = true;
    });
    Future.delayed(const Duration(milliseconds: 500), _finishGame);
  }

  // --- FINISH LOGIC (Shows Black Results Screen) ---
  void _finishGame() {
    _timer?.cancel();
    setState(() => isGameOver = true);
  }

  // --- SKIP LOGIC (Instantly Exits - NO Results Screen) ---
  void _onSkipPressed() {
    _timer?.cancel();
    // Directly pop with results, bypassing the "Sprint Done" screen
    Navigator.of(context).pop(calculateScores());
  }

  Map<String, double> calculateScores() {
    if (ideas.isEmpty) {
      return {
        "Creativity (Divergent Thinking)": 0.0,
        "Creativity (Convergent Thinking)": convergentChosen ? 0.5 : 0.0,
        "Idea Generation Fluency": 0.0,
        "Design Thinking": 0.0,
        "Improvisation Ability": 0.0,
        "Aesthetic Sensitivity": 0.0,
        "Problem Decomposition (creative version)": 0.0,
      };
    }

    const double idealIdeaCount = 9.0;
    final fluency = (ideaCount / idealIdeaCount).clamp(0.0, 1.0);

    double sumOriginality = 0.0;
    for (final idea in ideas) {
      sumOriginality += _originalityForIdea(idea, keywordFrequency);
    }
    final originality = (sumOriginality / ideaCount).clamp(0.0, 1.0);

    final Set<String> categories = {};
    for (final idea in ideas) {
      if (!_containsRealWord(idea)) continue;
      final cat = _detectCategory(idea);
      if (cat != null) categories.add(cat);
    }
    final flexibility = (categories.length / 4.0).clamp(0.0, 1.0);

    double sumElab = 0.0;
    for (final idea in ideas) sumElab += _elaborationScore(idea);
    final elaboration = (sumElab / ideaCount).clamp(0.0, 1.0);

    final divergentCreativity = (
        fluency * 0.30 +
            originality * 0.30 +
            flexibility * 0.25 +
            elaboration * 0.15
    ).clamp(0.0, 1.0);

    double convergentCreativity = 0.0;
    if (convergentChosen && selectedOptionIndex >= 0 && selectedOptionIndex < ideas.length) {
      final sel = ideas[selectedOptionIndex];
      final selOrig = _originalityForIdea(sel, keywordFrequency);
      final selElab = _elaborationScore(sel);
      final selCat = _detectCategory(sel);
      final isArt = (selCat == 'art') ? 1.0 : 0.0;
      convergentCreativity = (selOrig * 0.6 + selElab * 0.3 + isArt * 0.1).clamp(0.0, 1.0);
    }

    final ideaRateScore = (ideaCount / idealIdeaCount).clamp(0.0, 1.0);

    int designCount = 0;
    for (final idea in ideas) {
      final cat = _detectCategory(idea);
      if (cat == null) continue;
      if (['practical', 'construction', 'survival', 'utility', 'furniture', 'garden'].contains(cat)) designCount++;
    }
    final designThinking = (designCount / ideaCount).clamp(0.0, 1.0);

    final earliestTimestamp = ideaTimestamps.isNotEmpty ? ideaTimestamps.last : null;
    double speedScore = 0.0;
    if (earliestTimestamp != null && earliestTimestamp > 0) {
      speedScore = (1.0 - (earliestTimestamp / 7000.0)).clamp(0.0, 1.0);
    }
    final burstCount = ideaTimestamps.where((t) => t <= 10000).length;
    final burstScore = (burstCount / 3.0).clamp(0.0, 1.0);
    final improvisation = (speedScore * 0.5 + burstScore * 0.5);

    int artCount = 0;
    for (final idea in ideas) {
      final cat = _detectCategory(idea);
      if (cat == 'art') artCount++;
    }
    final baseAesthetic = (artCount / ideaCount).clamp(0.0, 1.0);
    double aestheticFinal = baseAesthetic;
    if (convergentChosen && selectedOptionIndex >= 0 && selectedOptionIndex < ideas.length) {
      final selCat = _detectCategory(ideas[selectedOptionIndex]);
      if (selCat == 'art') {
        aestheticFinal = (aestheticFinal * 0.6 + 1.0 * 0.4).clamp(0.0, 1.0);
      }
    }

    final problemDecomp = (categories.length / 5.0).clamp(0.0, 1.0);

    return {
      "Creativity (Divergent Thinking)": divergentCreativity,
      "Creativity (Convergent Thinking)": convergentCreativity,
      "Idea Generation Fluency": ideaRateScore,
      "Design Thinking": designThinking,
      "Improvisation Ability": improvisation,
      "Aesthetic Sensitivity": aestheticFinal,
      "Problem Decomposition (creative version)": problemDecomp,
    };
  }

  @override
  Widget build(BuildContext context) {
    // --- CLEAN RESULTS SCREEN (Only shows if finished naturally) ---
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb, color: Colors.yellow, size: 80),
              const SizedBox(height: 20),
              const Text("Creativity Sprint Done!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Ideas Generated: $ideaCount", style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(calculateScores()), // Finish and send scores
                icon: const Icon(Icons.arrow_forward),
                label: const Text("NEXT GAME"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("5. Object Brainstorm ($currentSeconds)"),
        automaticallyImplyLeading: false,
        backgroundColor: isDivergentPhase ? Colors.indigo : Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
              onPressed: _onSkipPressed, // Calls the Immediate Exit logic
              child: const Text("SKIP", style: TextStyle(color: Colors.white))
          )
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(12)),
          child: const Column(
            children: [
              Text("PHASE 1: BRAINSTORM", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              SizedBox(height: 8),
              Text("List unique uses for a BRICK.", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text("(Be creative — quantity first)", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _submitIdea,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(backgroundColor: Colors.indigo),
            )
          ],
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Ideas: $ideaCount", style: const TextStyle(fontSize: 16)),
            Text("Time left: $currentSeconds s", style: const TextStyle(fontSize: 16)),
          ],
        ),

        const SizedBox(height: 12),

        Expanded(
          child: ListView.builder(
            itemCount: ideas.length,
            itemBuilder: (context, idx) {
              final idea = ideas[idx];
              final ts = ideaTimestamps[idx];
              final ms = (ts / 1000).toStringAsFixed(1);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo[100],
                    foregroundColor: Colors.indigo[800],
                    child: Text("${ideaCount - idx}"),
                  ),
                  title: Text(idea, style: const TextStyle(fontSize: 16)),
                  subtitle: Text("t=${ms}s"),
                ),
              );
            },
          ),
        ),

        ElevatedButton(
          onPressed: _switchToConvergent,
          child: const Text("DONE BRAINSTORMING (NEXT)"),
        )
      ],
    );
  }

  Widget _buildConvergentUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("PHASE 2: DECISION", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        const Text("Pick your best idea from the list.", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: ideas.isEmpty
              ? Center(child: Text("No ideas were created.", style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
            itemCount: ideas.length,
            itemBuilder: (context, idx) {
              final idea = ideas[idx];
              final isSelected = selectedOptionIndex == idx;
              final cat = _detectCategory(idea);
              final subtitle = cat != null ? "category: $cat" : null;
              return Card(
                color: isSelected ? (convergentChosen && selectedOptionIndex == idx ? Colors.green[50] : Colors.white) : null,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  onTap: () => _selectConvergent(idx),
                  leading: CircleAvatar(child: Text("${ideaCount - idx}")),
                  title: Text(idea, style: const TextStyle(fontSize: 16)),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _finishGame(); // Manual Finish triggers Result Screen
                },
                child: const Text("FINISH"),
              ),
            )
          ],
        )
      ],
    );
  }
}