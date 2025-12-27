
class ChartGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<bool> results,
    required List<int> reactionTimes,
    required List<bool> isMathQuestion,
  }) {
    final int total = results.length;
    if (total == 0) {
        return {
            "Quantitative Reasoning": 0.0,
            "Information Processing Speed": 0.0,
        };
    }

    final int correctCount = results.where((x) => x).length;
    final double overallAccuracy = (correctCount / total).clamp(0.0, 1.0);

    int mathN = 0;
    int mathC = 0;

    for (int i=0; i<total; i++) {
        if (isMathQuestion[i]) {
            mathN++;
            if (results[i]) mathC++;
        }
    }

    final double mathAccuracy = mathN == 0 ? 0.0 : (mathC / mathN).clamp(0.0, 1.0);
    final double mathEvidence = (mathN / 5.0).clamp(0.0, 1.0);

    double medianRawSpeed = 0.0;
    if (reactionTimes.isNotEmpty) {
      final sorted = List<int>.from(reactionTimes)..sort();
      final mid = sorted[sorted.length ~/ 2].toDouble();
      medianRawSpeed = (1.0 - ((mid - 1500) / 8500)).clamp(0.0, 1.0);
    }

    final double quantitativeReasoning = clamp01(mathAccuracy * mathEvidence * overallAccuracy);
    final double informationProcessingSpeed = clamp01(medianRawSpeed * overallAccuracy);

    return {
      "Quantitative Reasoning": quantitativeReasoning,
      "Information Processing Speed": informationProcessingSpeed,
    };
  }
}
