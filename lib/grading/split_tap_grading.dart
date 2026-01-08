// lib/grading/split_tap_grading.dart
//
// Grading logic for the SplitTap game (dual-task: blink + math).
//
// Inputs (from game):
//  LEFT STREAM
//   - leftTargets, leftDistractors
//   - leftHitsT, leftCorrectRejections
//   - leftTrialCorrect[i]      : correctness per visual event
//   - leftTrialPostSwitch[i]   : whether this event is first after a rule change
//   - postSwitchTrials, postSwitchCorrect
//
//  RIGHT STREAM (math)
//   - mathHits, mathWrongs
//   - gameSeconds              : total game duration (for engagement)
//
// Output scores (0.0 – 1.0):
//   "Response Inhibition"
//   "Cognitive Flexibility"
//   "Instruction Adherence"
//   "Observation / Vigilance"
//   "Quantitative Reasoning"

import 'dart:math';

class SplitTapGrading {
  static Map<String, double> grade({
    // LEFT STREAM
    required int leftTargets,
    required int leftDistractors,
    required int leftHitsT,
    required int leftCorrectRejections,
    required List<bool> leftTrialCorrect,
    required List<bool> leftTrialPostSwitch,
    required int postSwitchTrials,
    required int postSwitchCorrect,

    // RIGHT STREAM (math)
    required int mathHits,
    required int mathWrongs,

    // GAME DURATION
    required double gameSeconds,
  }) {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    double mapAccuracyToSkill({
      required double accuracy,
      required double mid,
      required double spread,
    }) {
      if (spread <= 0) return clamp01(accuracy);
      final double raw = (accuracy - (mid - spread)) / (2 * spread);
      return clamp01(raw);
    }

    final int totalLeftTrials = leftTrialCorrect.length;
    final int mathTotal = mathHits + mathWrongs;

    // If literally nothing happened
    if (totalLeftTrials == 0 && mathTotal == 0) {
      return {
        "Response Inhibition": 0.0,
        "Cognitive Flexibility": 0.0,
        "Instruction Adherence": 0.0,
        "Observation / Vigilance": 0.0,
        "Quantitative Reasoning": 0.0,
      };
    }

    // Hidden engagement factor from math (0..1)
    final double mathEngagement = _computeMathEngagement(
      hits: mathHits,
      wrongs: mathWrongs,
      gameSeconds: gameSeconds,
      mapAccuracyToSkill: mapAccuracyToSkill,
    );

    // ------------- LEFT: OBSERVATION / VIGILANCE -------------

    final int totalTargets = max(leftTargets, 0);
    final int totalDistractors = max(leftDistractors, 0);

    final double hitRate =
    totalTargets > 0 ? leftHitsT / totalTargets : 0.0;
    final double crRate = totalDistractors > 0
        ? leftCorrectRejections / totalDistractors
        : 0.0;

    final double balancedAcc = (hitRate + crRate) / 2.0;

    double observationBase = mapAccuracyToSkill(
      accuracy: balancedAcc,
      mid: 0.75,  // ~75% balanced acc -> 0.5
      spread: 0.25, // 50% -> 0, 100% -> 1
    );

    // If you ignore math completely you can still get ~0.6 of the base.
    // Full engagement lets you reach the full base.
    double observationVigilance =
        observationBase * (0.6 + 0.4 * mathEngagement);
    observationVigilance = clamp01(observationVigilance);

    // ------------- LEFT: RESPONSE INHIBITION -------------

    int falseAlarms = 0;
    if (totalDistractors > 0) {
      falseAlarms = totalDistractors - leftCorrectRejections;
      if (falseAlarms < 0) falseAlarms = 0;
      if (falseAlarms > totalDistractors) {
        falseAlarms = totalDistractors;
      }
    }

    double responseInhibition;
    if (totalDistractors == 0) {
      responseInhibition = 0.0;
    } else {
      final double faRate =
      totalDistractors > 0 ? falseAlarms / totalDistractors : 0.0;

      // faRate = 0.0  -> 1.0
      // faRate = 0.2  -> ~0.5
      // faRate >= 0.4 -> 0.0
      double inhibitionBase = 1.0 - (faRate / 0.4);
      inhibitionBase = clamp01(inhibitionBase);

      // Inhibition is mostly left-stream driven; math has a small effect.
      responseInhibition =
          inhibitionBase * (0.8 + 0.2 * mathEngagement);
      responseInhibition = clamp01(responseInhibition);
    }

    // ------------- LEFT: INSTRUCTION ADHERENCE -------------

    double instructionAdherence;
    if (postSwitchTrials <= 0) {
      instructionAdherence = 0.0;
    } else {
      final double postAcc = postSwitchCorrect / postSwitchTrials;
      double adherenceBase = mapAccuracyToSkill(
        accuracy: postAcc,
        mid: 0.7,   // 70% on first-trials -> 0.5
        spread: 0.3,
      );

      // Here math matters more: if you drop math completely,
      // you can only reach half of what your visual behavior suggests.
      instructionAdherence =
          adherenceBase * (0.5 + 0.5 * mathEngagement);
      instructionAdherence = clamp01(instructionAdherence);
    }

    // ------------- LEFT: COGNITIVE FLEXIBILITY -------------

    double cognitiveFlexibility;
    if (postSwitchTrials <= 0 || totalLeftTrials == 0) {
      cognitiveFlexibility = 0.0;
    } else {
      final double leftAccuracy =
      totalLeftTrials > 0
          ? leftTrialCorrect.where((c) => c).length /
          totalLeftTrials
          : 0.0;

      int nonPostTotal = 0;
      int nonPostCorrect = 0;
      for (int i = 0; i < leftTrialCorrect.length; i++) {
        final bool isPost = (i < leftTrialPostSwitch.length)
            ? leftTrialPostSwitch[i]
            : false;
        if (!isPost) {
          nonPostTotal++;
          if (leftTrialCorrect[i]) nonPostCorrect++;
        }
      }

      final double preAcc = nonPostTotal > 0
          ? nonPostCorrect / nonPostTotal
          : leftAccuracy;

      final double postAcc = postSwitchTrials > 0
          ? postSwitchCorrect / postSwitchTrials
          : leftAccuracy;

      final double basePost = mapAccuracyToSkill(
        accuracy: postAcc,
        mid: 0.7,
        spread: 0.3,
      );

      // Switch cost = drop from pre to post.
      final double switchCost = max(0.0, preAcc - postAcc); // 0..1
      // 0.0 cost -> factor 1.0
      // 0.3 cost -> factor ~0.5
      final double costPenalty = clamp01(switchCost / 0.3);
      final double flexibilityFactor = 1.0 - 0.5 * costPenalty;

      double flexBase = clamp01(basePost * flexibilityFactor);

      // Flexibility is strongly dual-task; math has strong influence.
      cognitiveFlexibility =
          flexBase * (0.5 + 0.5 * mathEngagement);
      cognitiveFlexibility = clamp01(cognitiveFlexibility);
    }

    // ------------- RIGHT: QUANTITATIVE REASONING -------------

    final double quantitativeReasoning =
    _gradeQuantitativeReasoning(
      hits: mathHits,
      wrongs: mathWrongs,
      gameSeconds: gameSeconds,
      mapAccuracyToSkill: mapAccuracyToSkill,
    );

    return {
      "Response Inhibition": responseInhibition,
      "Cognitive Flexibility": cognitiveFlexibility,
      "Instruction Adherence": instructionAdherence,
      "Observation / Vigilance": observationVigilance,
      "Quantitative Reasoning": quantitativeReasoning,
    };
  }

