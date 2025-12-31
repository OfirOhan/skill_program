import 'dart:math';

class WordLadderGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<bool> results,
    required List<int> reactionTimes,
  }) {
    int n = min(results.length, reactionTimes.length);
    if (n == 0) return _zeroScore();

    // 1. Cognitive Profile (Fixed Weights)
    final List<Map<String, double>> itemWeights = [
      {"Inductive": 0.7, "Abstract": 0.3},
      {"Inductive": 0.3, "Abstract": 0.7},
      {"Inductive": 0.3, "Abstract": 0.7},
      {"Inductive": 0.8, "Abstract": 0.2},
      {"Inductive": 0.3, "Abstract": 0.7},
      {"Inductive": 0.2, "Abstract": 0.8},
    ];

    double earnedInductive = 0.0;
    double totalInductive = 0.0;
    double earnedAbstract = 0.0;
    double totalAbstract = 0.0;

    int correctCount = 0;

    for (int i = 0; i < n; i++) {
      if (i >= itemWeights.length) break;
      final weights = itemWeights[i];
      final wInd = weights["Inductive"]!;
      final wAbs = weights["Abstract"]!;

      totalInductive += wInd;
      totalAbstract += wAbs;

      if (results[i] == true) {
        correctCount++;
        earnedInductive += wInd;
        earnedAbstract += wAbs;
      }
    }

    final double inductiveScore = totalInductive > 0
        ? clamp01(earnedInductive / totalInductive)
        : 0.0;

    final double abstractScore = totalAbstract > 0
        ? clamp01(earnedAbstract / totalAbstract)
        : 0.0;

    // --- SCORING PROCESSING SPEED (Median) ---
    // 1. Calculate Raw Speed Scores for all items
    List<double> rawSpeeds = [];

    for (int i = 0; i < n; i++) {
      double t = reactionTimes[i].toDouble();

      double speedScore;
      if (t <= 3000) {
        speedScore = 1.0;
      } else if (t >= 15000) {
        speedScore = 0.5;
      } else {
        speedScore = 1.0 - ((t - 3000) / 12000) * 0.5;
      }
      rawSpeeds.add(speedScore);
    }

    // 2. Find the Median Raw Speed
    rawSpeeds.sort();
    double medianRawSpeed;
    if (n == 1) {
      medianRawSpeed = rawSpeeds[0];
    } else if (n % 2 == 1) {
      // Odd number of items: take the exact middle
      medianRawSpeed = rawSpeeds[n ~/ 2];
    } else {
      // Even number (Standard 6 items): take average of the two middle ones
      // For 6 items, indices are 0,1,2,3,4,5. Middle are [2] and [3].
      int mid = n ~/ 2;
      medianRawSpeed = (rawSpeeds[mid - 1] + rawSpeeds[mid]) / 2.0;
    }

    // 3. Apply Accuracy Penalty (Sqrt)
    double overallAccuracy = correctCount / n;
    final double ips = clamp01(medianRawSpeed * sqrt(overallAccuracy));

    return {
      "Inductive Reasoning": inductiveScore,
      "Abstract Thinking": abstractScore,
      "Information Processing Speed": ips,
    };
  }

  static Map<String, double> _zeroScore() => {
    "Inductive Reasoning": 0.0,
    "Abstract Thinking": 0.0,
    "Information Processing Speed": 0.0,
  };
}