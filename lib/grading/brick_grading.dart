import 'dart:convert';
import 'dart:math';
import '../secure/api_keys.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Internal holder for Gemini results
class _CreativityResult {
  final List<double> creativity; // length == ideas.length
  final List<String> canonical;  // length == ideas.length

  const _CreativityResult({
    required this.creativity,
    required this.canonical,
  });
}

class BrickGrading {
  // ⚠️ Put YOUR Gemini API key here (do NOT commit it to Git)
  static String get _apiKey => ApiKeys.geminiApiKey.trim();

  // ---------------------------------------------------------------------------
  // PUBLIC ENTRY POINT
  // ---------------------------------------------------------------------------
  static Future<Map<String, double>> grade({
    required List<String> ideas,
    required int divergentDuration,
    required int divergentUsedMs,
    required bool convergentChosen,
    required int selectedOptionIndex,
    required int convergentDecisionMs,
    required int convergentDuration,
  }) async {
    // 0. Filter out empty ideas (extra safety – UI already does this)
    final filteredIdeas = ideas.where((s) => s.trim().isNotEmpty).toList();
    if (filteredIdeas.isEmpty) {
      return _zeroScores();
    }

    // 1. Time/quantity base (no AI yet)
    final double usedSeconds =
    (divergentUsedMs / 1000.0).clamp(1.0, divergentDuration.toDouble());

    // Target ~1 plausible idea per 9 seconds of actual work
    final double targetIdeas = max(1.0, usedSeconds / 9.0);

    // Decision under time pressure (kept for future use if needed)
    double pressureSpeedScore = 0.0;
    if (convergentChosen &&
        selectedOptionIndex != -1 &&
        convergentDuration > 0) {
      final double frac =
          convergentDecisionMs / (convergentDuration * 1000.0);
      pressureSpeedScore = (1.0 - frac).clamp(0.0, 1.0);
    }

    // 2. Ask Gemini for per-idea creativity + canonical forms
    _CreativityResult? result;
    try {
      result = await _fetchCreativityScores(filteredIdeas);
    } catch (e) {
      print("⚠️ Gemini grading failed: $e");
    }

    // 3. Fallback if Gemini failed or returned junk
    if (result == null ||
        result.creativity.length != filteredIdeas.length ||
        result.canonical.length != filteredIdeas.length) {
      print("🔄 Using offline heuristic creativity fallback");
      result = _offlineCreativityScores(filteredIdeas);
    }

    // 4. Deterministic scoring from [creativity + canonical] + timing
    return _computeScores(
      creativity: result.creativity,
      canonical: result.canonical,
      targetIdeas: targetIdeas,
      pressureSpeedScore: pressureSpeedScore,
      selectedOptionIndex: selectedOptionIndex,
    );
  }

  // ---------------------------------------------------------------------------
  // 1) GEMINI: PER-IDEA CREATIVITY + CANONICAL FORM
  // ---------------------------------------------------------------------------