  // ===================== HELPERS =====================

  /// Engagement factor used INTERNALLY (0..1),
  /// combining math speed and math accuracy.
  static double _computeMathEngagement({
    required int hits,
    required int wrongs,
    required double gameSeconds,
    required double Function({
    required double accuracy,
    required double mid,
    required double spread,
    })
    mapAccuracyToSkill,
  }) {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    final int total = hits + wrongs;
    if (total <= 0 || gameSeconds <= 0) return 0.0;

    final double rate = total / gameSeconds; // attempts per second
    final double acc = hits / total;

    // Rate scoring:
    //   ~0.2/sec (~6 q in 30s)  -> near 0
    //   ~0.6/sec (~18 in 30s)   -> ~0.5
    //   ~1.0/sec (~30 in 30s)   -> near 1
    final double rateScore = mapAccuracyToSkill(
      accuracy: rate,
      mid: 0.6,
      spread: 0.4,
    );

    // Accuracy scoring:
    //   <= 40%    -> ~0
    //   70%       -> ~0.5
    //   >= 100%   -> ~1
    final double accScore = mapAccuracyToSkill(
      accuracy: acc,
      mid: 0.7,
      spread: 0.3,
    );

    // Combine: both need to be decent.
    final double engagement = sqrt(rateScore * accScore);
    return clamp01(engagement);
  }

  /// Quantitative Reasoning from math only.
  /// Accuracy is the main component, speed is a smaller bonus.
  static double _gradeQuantitativeReasoning({
    required int hits,
    required int wrongs,
    required double gameSeconds,
    required double Function({
    required double accuracy,
    required double mid,
    required double spread,
    })
    mapAccuracyToSkill,
  }) {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    final int total = hits + wrongs;
    if (total <= 0 || gameSeconds <= 0) return 0.0;

    final double acc = hits / total;
    final double rate = total / gameSeconds;

    final double accScore = mapAccuracyToSkill(
      accuracy: acc,
      mid: 0.7,
      spread: 0.3,
    );

    // Same rate scoring as engagement, but weaker weight
    final double rateScore = mapAccuracyToSkill(
      accuracy: rate,
      mid: 0.6,
      spread: 0.4,
    );

    // 70% weight on accuracy, 30% on speed
    final double combined = 0.7 * accScore + 0.3 * rateScore;
    return clamp01(combined);
  }
}
