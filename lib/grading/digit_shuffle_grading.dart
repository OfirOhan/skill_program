import 'dart:math';

class DigitShuffleGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  // The "Perfection Bonus" Logic
  // If perfect, return 1.0.
  // If even slightly wrong, apply a 20% penalty (multiply by 0.8).
  static double _applyPenalty(double rawAccuracy) {
    if (rawAccuracy >= 1.0) return 1.0;
    return rawAccuracy * 0.8;
  }

  static Map<String, double> grade({
    required List<double> roundAccuracies,
    required List<int> roundTimesMs,
    required List<int> roundTaskTypes, // 0=Recall, 1=Sort, 2=Add
  }) {
    final int n = min(roundAccuracies.length, min(roundTimesMs.length, roundTaskTypes.length));
    if (n <= 0) return _zeroScore();

    // 1. Create a Penalized Accuracy List first
    final List<double> penalizedAccs = roundAccuracies
        .map((acc) => _applyPenalty(acc))
        .toList();

    final List<int> sequenceLengths = [5, 5, 6, 6, 7];

    // --- 1. ROTE MEMORIZATION (Capacity) ---
    double weightedAcc = 0.0;
    double totalWeight = 0.0;
    for (int i = 0; i < n; i++) {
      int len = (i < sequenceLengths.length) ? sequenceLengths[i] : 5;
      weightedAcc += penalizedAccs[i] * len;
      totalWeight += len;
    }
    final double roteMemorization = totalWeight > 0
        ? clamp01(weightedAcc / totalWeight)
        : 0.0;

    // --- 2. WORKING MEMORY (Processing Power) ---
    List<double> manipulationScores = [];
    for (int i = 0; i < n; i++) {
      if (roundTaskTypes[i] == 1 || roundTaskTypes[i] == 2) {
        manipulationScores.add(penalizedAccs[i]);
      }
    }

    double workingMemory;
    if (manipulationScores.isEmpty) {
      workingMemory = roteMemorization;
    } else {
      workingMemory = manipulationScores.reduce((a, b) => a + b) / manipulationScores.length;
    }

    // --- 3. INFORMATION PROCESSING SPEED (Efficiency Average) ---
    double sumEffectiveSpeed = 0.0;

    for (int i = 0; i < n; i++) {
      int len = (i < sequenceLengths.length) ? sequenceLengths[i] : 5;
      double msPerDigit = roundTimesMs[i] / len;

      double roundSpeedScore;
      if (msPerDigit <= 400.0) {
        roundSpeedScore = 1.0;
      } else if (msPerDigit >= 3000.0) {
        roundSpeedScore = 0.5;
      } else {
        roundSpeedScore = 1.0 - ((msPerDigit - 400) / 2600.0) * 0.5;
      }

      // Multiply by PENALIZED accuracy
      sumEffectiveSpeed += (roundSpeedScore * sqrt(penalizedAccs[i]));
    }

    double ips = clamp01(sumEffectiveSpeed / n);

    return {
      "Rote Memorization": clamp01(roteMemorization),
      "Working Memory": clamp01(workingMemory),
      "Information Processing Speed": clamp01(ips),
    };
  }

  static Map<String, double> _zeroScore() => {
    "Rote Memorization": 0.0,
    "Working Memory": 0.0,
    "Information Processing Speed": 0.0,
  };
}