
class RoleplayGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int totalCues,
    required List<bool> results,
    required List<int> reactionTimes,
    required List<bool> isSubtext, // true if CueType.subtext
  }) {
      if (totalCues == 0) {
          return {
            "Pragmatics": 0.0,
            "Social Context Awareness": 0.0,
            "Decision Under Pressure": 0.0,
            "Reading Comprehension Speed": 0.0,
          };
      }

      final int m = results.length.clamp(0, totalCues);
      final int correct = results.take(m).where((x) => x).length;
      final double accuracy = (correct / totalCues).clamp(0.0, 1.0);

      final double avgRt = reactionTimes.isEmpty
          ? 12000.0 // timeoutPenaltyMs
          : reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;

      // 1200ms fast, 12000ms slow
      final double rawSpeed = (1.0 - ((avgRt - 1200.0) / (12000.0 - 1200.0))).clamp(0.0, 1.0);
      final double earnedSpeed = (rawSpeed * accuracy).clamp(0.0, 1.0);

      int subN = 0, subC = 0;
      int nonSubN = 0, nonSubC = 0;

      for (int i = 0; i < totalCues && i < m; i++) {
          if (isSubtext[i]) {
              subN++;
              if (results[i]) subC++;
          } else {
              nonSubN++;
              if (results[i]) nonSubC++;
          }
      }

      final double subAcc = subN == 0 ? accuracy : (subC / subN).clamp(0.0, 1.0);
      final double nonSubAcc = nonSubN == 0 ? accuracy : (nonSubC / nonSubN).clamp(0.0, 1.0);

      final double pragmatics = subAcc;
      final double socialContext = nonSubAcc;
      final double decisionUnderPressure = (0.80 * accuracy + 0.20 * rawSpeed).clamp(0.0, 1.0);
      final double readingSpeed = earnedSpeed;

      return {
          "Pragmatics": pragmatics,
          "Social Context Awareness": socialContext,
          "Decision Under Pressure": decisionUnderPressure,
          "Reading Comprehension Speed": readingSpeed,
      };
  }
}
