
class PrecisionGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int metricLevels,
    required int levelsCompleted,
    required double sumOffRate,
    required double sumDevNorm,
  }) {
      if (metricLevels == 0) {
          return {
            "Fine Motor Control": 0.0,
            "Visuomotor Integration": 0.0,
            "Movement Steadiness": 0.0,
          };
      }

      final completion = (levelsCompleted / 3.0).clamp(0.0, 1.0);
      final meanOffRate = (sumOffRate / metricLevels).clamp(0.0, 1.0);
      final meanDevNorm = (sumDevNorm / metricLevels).clamp(0.0, 1.0);

      final trackingQuality = (1.0 - (0.55 * meanDevNorm + 0.45 * meanOffRate)).clamp(0.0, 1.0);
      final steadiness = (1.0 - (0.75 * meanDevNorm + 0.25 * meanOffRate)).clamp(0.0, 1.0);

      final fineMotorControl = trackingQuality;
      final visuomotorIntegration = (trackingQuality * completion).clamp(0.0, 1.0);
      final movementSteadiness = steadiness;

      return {
          "Fine Motor Control": fineMotorControl,
          "Visuomotor Integration": visuomotorIntegration,
          "Movement Steadiness": movementSteadiness,
      };
  }
}
