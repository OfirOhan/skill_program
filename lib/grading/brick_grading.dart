import 'dart:math';

class BrickGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<String> ideas,
    required Map<String, int> keywordFrequency,
    required int divergentDuration,
    required int divergentUsedMs,
    required bool convergentChosen,
    required int selectedOptionIndex,
    required int convergentDecisionMs,
    required int convergentDuration,
  }) {
    bool isValidIdea(String s) => BrickHelpers.containsRealWord(s);

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

    if (validCount == 0) {
      return {
        "Ideation Fluency": 0.0,
        "Divergent Thinking": 0.0,
        "Cognitive Flexibility": 0.0,
        "Planning & Prioritization": 0.0,
        "Decision Under Pressure": 0.0,
      };
    }

    // 1) Ideation Fluency
    final int usedMs = (divergentUsedMs > 0)
        ? divergentUsedMs.clamp(1, divergentDuration * 1000)
        : (divergentDuration * 1000);

    final double usedSeconds = usedMs / 1000.0;
    final double targetIdeas = usedSeconds / 5.0;
    final double ideationFluency = clamp01(validCount / (targetIdeas <= 0 ? 1.0 : targetIdeas));

    // 2) Divergent Thinking
    double divergentThinking = 0.0;
    if (validCount >= 2) {
      double sumOrig = 0.0;
      for (final idea in validIdeas) {
        sumOrig += BrickHelpers.originalityForIdea(idea, keywordFrequency);
      }
      divergentThinking = clamp01(sumOrig / validCount);
    }

    // 3) Cognitive Flexibility
    double cognitiveFlexibility = 0.0;
    {
      final Map<String, int> catFreq = {};
      int categorized = 0;

      for (final idea in validIdeas) {
        final cat = BrickHelpers.detectCategory(idea);
        if (cat != null) {
          categorized++;
          catFreq[cat] = (catFreq[cat] ?? 0) + 1;
        }
      }

      final int K = BrickHelpers.keywordToCategory.values.toSet().length;

      if (categorized >= 2 && catFreq.length >= 2 && K >= 2) {
        double h = 0.0;
        catFreq.forEach((_, c) {
          final double p = c / categorized;
          h += -p * log(p);
        });
        final double hMax = log(K.toDouble());
        cognitiveFlexibility = clamp01(hMax <= 0 ? 0.0 : (h / hMax));
      }
    }

    // 4) Planning & Prioritization
    double planningPrioritization = 0.0;
    double selectedQualityRatio = 0.0;

    double qualityOf(String idea) {
      final double o = BrickHelpers.originalityForIdea(idea, keywordFrequency);
      final double e = BrickHelpers.elaborationScore(idea);
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
    }

    // 5) Decision Under Pressure
    double decisionUnderPressure = 0.0;
    if (convergentChosen && convergentDecisionMs >= 0) {
      final double timeScore = clamp01(1.0 - (convergentDecisionMs / (convergentDuration * 1000.0)));
      decisionUnderPressure = clamp01(timeScore * selectedQualityRatio);
    }

    return {
      "Ideation Fluency": ideationFluency,
      "Divergent Thinking": divergentThinking,
      "Cognitive Flexibility": cognitiveFlexibility,
      "Planning & Prioritization": planningPrioritization,
      "Decision Under Pressure": decisionUnderPressure,
    };
  }
}

class BrickHelpers {

  static final Set<String> _englishWords = {
    "door", "doorstop", "weapon", "build", "pedestal", "paint", "powder",
    "crush", "pigment", "throw", "window", "art", "sculpture", "support",
    "press", "hold", "paperweight", "display", "wall", "design", "color",
    "decorate", "stack", "heat", "warm", "insulate", "tool", "plant",
    "garden", "planter", "seat", "step", "bench", "anchor", "weight",
    "exercise", "paper", "book", "bookend"
  };

  static final Set<String> _commonIdeas = {
    "doorstop", "paperweight", "build wall", "build", "throw", "weapon", "bookend", "step",
  };

  static final Map<String, String> keywordToCategory = {
    "door": "practical", "doorstop": "practical", "paper": "practical", "paperweight": "practical",
    "book": "practical", "bookend": "practical", "build": "construction", "wall": "construction",
    "stack": "construction", "paint": "art", "pigment": "art", "powder": "art", "crush": "art",
    "sculpture": "art", "seat": "furniture", "bench": "furniture", "step": "furniture",
    "weapon": "danger", "throw": "danger", "heat": "survival", "warm": "survival",
    "plant": "garden", "planter": "garden", "anchor": "utility", "weight": "utility", "exercise": "utility",
  };

  static bool containsRealWord(String idea) {
    final parts = idea.toLowerCase().split(RegExp(r'[^a-z]+'));
    return parts.any((w) => _englishWords.contains(w));
  }

  static List<String> extractKeywords(String idea) {
    return idea.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty && _englishWords.contains(w)).toList();
  }

  static String? detectCategory(String idea) {
    final kws = extractKeywords(idea);
    for (final k in kws) {
      if (keywordToCategory.containsKey(k)) return keywordToCategory[k];
    }
    return null;
  }

  static bool isCommonIdea(String idea) {
    final lowered = idea.toLowerCase();
    for (final c in _commonIdeas) {
      if (lowered.contains(c)) return true;
    }
    return false;
  }

  static double elaborationScore(String idea) {
    final kws = extractKeywords(idea).length;
    return min(kws / 6.0, 1.0);
  }

  static double originalityForIdea(String idea, Map<String, int> freq) {
    if (!containsRealWord(idea)) return 0.0;
    if (isCommonIdea(idea)) return 0.0;
    final kws = extractKeywords(idea);
    if (kws.isEmpty) return 0.0;
    final primary = kws.first;
    final f = freq[primary] ?? 0;
    if (f <= 1) return 1.0;
    return (1.0 / (f)).clamp(0.0, 1.0);
  }
}