  static Future<_CreativityResult?> _fetchCreativityScores(
      List<String> ideas) async {
    if (_apiKey.isEmpty) return null;
    if (ideas.isEmpty) return null;

    final modelsToTry = <String>[
      'gemini-2.5-flash',
      'gemini-2.0-flash',
    ];

    final ideasJson = jsonEncode(ideas);

    final prompt = '''
You grade creative "alternative uses" for the object BRICK.

For EACH idea, you must return:
- "creativity": a score between 0.0 and 1.0
- "canonical": the same idea rewritten with correct spelling and minimal grammar fixes.
  * Do NOT paraphrase or add new information.
  * Keep it as short and direct as possible.
  * If two inputs from the list express essentially the same idea,
    you MUST use exactly the same "canonical" string for both.

Creativity scale:
- 0.0 = nonsense, off-topic, or unusable as a real use.
- 0.3 = extremely common/cliché but plausible.
- 0.5 = ordinary but reasonable.
- 0.7 = somewhat original and plausible in real life.
- 1.0 = highly original AND realistically usable.

Return ONLY valid JSON in exactly this shape:

{
  "scores": [
    { "index": 0, "creativity": 0.0, "canonical": "..." },
    { "index": 1, "creativity": 0.0, "canonical": "..." }
  ]
}

Do not include explanations or any extra text.

Here is the ideas list as JSON:

$ideasJson
''';

    for (final modelName in modelsToTry) {
      try {
        print("🚀 Trying Gemini model: $modelName");

        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
          generationConfig: GenerationConfig( // <-- removed 'const' here
            temperature: 0.0,
            topP: 0.0,
            topK: 1,
          ),
        );

        final response = await model.generateContent([Content.text(prompt)]);

        final raw = response.text;
        if (raw == null) continue;

        final clean = raw
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final decoded = jsonDecode(clean) as Map<String, dynamic>?;

        if (decoded == null || decoded['scores'] == null) {
          continue;
        }

        final scoresList = decoded['scores'] as List<dynamic>;
        final scores =
        List<double>.filled(ideas.length, 0.0, growable: false);
        final canonical =
        List<String>.filled(ideas.length, '', growable: false);

        for (final item in scoresList) {
          if (item is! Map) continue;
          final idx = item['index'];
          final c = item['creativity'];
          final canon = item['canonical'];

          if (idx is int && idx >= 0 && idx < ideas.length) {
            if (c is num) {
              scores[idx] = c.toDouble().clamp(0.0, 1.0);
            }
            if (canon is String) {
              canonical[idx] = canon.trim();
            }
          }
        }

        // 🔍 DEBUG: see what Gemini actually did
        print("=== Gemini per-idea scores for BrickGrading ===");
        for (int i = 0; i < ideas.length; i++) {
          final rawText = ideas[i];
          final canonText = canonical[i];
          final cVal = scores[i];
          print("[$i] raw='$rawText' | canonical='$canonText' | creativity=$cVal");
        }
        print("===============================================");

        print("✅ Gemini $modelName succeeded.");
        return _CreativityResult(
          creativity: scores,
          canonical: canonical,
        );

      } catch (e) {
        print("❌ Gemini model $modelName failed: $e");
      }
    }

