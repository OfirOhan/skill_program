// grading/color_cascade_grading.dart

class ColorCascadeGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<bool> roundPerfect,
    required List<double> roundPrecision,
    required List<int> reactionTimes,
    required int timeoutPenaltyMs,
  }) {
    if (roundPrecision.isEmpty) {
      return {
        "Color Discrimination": 0.0,
        "Visual Acuity": 0.0,
      };
    }

    // Round difficulty values
    // Round 1 (Sort): 0.28
    // Round 2 (3% diff): 0.28
    // Round 3 (1.5% diff): 0.3
    // Round 4 (1.0% diff): 0.3 (bonus)
    // Total possible: 1.13 (clamps to 1.0)
    final List<double> roundValues = [0.28, 0.28, 0.3, 0.3];

    // Calculate raw scores with per-round data (100% accurate)
    double rawPrecision = 0.0;
    double rawStrict = 0.0;

    for (int i = 0; i < roundPrecision.length && i < roundValues.length; i++) {
      // Add weighted precision for this round
      rawPrecision += roundPrecision[i] * roundValues[i];

      // Add weighted strict for this round if it was perfect
      if (i < roundPerfect.length && roundPerfect[i]) {
        rawStrict += roundValues[i];
      }
    }

    // === SKILL MEASUREMENTS ===

    // COLOR DISCRIMINATION (0.0 - 1.0)
    // Direct measure of perceptual ability to detect color differences
    // Includes partial credit from sorting attempts
    final double colorDiscrimination = rawPrecision.clamp(0.0, 1.0);

    // VISUAL ACUITY (0.0 - 1.0)
    // Combines perceptual sensitivity (60%) with perfect performance (40%)
    // Rewards both seeing differences AND getting them consistently right
    // Perfect rounds get a 1.2x bonus to emphasize sharpness/consistency
    final double visualAcuity = (0.6 * rawPrecision + 0.4 * rawStrict * 1.15).clamp(0.0, 1.0);

    return {
      "Color Discrimination": colorDiscrimination,
      "Visual Acuity": visualAcuity,
    };
  }
}