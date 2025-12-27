
class WordLadderGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int totalItems,
    required List<bool> results,
    required List<int> reactionTimes,
    required List<String> categories,
  }) {
    if (totalItems == 0) {
      return {
        "Inductive Reasoning": 0.0,
        "Abstract Thinking": 0.0,
        "Information Processing Speed": 0.0,
      };
    }

    final int m = results.length;
    final int correct = results.where((x) => x).length;
    final double overallAccuracy = (correct / totalItems).clamp(0.0, 1.0);

    double medianRawSpeed = 0.0;
    if (reactionTimes.isNotEmpty) {
      final sorted = List<int>.from(reactionTimes)..sort();
      final double mid = sorted[sorted.length ~/ 2].toDouble();
      medianRawSpeed = (1.0 - ((mid - 800.0) / 9200.0)).clamp(0.0, 1.0);
    }

    int indN = 0, indC = 0;
    int absN = 0, absC = 0;

    for (int i = 0; i < totalItems && i < m; i++) {
        final cat = categories[i];
        if (cat == "SCALE" || cat == "SYSTEMS") {
            indN++;
            if (results[i]) indC++;
        } else {
            absN++;
            if (results[i]) absC++;
        }
    }

    final double inductiveAccuracy = indN == 0 ? 0.0 : (indC / indN).clamp(0.0, 1.0);
    final double abstractAccuracy = absN == 0 ? 0.0 : (absC / absN).clamp(0.0, 1.0);

    final double informationProcessingSpeed = clamp01(medianRawSpeed * overallAccuracy);

    return {
      "Inductive Reasoning": inductiveAccuracy,
      "Abstract Thinking": abstractAccuracy,
      "Information Processing Speed": informationProcessingSpeed,
    };
  }
}
