// lib/grading/split_tap_grading.dart
//
// Grading logic for the SplitTap game (dual-task: blink + easy math).
//
// Math here is a *distractor*, not a true quant reasoning test.
// It only affects other skills via an internal "math engagement" factor.
//
// Inputs (from game):
//  LEFT STREAM
//   - leftTargets, leftDistractors
//   - leftHitsT, leftCorrectRejections
//   - leftTrialCorrect[i]       : correctness per visual event
//   - leftTrialPostSwitch[i]    : whether this event is the FIRST blink
//                                 after a rule change
//   - leftTrialRuleConflict[i]  : true if this blink color matches
//                                 *old* rule but not new rule (true conflict)
//
//   NOTE: In grading we internally extend this to a 2-blink window:
//         first blink (weight 0.7) + second blink (weight 0.3).
//
//  RIGHT STREAM (math)
//   - mathHits, mathWrongs
//
// Output scores (0.0 – 1.0):
//   "Response Inhibition"
//   "Cognitive Flexibility"
//   "Instruction Adherence"
//   "Observation / Vigilance"
//
// NOTE: No Quantitative Reasoning here – math is not strong enough for that.

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
    required List<bool> leftTrialRuleConflict,

    // RIGHT STREAM (math)
    required int mathHits,
    required int mathWrongs,
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

    // If we have no left-stream data, we *cannot* measure these 4 skills.
    if (totalLeftTrials == 0) {
      return {
        "Response Inhibition": 0.0,
        "Cognitive Flexibility": 0.0,
        "Instruction Adherence": 0.0,
        "Observation / Vigilance": 0.0,
      };
    }

    // ---------- build a 2-blink post-switch window mask ----------
    //
    // isPostWindow[i] = true if blink i is either:
    //   - the first blink after a switch (leftTrialPostSwitch[i] == true), OR
    //   - the second blink after that switch (i == firstIndex + 1).
    //
    final List<bool> isPostWindow =
    List<bool>.filled(totalLeftTrials, false);

    for (int i = 0; i < leftTrialPostSwitch.length; i++) {
      if (leftTrialPostSwitch[i]) {
        // first blink after switch
        if (i < totalLeftTrials) {
          isPostWindow[i] = true;
        }
        // second blink after switch (if exists)
        final int secondIdx = i + 1;
        if (secondIdx < totalLeftTrials) {
          isPostWindow[secondIdx] = true;
        }
      }
    }
    // -----------------------------------------------------------------

    // Internal math engagement = "did you actually do the easy math
    // and were you at least above pure guessing?"
    final double mathEngagement = _computeMathEngagement(
      hits: mathHits,
      wrongs: mathWrongs,
    );

    // ----------------- BASIC LEFT-STREAM RATES -----------------

    final int totalTargets = max(leftTargets, 0);
    final int totalDistractors = max(leftDistractors, 0);

    final double hitRate =
    totalTargets > 0 ? leftHitsT / totalTargets : 0.0;
    final double crRate = totalDistractors > 0
        ? leftCorrectRejections / totalDistractors
        : 0.0;

    final double balancedAcc =
        (hitRate + crRate) / 2.0; // (currently unused, but OK to keep)

    // We also need false alarms + response count for some skills
    int falseAlarms = 0;
    if (totalDistractors > 0) {
      falseAlarms = totalDistractors - leftCorrectRejections;
      if (falseAlarms < 0) falseAlarms = 0;
      if (falseAlarms > totalDistractors) falseAlarms = totalDistractors;
    }
    final int totalResponses = leftHitsT + falseAlarms;

    // For guards on "do we even have any switches"
    int postSwitchCount = 0;
    for (int i = 0; i < leftTrialPostSwitch.length; i++) {
      if (leftTrialPostSwitch[i]) postSwitchCount++;
    }

    // ----------------- OBSERVATION / VIGILANCE -----------------

    double obsHit = hitRate;

    // Map only CR / FA into a "difficulty adjusted" term.
    double crSkill = mapAccuracyToSkill(
      accuracy: crRate,
      mid: 0.7,
      spread: 0.3,
    );

    // Blend: 60% from raw hitRate, 40% from mapped CR-skill.
    double observationBase = 0.6 * obsHit + 0.4 * crSkill;

    // Dual-task factor:
    //  mathEngagement = 0   -> factor 0.6 (still “good” if blinks are strong)
    //  mathEngagement = 1   -> factor 1.0
    double observationVigilance =
        observationBase * (0.6 + 0.4 * mathEngagement);
    observationVigilance = clamp01(observationVigilance);

    // ----------------- RESPONSE INHIBITION -----------------

    double responseInhibition;
    if (totalDistractors == 0) {
      responseInhibition = 0.0;
    } else {
      final double faRate =
      totalDistractors > 0 ? falseAlarms / totalDistractors : 0.0;

      // faRate = 0     -> base 1.0
      // faRate = 0.6   -> base ~0.0 (you chose this threshold)
      double inhibitionBase = 1.0 - (faRate / 0.6);
      inhibitionBase = clamp01(inhibitionBase);

      // Activity factor to penalize AFK:
      // 0 taps  -> 0
      // 3+ taps -> 1
      double activity = 0.0;
      if (totalResponses > 0) {
        activity = clamp01(totalResponses / 3.0);
      }

      // Combine:
      //  - 40% baseline from visual stream alone
      //  - +40% from mathEngagement
      //  - +20% from activity (to kill pure AFK cases)
      final double dualFactor =
          0.4 + 0.4 * mathEngagement + 0.2 * activity;

      responseInhibition = clamp01(inhibitionBase * dualFactor);
    }

    // ----------------- INSTRUCTION ADHERENCE -----------------

    double instructionAdherence;
    if (postSwitchCount == 0) {
      instructionAdherence = 0.0;
    } else {
      double weightedCorrect = 0.0;
      double totalWeight = 0.0;

      for (int i = 0; i < leftTrialCorrect.length; i++) {
        final bool inPostWindow =
        (i < isPostWindow.length) ? isPostWindow[i] : false;
        if (!inPostWindow) continue;

        final bool isCorrect = leftTrialCorrect[i];
        final bool isConflict = (i < leftTrialRuleConflict.length)
            ? leftTrialRuleConflict[i]
            : false;

        // Base weight: conflict trials count heavier.
        final double baseW = isConflict ? 1.5 : 1.0;

        // First vs second blink weight.
        final bool isFirstPost = (i < leftTrialPostSwitch.length)
            ? leftTrialPostSwitch[i]
            : false;
        final bool isSecondPost = !isFirstPost && inPostWindow;

        final double windowFactor = isFirstPost ? 0.7 : 0.3;
        final double w = baseW * windowFactor;

        totalWeight += w;
        if (isCorrect) {
          weightedCorrect += w;
        }
      }

      final double postWeightedAcc =
      totalWeight > 0 ? (weightedCorrect / totalWeight) : 0.0;

      double adherenceBase = mapAccuracyToSkill(
        accuracy: postWeightedAcc,
        mid: 0.55,
        spread: 0.4,
      );

      // Strong dual-task dependency:
      //  mathEngagement = 0 -> factor 0.6
      //  mathEngagement = 1 -> factor 1.0
      instructionAdherence =
          adherenceBase * (0.6 + 0.4 * mathEngagement);
      instructionAdherence = clamp01(instructionAdherence);
    }

    // ----------------- COGNITIVE FLEXIBILITY -----------------

    double cognitiveFlexibility;
    if (postSwitchCount == 0) {
      cognitiveFlexibility = 0.0;
    } else {
      int nonPostTotal = 0;
      int nonPostCorrect = 0;

      // "pre" = any trial NOT in the 2-blink post window
      for (int i = 0; i < leftTrialCorrect.length; i++) {
        final bool inPostWindow =
        (i < isPostWindow.length) ? isPostWindow[i] : false;
        if (!inPostWindow) {
          nonPostTotal++;
          if (leftTrialCorrect[i]) {
            nonPostCorrect++;
          }
        }
      }

      final double preAcc = nonPostTotal > 0
          ? nonPostCorrect / nonPostTotal
          : (leftTrialCorrect.where((c) => c).length / totalLeftTrials);

      // Post-switch weighted accuracy (same logic as adherence, 0.6/0.4 weights),
      // and also plain post accuracy for the pre-vs-post comparison.
      double weightedCorrect = 0.0;
      double totalWeight = 0.0;
      int postPlainTotal = 0;    // NEW: plain post count
      int postPlainCorrect = 0;  // NEW: plain post correct

      for (int i = 0; i < leftTrialCorrect.length; i++) {
        final bool inPostWindow =
        (i < isPostWindow.length) ? isPostWindow[i] : false;
        if (!inPostWindow) continue;

        postPlainTotal++; // NEW: count every post-window trial

        final bool isCorrect = leftTrialCorrect[i];
        final bool isConflict = (i < leftTrialRuleConflict.length)
            ? leftTrialRuleConflict[i]
            : false;

        // CHANGED: conflict base weight = 1.5 (so first conflict blink ≈ 0.9)
        final double baseW = isConflict ? 1.5 : 1.0; // CHANGED

        final bool isFirstPost = (i < leftTrialPostSwitch.length)
            ? leftTrialPostSwitch[i]
            : false;
        final bool isSecondPost = !isFirstPost && inPostWindow;

        final double windowFactor = isFirstPost ? 0.6 : 0.4;
        final double w = baseW * windowFactor;

        totalWeight += w;
        if (isCorrect) {
          weightedCorrect += w;
          postPlainCorrect++; // NEW: plain correct count
        }
      }

      final double postWeightedAcc =
      totalWeight > 0 ? (weightedCorrect / totalWeight) : 0.0;

      // NEW: plain (unweighted) post accuracy for delta
      final double postAccPlain =
      postPlainTotal > 0 ? (postPlainCorrect / postPlainTotal) : 0.0; // NEW

      // Base on *post* performance (still uses weighted accuracy).
      double basePost = mapAccuracyToSkill(
        accuracy: postWeightedAcc,
        mid: 0.55,
        spread: 0.4,
      );

      // ---- Switch effect: ratio-based around pre vs post (multiplicative) ----
      //
      // r = postAccPlain / preAcc
      //
      // We want:
      //   - r = 1.0       -> max bonus:      factor = 1.25
      //   - r >= 2.0      -> no extra bonus: factor = 1.0
      //   - r = 0.8       -> neutral:        factor = 1.0
      //   - r <= 0.5      -> max penalty:    factor = 0.8
      //
      // So:
      //   - [1.0, 2.0]   : 1.25 -> 1.0  (improvement, bonus shrinks)
      //   - [0.8, 1.0]   : 1.0  -> 1.25 (small drop/near same, still bonus)
      //   - [0.5, 0.8]   : 0.8  -> 1.0  (real drop, punishment)
      const double maxBonus   = 1.2;
      const double minPenalty = 0.8;
      const double maxRatio   = 2.0;
      const double minRatio   = 0.5;   // pre twice better than post = max penalty
      const double neutralR   = 0.8;   // below this, we start penalizing

      double flexibilityFactor;
      if (preAcc <= 0.0) {
        // No meaningful baseline -> stay neutral.
        flexibilityFactor = 1.0;
      } else {
        final double rawRatio = postAccPlain / preAcc;

        if (rawRatio >= 1.0) {
          // Same or better after switch: r in [1, maxRatio]
          final double r = rawRatio.clamp(1.0, maxRatio);
          final double t = (r - 1.0) / (maxRatio - 1.0); // 0..1
          // t = 0 -> factor = maxBonus (1.25)
          // t = 1 -> factor = 1.0
          flexibilityFactor = maxBonus - (maxBonus - 1.0) * t;
        } else {
          // Worse after switch: r in [minRatio, 1)
          final double r = rawRatio.clamp(minRatio, 1.0);

          if (r >= neutralR) {
            // Mild drop: r in [0.8, 1) -> from 1.0 up to 1.25
            final double t = (r - neutralR) / (1.0 - neutralR); // 0..1
            // r = 0.8 -> factor = 1.0
            // r → 1   -> factor → 1.25
            flexibilityFactor = 1.0 + (maxBonus - 1.0) * t;
          } else {
            // Real punishment region: r in [minRatio, 0.8)
            final double t = (r - minRatio) / (neutralR - minRatio); // 0..1
            // r = minRatio (0.5) -> factor = minPenalty (0.8)
            // r = 0.8            -> factor = 1.0
            flexibilityFactor = minPenalty + (1.0 - minPenalty) * t;
          }
        }
      }

      // ----------------------------------------------------------------


      double flexBase = clamp01(basePost * flexibilityFactor);

      // Dual-task factor like adherence
      cognitiveFlexibility =
          flexBase * (0.6 + 0.4 * mathEngagement);
      cognitiveFlexibility = clamp01(cognitiveFlexibility);
    }

    return {
      "Response Inhibition": responseInhibition,
      "Cognitive Flexibility": cognitiveFlexibility,
      "Instruction Adherence": instructionAdherence,
      "Observation / Vigilance": observationVigilance,
    };
  }

  // ===================== HELPERS =====================

  // Engagement: non-linear, depends on attempts AND accuracy.
  //
  // Rules:
  //  - 0 attempts      -> 0
  //  - 5 attempts      -> attemptsScore = 0.5
  //  - 16+ attempts    -> attemptsScore = 1.0
  //  - If accuracy <= 0.4 (≈ spam guessing) -> 0, no matter attempts.
  //  - Else: engagement = attemptsScore * sqrt(accuracy)
  static double _computeMathEngagement({
    required int hits,
    required int wrongs,
  }) {
    double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

    final int total = hits + wrongs;
    if (total <= 0) return 0.0;

    final double accuracy = hits / total.toDouble();

    // Below or equal to 40% accuracy -> no engagement credit (spammer).
    if (accuracy <= (0.4)) {
      return 0.0;
    }

    final double attempts = total.toDouble();
    double attemptsScore;

    if (attempts <= 0.0) {
      attemptsScore = 0.0;
    } else if (attempts <= 5.0) {
      // Ramp up quickly at the beginning: 0..5 -> 0..0.5
      attemptsScore = 0.5 * (attempts / 5.0);
    } else if (attempts >= 16.0) {
      // Cap at full credit from 16 attempts and up
      attemptsScore = 1.0;
    } else {
      // Between 5 and 16 attempts: 0.5..1.0
      // 5  -> 0.5
      // 16 -> 1.0
      attemptsScore = 0.5 + 0.5 * ((attempts - 5.0) / 11.0);
    }

    // Accuracy always matters (above threshold), but sublinearly:
    //  acc = 1.0 -> factor 1.0
    //  acc = 0.5 -> factor ~0.707
    //  acc = 0.36 -> factor 0.6
    final double accFactor = sqrt(accuracy);

    return clamp01(attemptsScore * accFactor);
  }
}
