import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../grading/brick_grading.dart';

// --- DATA & CONFIG ---

// --- NEW: timing evidence (tracking only) ---
int divergentUsedMs = 0;           // how long they actually brainstormed
int convergentStartMs = 0;         // when decision phase begins
int convergentDecisionMs = -1;     // time-to-pick within decision phase; -1 = no decision

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
      // No keyword extraction needed here anymore
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

  // Updated to be async
  Future<void> _onSkipPressed() async {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    final scores = await calculateScores();
    if (!mounted) return;
    Navigator.of(context).pop(scores);
  }

  // Updated to be async and call the new grade signature
  Future<Map<String, double>> calculateScores() async {
    return await BrickGrading.grade(
      ideas: ideas,
      divergentDuration: divergentDuration,
      divergentUsedMs: divergentUsedMs,
      convergentChosen: convergentChosen,
      selectedOptionIndex: selectedOptionIndex,
      convergentDecisionMs: convergentDecisionMs,
      convergentDuration: convergentDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                // Updated to handle async result
                onPressed: () async {
                  final scores = await calculateScores();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(scores);
                },
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
        title: const Text("Object Brainstorm"),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                  "$currentSeconds s",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: currentSeconds <= 5 ? Colors.red : Colors.indigo
                  )
              ),
            ),
          ),
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