import 'dart:convert';
import 'dart:math';

import 'package:google_generative_ai/google_generative_ai.dart';
import '../secure/api_keys.dart';

class BrickGrading {
  // Three separate keys from your secure store
  static String get _apiKey1 => ApiKeys.geminiApiKey_1.trim();
  static String get _apiKey2 => ApiKeys.geminiApiKey_2.trim();
  static String get _apiKey3 => ApiKeys.geminiApiKey_3.trim();

  /// Toggle this ON in tests when you want to see what Gemini is doing.
  static bool debugLogs = true;

  /// If true, _logError will also print the full error details from Gemini.
  static bool verboseErrors = false;

  static void _log(String msg) {
    if (debugLogs) {
      print(msg);
    }
  }

  static void _logError(String msg, [Object? error]) {
    if (debugLogs || verboseErrors) {
      print(msg);
      if (verboseErrors && error != null) {
        print("  Details: $error");
      }
    }
  }

  // Allowed discrete creativity levels (0.2 removed)
  static const List<double> _allowedCreativityLevels = <double>[
    0.0,
    0.3,
    0.4,
    0.6,
    0.8,
    1.0,
  ];

  /// Snap any raw Gemini score to nearest allowed level.
  static double _snapCreativity(double c) {
    double best = _allowedCreativityLevels.first;
    double bestDiff = (c - best).abs();

    for (final level in _allowedCreativityLevels.skip(1)) {
      final d = (c - level).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = level;
      }
    }
    return best;
  }

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
    // 0. Filter out empty ideas
    final filteredIdeas = ideas.where((s) => s.trim().isNotEmpty).toList();
    if (filteredIdeas.isEmpty) {
      return _zeroScores();
    }

    // 1. Time/quantity base (no AI yet)
    final double usedSeconds =
    (divergentUsedMs / 1000.0).clamp(1.0, divergentDuration.toDouble());

    // Target ~1 plausible idea per 9 seconds of actual work
    final double targetIdeas = max(1.0, usedSeconds / 9.0);

    // Decision-phase timing (currently only for future use)
    double pressureSpeedScore = 0.0;
    if (convergentChosen &&
        selectedOptionIndex != -1 &&
        convergentDuration > 0) {
      final double frac =
          convergentDecisionMs / (convergentDuration * 1000.0);
      pressureSpeedScore = (1.0 - frac).clamp(0.0, 1.0);
    }

    // 2. Ask Gemini for per-idea creativity + canonical forms
    List<_GeminiIdeaScore>? ideaScores;
    try {
      ideaScores = await _fetchCreativityScores(filteredIdeas);
    } catch (e) {
      _logError("⚠️ Gemini grading threw unexpectedly (all keys failed?):", e);
    }

    // 3. Fallback if Gemini failed or returned junk
    if (ideaScores == null || ideaScores.length != filteredIdeas.length) {
      _log("🔄 Using offline heuristic creativity fallback");
      ideaScores = _offlineIdeaScores(filteredIdeas);
    }

    // Debug dump (only if debugLogs == true)
    _debugDumpIdeas(filteredIdeas, ideaScores);

    // 4. Deterministic scoring from [ideaScores] + timing
    final scores = _computeScores(
      ideaScores: ideaScores,
      targetIdeas: targetIdeas,
      pressureSpeedScore: pressureSpeedScore,
      selectedOptionIndex: selectedOptionIndex,
    );

    _debugDumpSummary(scores, targetIdeas, ideaScores);

    return scores;
  }

  // ---------------------------------------------------------------------------
  // 1) GEMINI: PER-IDEA CREATIVITY + CANONICAL FORM, WITH MULTI-KEY FALLBACK
  // ---------------------------------------------------------------------------

  static Future<List<_GeminiIdeaScore>?> _fetchCreativityScores(
      List<String> ideas) async {
    if (ideas.isEmpty) return null;

    // Try key #1, then #2, then #3 (skip empties)
    final apiKeys = <String>[_apiKey1, _apiKey2, _apiKey3]
        .where((k) => k.isNotEmpty)
        .toList();

    if (apiKeys.isEmpty) return null;

    final modelsToTry = <String>[
      'gemini-2.5-flash',
      'gemini-2.0-flash',
    ];

    final ideasJson = jsonEncode(ideas);

    final prompt = '''
You score how creative each "alternative use" of a BRICK is.

Core rules (very important):
- Score EACH idea **independently** on an ABSOLUTE scale from 0.0 to 1.0.
- Pretend you see ONE idea at a time, not the whole list.
- The score for an idea MUST NOT change just because other ideas in the list
  are better or worse. Do NOT rank or normalize across the list.
- In borderline cases, err slightly toward a higher score (be generous, not harsh).

DISCRETE SCALE:
When you choose the creativity, you MUST round it to the NEAREST value in this set:
[0.0, 0.3, 0.4, 0.6, 0.8, 1.0]
Do not output values outside this set.

For EACH idea, output:
- "creativity": one of [0.0, 0.3, 0.4, 0.6, 0.8, 1.0]
- "canonical": a short, corrected English phrase describing the same use
  (fix spelling, simplify wording).
If two ideas are essentially the SAME USE, give them the EXACT same canonical phrase.

Creativity scale (calibrated for average adults given ~45 seconds to think):
- 0.0 = nonsense / off-topic / not really a use.
- 0.3 = very trivial "first reflex" uses that almost everyone would say in the
        first seconds. Typically:
        * "build a wall"
        * "build a house"
        * "doorstop" / "hold a door open"
        * "paperweight"
        * "use as a weapon" / "throw it at someone"
- 0.4 = ordinary but reasonable; a bit beyond those reflex answers, but still
        not especially original.
- 0.6 = clearly above-average idea with some novelty compared to what most
        people would produce in 45 seconds.
- 0.8 = very creative and surprising but still realistic.
- 1.0 = exceptional for a 45-second task:
        highly original, realistic, and would impress a creativity researcher.
        If an idea fits this description, you SHOULD give 1.0 (do not avoid it).

Calibration anchors (examples to set the scale; they are NOT the only valid uses):
- "build a wall"                             -> ≈ 0.3
- "paperweight"                              -> ≈ 0.4
- "line a garden path as edging"             -> ≈ 0.6
- "use as garden border around flower beds"  -> ≈ 0.6
- "drill holes and use as a bird feeder"     -> ≈ 0.8–1.0
- "crush into red pigment for artists"       -> ≈ 1.0
- "use as a heat sink behind a solar panel"  -> ≈ 1.0

Respond ONLY with JSON in this exact shape:

{
  "scores": [
    { "index": 0, "creativity": 0.0, "canonical": "..." },
    { "index": 1, "creativity": 0.0, "canonical": "..." }
  ]
}

Here is the ideas list as JSON (array of strings):

$ideasJson
''';

    // Try each key in order; if ALL models fail on a key, move to the next key
    for (int keyIdx = 0; keyIdx < apiKeys.length; keyIdx++) {
      final key = apiKeys[keyIdx];
      _log("🔑 Using Gemini API key #${keyIdx + 1}");

      for (final modelName in modelsToTry) {
        try {
          _log("🚀 Trying Gemini model: $modelName");

          final model = GenerativeModel(
            model: modelName,
            apiKey: key,
            generationConfig: GenerationConfig(
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

          // Start with all ideas defaulting to 0.0 creativity and their raw text
          final result = List<_GeminiIdeaScore>.generate(
            ideas.length,
                (i) => _GeminiIdeaScore(
              canonical: ideas[i].trim(),
              creativity: 0.0,
            ),
            growable: false,
          );

          for (final item in scoresList) {
            if (item is! Map) continue;
            final idx = item['index'];
            final c = item['creativity'];
            final canon = item['canonical'];

            if (idx is int &&
                idx >= 0 &&
                idx < ideas.length &&
                c is num) {
              final rawCreat = c.toDouble().clamp(0.0, 1.0);
              final creativity = _snapCreativity(rawCreat);
              final canonical = (canon is String && canon.trim().isNotEmpty)
                  ? canon.trim()
                  : ideas[idx].trim();

              result[idx] = _GeminiIdeaScore(
                canonical: canonical,
                creativity: creativity,
              );
            }
          }

          _log("✅ Gemini $modelName succeeded with key #${keyIdx + 1}.");
          return result;
        } catch (e) {
          _logError(
            "❌ Gemini model $modelName failed with key #${keyIdx + 1}, trying next model/key.",
            e,
          );
          // Continue to next model or next key
        }
      }

      _log(
          "⚠️ All models failed for Gemini key #${keyIdx + 1}, trying next key if available...");
    }

    // If we exit the loop, all keys & models failed
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2) OFFLINE FALLBACK: HEURISTIC CREATIVITY (STATIC)
  // ---------------------------------------------------------------------------

  static List<_GeminiIdeaScore> _offlineIdeaScores(List<String> ideas) {
    final scores = <_GeminiIdeaScore>[];
    for (final idea in ideas) {
      final text = idea.toLowerCase().trim();
      if (text.isEmpty) {
        scores.add(_GeminiIdeaScore(canonical: '', creativity: 0.0));
        continue;
      }

      final length = text.length;
      double c;
      if (_looksLikeGibberish(text)) {
        c = 0.0;
      } else if (length < 10) {
        c = 0.3;
      } else if (length < 30) {
        c = 0.4;
      } else {
        c = 0.6;
      }

      scores.add(_GeminiIdeaScore(
        canonical: idea.trim(),
        creativity: _snapCreativity(c),
      ));
    }
    return scores;
  }

  static bool _looksLikeGibberish(String text) {
    final lower = text.toLowerCase();
    final vowels = RegExp(r'[aeiouy]');
    return lower.length > 4 && !vowels.hasMatch(lower);
  }

  // ---------------------------------------------------------------------------
  // 3) DETERMINISTIC SCORING FROM IDEA SCORES + TIMING
  // ---------------------------------------------------------------------------

  static Map<String, double> _computeScores({
    required List<_GeminiIdeaScore> ideaScores,
    required double targetIdeas,
    required double pressureSpeedScore, // currently unused
    required int selectedOptionIndex,
  }) {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    if (ideaScores.isEmpty) {
      return _zeroScores();
    }

    // ---- STEP 1: group by canonical (dedupe concepts) -----------------------
    final Map<String, double> conceptBest = <String, double>{};

    for (final s in ideaScores) {
      final canonKey = s.canonical.trim().toLowerCase();
      if (canonKey.isEmpty) continue;

      final existing = conceptBest[canonKey];
      if (existing == null || s.creativity > existing) {
        conceptBest[canonKey] = s.creativity;
      }
    }

    if (conceptBest.isEmpty) {
      return _zeroScores();
    }

    final conceptScores = conceptBest.values.toList();

    // Only concepts with creativity >= 0.3 count as "plausible"
    final valid = conceptScores.where((c) => c >= 0.3).toList();
    final int nValid = valid.length;

    if (nValid == 0) {
      return _zeroScores();
    }

    // 3+ distinct plausible concepts = full engagement
    final double engagementFactor = clamp01(nValid / 3.0);

    // Raw fluency based on number of distinct plausible concepts vs time target
    final double rawFluencyScore = clamp01(nValid / targetIdeas);

    // Best concept's creativity
    final double peakCreativity = valid.reduce(max);

    // Quality factor for Fluency = best concept's creativity directly
    final double qualityFactor = peakCreativity; // 0.0–1.0

    // --- Ideation Fluency ---
    final double fluency =
    clamp01((rawFluencyScore + qualityFactor + engagementFactor) / 3.0);

    // --- Divergent Thinking ---
    const double highThreshold = 0.5;
    final int highCount = valid.where((c) => c >= highThreshold).length;
    final double multiHigh =
    highCount == 0 ? 0.0 : min(highCount, 3) / 3.0; // 0, 1/3, 2/3, 1

    final double coreDivergence =
        0.6 * peakCreativity + 0.4 * multiHigh;

    final double divergent =
    clamp01((coreDivergence + engagementFactor) / 2.0);

    // --- Planning & Prioritization ---
    double planning = 0.0;

    if (selectedOptionIndex >= 0 &&
        selectedOptionIndex < ideaScores.length) {
      final double bestCreat = peakCreativity;
      final double chosenCreat = ideaScores[selectedOptionIndex].creativity;

      double selectionQuality = 0.0;
      if (bestCreat > 0.0) {
        // Simple ratio (no special 0.1-near-peak rule)
        selectionQuality = clamp01(chosenCreat / bestCreat);
      }

      planning = selectionQuality * engagementFactor;
    }

    return {
      "Ideation Fluency": fluency,
      "Divergent Thinking": divergent,
      "Planning & Prioritization": planning,
    };
  }

  // ---------------------------------------------------------------------------
  // 4) DEBUG HELPERS (OPTIONAL)
  // ---------------------------------------------------------------------------

  static void _debugDumpIdeas(
      List<String> rawIdeas, List<_GeminiIdeaScore> scores) {
    if (!debugLogs) return;
    _log("=== Gemini per-idea scores for BrickGrading ===");
    for (int i = 0; i < rawIdeas.length; i++) {
      final raw = rawIdeas[i];
      final s = scores[i];
      _log(
          "[$i] raw='${raw}' | canonical='${s.canonical}' | creativity=${s.creativity}");
    }
    _log("===============================================");
  }

  static void _debugDumpSummary(
      Map<String, double> scores,
      double targetIdeas,
      List<_GeminiIdeaScore> ideaScores,
      ) {
    if (!debugLogs) return;

    final conceptBest = <String, double>{};
    for (final s in ideaScores) {
      final canonKey = s.canonical.trim().toLowerCase();
      if (canonKey.isEmpty) continue;
      final existing = conceptBest[canonKey];
      if (existing == null || s.creativity > existing) {
        conceptBest[canonKey] = s.creativity;
      }
    }
    final conceptScores = conceptBest.values.toList();
    final valid = conceptScores.where((c) => c >= 0.3).toList();
    final nValid = valid.length;
    final rawFluency = nValid / targetIdeas;
    final engagementFactor = nValid / 3.0;
    _log("=== BrickGrading summary ===");
    _log("  targetIdeas=$targetIdeas");
    _log("  nValid=$nValid");
    _log("  rawFluencyScore=$rawFluency");
    _log("  engagementFactor=$engagementFactor");
    _log("  conceptScores=$conceptScores");
    if (valid.isNotEmpty) {
      _log("  peakCreativity=${valid.reduce(max)}");
    }
    _log("  fluency=${scores["Ideation Fluency"]}");
    _log("  divergent=${scores["Divergent Thinking"]}");
    _log("  planning=${scores["Planning & Prioritization"]}");
    _log("===============================================");
  }

  // ---------------------------------------------------------------------------
  // 5) UTIL
  // ---------------------------------------------------------------------------

  static Map<String, double> _zeroScores() => const {
    "Ideation Fluency": 0.0,
    "Divergent Thinking": 0.0,
    "Planning & Prioritization": 0.0,
  };
}

// Simple internal struct to carry Gemini scores
class _GeminiIdeaScore {
  final String canonical;
  final double creativity;

  _GeminiIdeaScore({
    required this.canonical,
    required this.creativity,
  });
}
