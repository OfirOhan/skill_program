library blink_grading;

import 'dart:math';

/// Central grading logic used by BOTH Blink Match and N-Back.
Map<String, double> gradeBlinkFromStats({
  required List<bool> isTarget,
  required List<bool> userClaimed,
  required List<int> hitReactionTimesMs,
}) {
  double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  final int totalTrials = isTarget.length;
  if (totalTrials == 0) {
    return {
      "Working Memory": 0.0,
      "Response Inhibition": 0.0,
      "Reaction Time (Choice)": 0.0,
      "Observation / Vigilance": 0.0,
    };
  }

  // --- 1. Data Collection & Splitting ---
  int targets = 0, distractors = 0;
  int hits = 0, falseAlarms = 0, correctRejections = 0;

  final int split = totalTrials ~/ 2;
  int t1 = 0, d1 = 0, h1 = 0, cr1 = 0;
  int t2 = 0, d2 = 0, h2 = 0, cr2 = 0;

  for (int i = 0; i < totalTrials; i++) {
    final bool _isTarget = isTarget[i];
    final bool _claimed = userClaimed[i];
    final bool isFirstHalf = i < split;

    // Global counts
    if (_isTarget) {
      targets++;
      if (_claimed) hits++;
    } else {
      distractors++;
      if (_claimed) falseAlarms++; else correctRejections++;
    }

    // Split counts
    if (isFirstHalf) {
      if (_isTarget) { t1++; if (_claimed) h1++; }
      else { d1++; if (!_claimed) cr1++; }
    } else {
      if (_isTarget) { t2++; if (_claimed) h2++; }
      else { d2++; if (!_claimed) cr2++; }
    }
  }

  if (targets <= 0 || distractors <= 0) {
    return {
      "Working Memory": 0.0,
      "Response Inhibition": 0.0,
      "Reaction Time (Choice)": 0.0,
      "Observation / Vigilance": 0.0,
    };
  }

  // --- 2. Global Metrics ---
  final hitRate = hits / targets;
  final specificity = correctRejections / distractors;
  final falseAlarmRate = falseAlarms / distractors;
  final balancedAcc = (hitRate + specificity) / 2.0;

  // --- 3. Core Scores ---

  // Working Memory: HitRate * Sqrt(Specificity).
  final double workingMemory = clamp01(hitRate * sqrt(specificity));

  // Response Inhibition: Strictly purely about False Alarms.
  final double responseInhibition = clamp01(1.0 - falseAlarmRate);

  // --- 4. Vigilance (Stability) ---
  double observationVigilance = 0.0;

  if (t1 > 0 && d1 > 0 && t2 > 0 && d2 > 0) {
    final ba1 = ((h1 / t1) + (cr1 / d1)) / 2.0;
    final ba2 = ((h2 / t2) + (cr2 / d2)) / 2.0;

    final diff = (ba1 - ba2).abs();

    // Stability Formula: 1.0 - (Diff^2 * 3.0)
    final stability = clamp01(1.0 - (diff * diff * 3.0));
    observationVigilance = clamp01(stability * balancedAcc);
  }

  // --- 5. Reaction Time (Metric Purity) ---
  double reactionTimeChoice = 0.0;
  if (hitReactionTimesMs.length >= 2) {
    final sorted = [...hitReactionTimesMs]..sort();
    final mid = sorted.length ~/ 2;
    final medianMs = sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2.0;

    const bestMs = 550.0;
    const worstMs = 1500.0;

    final rawSpeed = clamp01(1.0 - ((medianMs - bestMs) / (worstMs - bestMs)));
    final validityFactor = sqrt(specificity);

    reactionTimeChoice = clamp01(rawSpeed * validityFactor);
  }

  // --- 6. Engagement Gate ---
  final engagement = hits + falseAlarms;
  final minEngagement = targets * 0.3;
  final engagementFactor = minEngagement > 0
      ? clamp01(engagement / minEngagement)
      : 0.0;

  return {
    "Working Memory": workingMemory * engagementFactor,
    "Response Inhibition": responseInhibition * engagementFactor,
    "Reaction Time (Choice)": reactionTimeChoice * engagementFactor,
    "Observation / Vigilance": observationVigilance * engagementFactor,
  };
}