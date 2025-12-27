import 'dart:math';

class PlanPushGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<int> earnedValues,
    required List<int> optimalValues,
    required List<int> submitRTs,
    required int overtimeErrors,
    required int underTimeErrors,
  }) {
      final int days = earnedValues.length;
      if (days == 0) {
          return {
            "Planning & Prioritization": 0.0,
            "Constraint Management": 0.0,
            "Risk Management": 0.0,
            "Decision Under Pressure": 0.0,
          };
      }

      double sumQuality = 0.0;
      for (int i = 0; i < days; i++) {
          final opt = max(1, optimalValues[i]);
          sumQuality += (earnedValues[i] / opt).clamp(0.0, 1.0);
      }
      final double avgQuality = (sumQuality / days).clamp(0.0, 1.0);

      final double constraintManagement = (1.0 - ((overtimeErrors * 0.75 + underTimeErrors * 0.25) / days)).clamp(0.0, 1.0);
      final double riskManagement = (1.0 - (overtimeErrors / days)).clamp(0.0, 1.0);

      final double avgRt = submitRTs.isEmpty ? 30000.0 : submitRTs.reduce((a, b) => a + b) / submitRTs.length;
      final double rawSpeed = (1.0 - ((avgRt - 4000.0) / 26000.0)).clamp(0.0, 1.0);
      final double decisionUnderPressure = (0.8 * avgQuality + 0.2 * rawSpeed).clamp(0.0, 1.0);

      return {
          "Planning & Prioritization": avgQuality,
          "Constraint Management": constraintManagement,
          "Risk Management": riskManagement,
          "Decision Under Pressure": decisionUnderPressure,
      };
  }
}
