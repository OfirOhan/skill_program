library blink_grading;
import 'dart:math';

/// Pure grading logic for Blink Match
/// NO widget state, NO timers, NO UI

Map<String, double> gradeBlinkFromStats({
  required int targets,
  required int distractors,

  required int hits,
  required int falseAlarms,

  // --- split stats for vigilance ---
  required int firstHalfHits,
  required int firstHalfTargets,
  required int firstHalfCorrectRejections,
  required int firstHalfDistractors,

  required int secondHalfHits,
  required int secondHalfTargets,
  required int secondHalfCorrectRejections,
  required int secondHalfDistractors,

  required List<int> hitReactionTimesMs,
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

  // --- Global accuracy ---
  final hitRate = hits / targets;
  final specificity = (distractors - falseAlarms) / distractors;
  final falseAlarmRate = falseAlarms / distractors;
  final balancedAcc = (hitRate + specificity) / 2.0;


  final double workingMemory = clamp01(hitRate * sqrt(specificity));
  final responseInhibition = clamp01(1.0 - falseAlarmRate);

  // --- Reaction Time ---
  double reactionTimeChoice = 0.0;
  if (hitReactionTimesMs.length >= 2) {
    final sorted = [...hitReactionTimesMs]..sort();
    final mid = sorted.length ~/ 2;
    final medianMs = sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2.0;

    const bestMs = 550.0;
    const worstMs = 1500.0;

    final raw =
    clamp01(1.0 - ((medianMs - bestMs) / (worstMs - bestMs)));
    reactionTimeChoice = clamp01(raw * balancedAcc);
  }

  // --- Vigilance (derived, not injected) ---
  double ba1 = 0.0;
  double ba2 = 0.0;

  if (firstHalfTargets > 0 && firstHalfDistractors > 0) {
    ba1 = ((firstHalfHits / firstHalfTargets) +
        (firstHalfCorrectRejections / firstHalfDistractors)) /
        2.0;
  }

  if (secondHalfTargets > 0 && secondHalfDistractors > 0) {
    ba2 = ((secondHalfHits / secondHalfTargets) +
        (secondHalfCorrectRejections / secondHalfDistractors)) /
        2.0;
  }

  final diff = (ba1 - ba2).abs();

  // [FIX] Squaring the difference makes the metric tolerant of small
  // variance (1 error) while still punishing large fatigue drops.
  final stability = clamp01(1.0 - (diff * diff * 3.0));

  final vigilance = clamp01(stability * balancedAcc);

  // --- Engagement gate ---
  final engagement = hits + falseAlarms;
  final minEngagement = targets * 0.3;
  final engagementFactor =
  minEngagement > 0 ? clamp01(engagement / minEngagement) : 0.0;

  return {
    "Working Memory": workingMemory * engagementFactor,
    "Response Inhibition": responseInhibition * engagementFactor,
    "Reaction Time (Choice)": reactionTimeChoice * engagementFactor,
    "Observation / Vigilance": vigilance * engagementFactor,
  };
}
