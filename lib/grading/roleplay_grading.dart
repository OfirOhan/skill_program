// grading/roleplay_grading.dart

class RoleplayGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int totalCues,
    required List<bool> results,
    required List<int> reactionTimes,
    required List<bool> isPragmatic,      // CueType.pragmatic
    required List<bool> isSocialContext,  // CueType.socialContext
    required List<int> contextWordCounts,
    required List<int> quoteWordCounts,
    required List<int> optionsWordCounts,
  }) {
    if (totalCues == 0) {
      return {
        "Pragmatics": 0.0,
        "Social Context Awareness": 0.0,
        "Reading Comprehension Speed": 0.0,
      };
    }

    // m = number of answered cues (capped at totalCues)
    final int m = results.length.clamp(0, totalCues);

    // Treat unanswered cues as incorrect by dividing by totalCues
    final int correct = results.take(m).where((x) => x).length;
    final double overallAccuracy =
    (correct / totalCues).clamp(0.0, 1.0);

    // -----------------------------
    // Reading comprehension speed
    // -----------------------------

    double _median(List<double> xs) {
      if (xs.isEmpty) return 0.0;
      final sorted = List<double>.from(xs)..sort();
      final n = sorted.length;
      final mid = n ~/ 2;
      if (n.isOdd) {
        return sorted[mid];
      } else {
        return (sorted[mid - 1] + sorted[mid]) / 2.0;
      }
    }

    /// Aggregate speed: average of the 4 middle values after sorting.
    /// - If < 4 values, falls back to median.
    double _centerAverage4(List<double> xs) {
      if (xs.isEmpty) return 0.0;
      final sorted = List<double>.from(xs)..sort();
      final int n = sorted.length;

      // Not enough data → just use median
      if (n < 4) {
        return _median(xs);
      }

      final int mid = n ~/ 2;

      // Aim for 4 central values around the median
      int left = mid - 2;
      int right = mid + 1; // inclusive

      // Clamp to valid range, keeping window size as close to 4 as possible
      if (left < 0) {
        right += -left;
        left = 0;
      }
      if (right >= n) {
        final overflow = right - (n - 1);
        left = (left - overflow).clamp(0, n - 1);
        right = n - 1;
      }

      double sum = 0.0;
      int count = 0;
      for (int i = left; i <= right; i++) {
        sum += sorted[i];
        count++;
      }
      if (count == 0) return 0.0;
      return sum / count;
    }

    // Expected time (ms) from weighted reading load:
    //
    // - Base 4s to orient + interpret
    // - + 200ms per weighted word
    // - Clamped into [7s, 20s] (round cap still 25s, so this is a target band)
    double _expectedTimeMs(double weightedWords) {
      const double baseMs = 4000.0;
      const double perWordMs = 200.0;
      const double minMs = 7000.0;
      const double maxMs = 20000.0;

      final double raw = baseMs + perWordMs * weightedWords;
      return raw.clamp(minMs, maxMs);
    }

    // Weight options less than core text, but still significant
    const double optionWeight = 0.7;

    final int nSpeed = [
      m,
      reactionTimes.length,
      contextWordCounts.length,
      quoteWordCounts.length,
      optionsWordCounts.length,
    ].reduce((a, b) => a < b ? a : b);

    final List<double> perItemScores = [];

    for (int i = 0; i < nSpeed; i++) {
      final int rtMs = reactionTimes[i];
      if (rtMs <= 0) continue; // ignore invalid RTs

      final int ctxWords = contextWordCounts[i];
      final int quoteWords = quoteWordCounts[i];
      final int optWords = optionsWordCounts[i];

      // Per-cue weighted reading load
      final double weightedWords =
          ctxWords.toDouble() +
              quoteWords.toDouble() +
              optionWeight * optWords.toDouble();

      final double expectedMs = _expectedTimeMs(weightedWords);
      final double rt = rtMs.toDouble();

      // Base speed axis from timing only:
      //
      // r = rt / expected
      // - r <= 1.0   → baseSpeed = 1.0   (on time or faster)
      // - r >= 2.0   → baseSpeed = 0.0   (~2x slower than expected)
      // - 1.0 < r < 2.0 → linear drop 1 → 0
      final double r = rt / expectedMs;
      double baseSpeed;
      if (r <= 1.0) {
        baseSpeed = 1.0;
      } else if (r >= 2.0) {
        baseSpeed = 0.0;
      } else {
        baseSpeed = 2.0 - r; // between 1 and 0
      }
      baseSpeed = clamp01(baseSpeed);

      final bool isCorrectHere = results[i];
      double itemScore;

      if (isCorrectHere) {
        // Correct answers: map baseSpeed ∈ [0,1] → [0.4, 1.0]
        // - very slow but correct  → ~0.4
        // - on-time / fast correct → ~1.0
        itemScore = 0.4 + 0.6 * baseSpeed;
      } else {
        // Incorrect answers: map baseSpeed ∈ [0,1] → [0.0, 0.4]
        // (You set 0.4 here; wrong but very fast can approach 0.4,
        //  but still typically lower than correct answers.)
        itemScore = 0.4 * baseSpeed;
      }

      itemScore = clamp01(itemScore);
      perItemScores.add(itemScore);
    }

    // Aggregate per-round scores with center-average of 4 middle values.
    final double readingSpeed = _centerAverage4(perItemScores);

    // -----------------------------
    // Split by cue type (accuracy)
    // -----------------------------

    int pragmaticN = 0, pragmaticCorrect = 0;
    int socialContextN = 0, socialContextCorrect = 0;

    for (int i = 0; i < totalCues && i < m; i++) {
      if (isPragmatic[i]) {
        pragmaticN++;
        if (results[i]) pragmaticCorrect++;
      }

      if (isSocialContext[i]) {
        socialContextN++;
        if (results[i]) socialContextCorrect++;
      }
    }

    // Skill 1: Pragmatics (linguistic decoding)
    final double pragmaticsScore = pragmaticN == 0
        ? overallAccuracy
        : (pragmaticCorrect / pragmaticN).clamp(0.0, 1.0);

    // Skill 2: Social Context Awareness (situational decoding)
    final double socialContextScore = socialContextN == 0
        ? overallAccuracy
        : (socialContextCorrect / socialContextN).clamp(0.0, 1.0);

    return {
      "Pragmatics": pragmaticsScore,
      "Social Context Awareness": socialContextScore,
      "Reading Comprehension Speed": readingSpeed,
    };
  }
}
