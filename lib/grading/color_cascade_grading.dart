
class ColorCascadeGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int totalCorrect,
    required double totalPrecision,
    required int rounds,
    required List<int> reactionTimes,
    required int timeoutPenaltyMs, 
  }) {
    if (rounds == 0) {
        return {
            "Color Discrimination": 0.0,
            "Visual Acuity": 0.0,
            "Pattern Recognition": 0.0,
            "Information Processing Speed": 0.0,
            "Decision Under Pressure": 0.0,
        };
    }

    // Strict round wins (perfect sort + correct odd-tap rounds)
    final double strictAccuracy = (totalCorrect / rounds).clamp(0.0, 1.0);

    // Precision includes partial credit on sort + 0/1 on grid rounds
    final double precision = (totalPrecision / rounds).clamp(0.0, 1.0);

    // Speed (includes timeout penalties)
    final double avgRt = reactionTimes.isEmpty
        ? timeoutPenaltyMs.toDouble()
        : reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;

    // 1200ms = fast, 25000ms = very slow
    final double rawSpeed = (1.0 - ((avgRt - 1200.0) / (timeoutPenaltyMs - 1200.0))).clamp(0.0, 1.0);

    // Speed only counts if perception was actually good (anti-guess / anti-random tapping)
    final double earnedSpeed = (rawSpeed * precision).clamp(0.0, 1.0);

    final double colorDiscrimination = precision;
    final double visualAcuity = (0.7 * precision + 0.3 * strictAccuracy).clamp(0.0, 1.0);
    final double patternRecognition = (0.6 * strictAccuracy + 0.4 * precision).clamp(0.0, 1.0);

    final double decisionUnderPressure = (0.8 * strictAccuracy + 0.2 * rawSpeed).clamp(0.0, 1.0);

    return {
      "Color Discrimination": colorDiscrimination,
      "Visual Acuity": visualAcuity,
      "Pattern Recognition": patternRecognition,
      "Information Processing Speed": earnedSpeed,
      "Decision Under Pressure": decisionUnderPressure,
    };
  }
}
