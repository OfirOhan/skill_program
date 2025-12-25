library blink_grading;

/// Pure grading logic for Blink Match
/// NO widget state, NO timers, NO UI

Map<String, double> gradeBlinkFromStats({
  required int targets,
  required int distractors,
  required int hits,
  required int falseAlarms,
  required List<int> hitReactionTimesMs,
  required double balancedAccFirstHalf,
  required double balancedAccSecondHalf,
}) {
  double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  if (targets <= 0 || distractors <= 0) {
    return {
      "Working Memory": 0.0,
      "Response Inhibition": 0.0,
      "Reaction Time (Choice)": 0.0,
      "Observation / Vigilance": 0.0,
    };
  }

  final double hitRate = hits / targets;
  final double specificity = (distractors - falseAlarms) / distractors;
  final double falseAlarmRate = falseAlarms / distractors;
  final double balancedAcc = (hitRate + specificity) / 2.0;

  final double workingMemory = clamp01(hitRate * specificity);
  final double responseInhibition = clamp01(1.0 - falseAlarmRate);

  double reactionTimeChoice = 0.0;
  if (hitReactionTimesMs.length >= 2) {
    final sorted = [...hitReactionTimesMs]..sort();
    final mid = sorted.length ~/ 2;
    final double medianMs = sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2.0;

    const double bestMs = 550.0;
    const double worstMs = 1500.0;

    final double raw =
    clamp01(1.0 - ((medianMs - bestMs) / (worstMs - bestMs)));

    reactionTimeChoice = clamp01(raw * balancedAcc);
  }

  final double vigilance = clamp01(
    (1.0 - (balancedAccFirstHalf - balancedAccSecondHalf).abs()) *
        balancedAcc,
  );

  // --- Engagement Gate ---
  final int engagement = hits + falseAlarms;
  final double minEngagement = targets * 0.3;
  final double engagementFactor =
  minEngagement > 0 ? clamp01(engagement / minEngagement) : 0.0;

  return {
    "Working Memory": workingMemory * engagementFactor,
    "Response Inhibition": responseInhibition * engagementFactor,
    "Reaction Time (Choice)": reactionTimeChoice * engagementFactor,
    "Observation / Vigilance": vigilance * engagementFactor,
  };
}
