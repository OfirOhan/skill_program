// grading/precision_grading.dart

import 'dart:math';

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

    // CLAMPED LINEAR WEIGHTED APPROACH:
    // 1. Clamp deviation: 0-25% maps to 1.0-0.0 (anything >25% = 0)
    // 2. Clamp off-path: 0-10% maps to 1.0-0.0 (anything >10% = 0)
    // 3. Apply weighted formula: weight_dev × dev_score + weight_off × off_score
    // 4. Only visuomotor gets completion bonus (goal achievement requires completion)
    //
    // Ratio: dev 25% / off 10% = 2.5:1 (deviation threshold is higher because
    // you will always have more deviation than off-path - it's continuous vs binary)

    // Clamp deviation to 0-25% range
    final deviationClamped = clamp01(1.0 - (meanDevNorm / 0.25));

    // Clamp off-path to 0-10% range
    final offPathClamped = clamp01(1.0 - (meanOffRate / 0.10));

    // Fine Motor Control: Balanced (60% precision, 40% stability)
    // NOT affected by completion - measures raw control ability
    final fineMotorControl = clamp01(
        0.60 * deviationClamped + 0.40 * offPathClamped
    );

    // Visuomotor Integration: Slightly favors precision, REQUIRES completion
    // Completion bonus: 0/3 = 50%, 2/3 = 90%, 3/3 = 110% (bonus!)
    final visuomotorBase = clamp01(
        0.55 * deviationClamped + 0.45 * offPathClamped
    );
    final completionBonus = 0.6 + 0.48 * completion;
    final visuomotorIntegration = clamp01(visuomotorBase * completionBonus);

    // Movement Steadiness: Heavily emphasizes staying on-path (80% stability)
    // NOT affected by completion - measures movement stability
    final movementSteadiness = clamp01(
        0.20 * deviationClamped + 0.80 * offPathClamped
    );

    // print("sum off-rate $sumOffRate");
    // print("sum dev $sumDevNorm");
    // print("fine motor: $fineMotorControl");
    // print("Visuomotor Integration: $visuomotorIntegration");
    // print("Movement Steadiness: $movementSteadiness");

    return {
      "Fine Motor Control": fineMotorControl,
      "Visuomotor Integration": visuomotorIntegration,
      "Movement Steadiness": movementSteadiness,
    };
  }
}