    return null; // all models failed
  }

  // ---------------------------------------------------------------------------
  // 2) OFFLINE FALLBACK: SIMPLE HEURISTIC CREATIVITY + CANONICAL
  //    (STATIC, NO AI – used only if Gemini fails)
  // ---------------------------------------------------------------------------

  static _CreativityResult _offlineCreativityScores(List<String> ideas) {
    final scores = <double>[];
    final canonical = <String>[];

    for (final idea in ideas) {
      final trimmed = idea.trim();
      final text = trimmed.toLowerCase();

      double score;
      if (text.isEmpty) {
        score = 0.0;
      } else if (_looksLikeGibberish(text)) {
        score = 0.0;
      } else {
        final length = text.length;
        if (length < 10) {
          // short & plausible-ish
          score = 0.3;
        } else if (length < 30) {
          score = 0.5;
        } else {
          score = 0.7;
        }
      }

      scores.add(score);
      canonical.add(trimmed); // simple normalized text
    }

    return _CreativityResult(
      creativity: scores,
      canonical: canonical,
    );
  }

  static bool _looksLikeGibberish(String text) {
    // No vowels -> probably nonsense (very rough)
    final lower = text.toLowerCase();
    final vowels = RegExp(r'[aeiouy]');
    return lower.length > 4 && !vowels.hasMatch(lower);
  }

  // ---------------------------------------------------------------------------
  // 3) DETERMINISTIC SCORING FROM CREATIVITY + CANONICAL + TIMING
  // ---------------------------------------------------------------------------

  static Map<String, double> _computeScores({
    required List<double> creativity,
    required List<String> canonical,
    required double targetIdeas,
    required double pressureSpeedScore, // currently unused in final output
    required int selectedOptionIndex,
  }) {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    if (creativity.isEmpty) {
      return _zeroScores();
    }

    final int n = creativity.length;

    // Canonical param is final; create a safe local copy with correct length
    final List<String> canon = List<String>.filled(n, '');
    final int copyLen = min(n, canonical.length);
    for (int i = 0; i < copyLen; i++) {
      canon[i] = canonical[i];
    }

    const double plausibleThreshold = 0.3;

    // Build clusters by canonical form for Divergent & Planning,
    // while still counting ALL plausible ideas for Fluency.
    final Map<String, List<int>> clusters = {};
    int nValid = 0;

    for (int i = 0; i < n; i++) {
      final c = creativity[i];
      if (c < plausibleThreshold) continue;

      nValid++;

      String key = canon[i].trim().toLowerCase();
      if (key.isEmpty) {
        key = '__idea_$i';
      }

      clusters.putIfAbsent(key, () => []).add(i);
    }

    // If no plausible ideas at all → no credit
    if (nValid == 0 || clusters.isEmpty) {
      return _zeroScores();
    }

    // Engagement: 3+ plausible ideas = full
    final double engagementFactor = clamp01(nValid / 3.0);

    // Raw fluency: how many plausible ideas vs time-based target
    final double rawFluencyScore = clamp01(nValid / targetIdeas);

    // Cluster-level scores (unique conceptual ideas)
    final List<double> clusterScores = [];
    clusters.forEach((_, idxs) {
      double best = 0.0;
      for (final i in idxs) {
        best = max(best, creativity[i]);
      }
      clusterScores.add(best);
    });

    // Peak creativity among plausible ideas (best single conceptual idea)
    final double peakCreativity = clusterScores.reduce(max);

    // -------------------------
    // Ideation Fluency
    // -------------------------
    //
    // Mean of:
    //  - rawFluencyScore (quantity vs time)
    //  - peakCreativity  (best idea strength)
    //  - engagementFactor (how many plausible ideas)
    //
    final double qualityFactor = peakCreativity;
    final double fluency = clamp01(
        (rawFluencyScore + qualityFactor + engagementFactor) / 3.0);

    // -------------------------
    // Divergent Thinking
    // -------------------------
    //
    // Based on:
    //  - peakStrength: best cluster score
    //  - multiHigh: how many clusters are "pretty creative" (>= 0.5)
    //  - engagementFactor: overall effort
    //
    const double highThreshold = 0.5;
    final int highCount =
        clusterScores.where((c) => c >= highThreshold).length;
    final double multiHigh =
    highCount == 0 ? 0.0 : min(highCount, 3) / 3.0; // 0, 1/3, 2/3, 1

    final double peakStrength = peakCreativity;

    final double coreDivergence =
        0.6 * peakStrength + 0.4 * multiHigh;

    final double divergent =
    clamp01((coreDivergence + engagementFactor) / 2.0);

    // -------------------------
    // Planning & Prioritization
    // -------------------------
    //
    // "Did you select one of your strongest (plausible) ideas?"
    //
    double planning = 0.0;
    if (selectedOptionIndex >= 0 && selectedOptionIndex < n) {
      final double chosenCreat = creativity[selectedOptionIndex];

      if (chosenCreat >= plausibleThreshold && peakCreativity > 0.0) {
        final double selectionQuality =
        clamp01(chosenCreat / peakCreativity);
        planning = selectionQuality * engagementFactor;
      } else {
        // Picked a non-plausible idea or no creativity signal
        planning = 0.0;
      }
    }
    // 🔍 DEBUG: overall grading summary
    print("=== BrickGrading summary ===");
    print("  targetIdeas=$targetIdeas");
    print("  nValid=$nValid");
    print("  rawFluencyScore=$rawFluencyScore");
    print("  engagementFactor=$engagementFactor");
    print("  clusterScores=$clusterScores");
    print("  peakCreativity=$peakCreativity");
    print("  fluency=$fluency");
    print("  divergent=$divergent");
    print("  planning=$planning");
    print("================================");

    return {
      "Ideation Fluency": fluency,
      "Divergent Thinking": divergent,
      "Planning & Prioritization": planning,
    };
  }

  // ---------------------------------------------------------------------------
  // 4) UTIL
  // ---------------------------------------------------------------------------

  static Map<String, double> _zeroScores() => {
    "Ideation Fluency": 0.0,
    "Divergent Thinking": 0.0,
    "Planning & Prioritization": 0.0,
  };
}
