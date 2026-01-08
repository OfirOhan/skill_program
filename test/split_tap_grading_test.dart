import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/split_tap_grading.dart';

void main() {
  const double eps = 0.05; // kept in case you want closeTo later

  Map<String, double> gradeHelper({
    required int leftTargets,
    required int leftDistractors,
    required int leftHitsT,
    required int leftCorrectRejections,
    required List<bool> leftTrialCorrect,
    required List<bool> leftTrialPostSwitch,
    required int postSwitchTrials,
    required int postSwitchCorrect,
    required int mathHits,
    required int mathWrongs,
  }) {
    final scores = SplitTapGrading.grade(
      leftTargets: leftTargets,
      leftDistractors: leftDistractors,
      leftHitsT: leftHitsT,
      leftCorrectRejections: leftCorrectRejections,
      leftTrialCorrect: leftTrialCorrect,
      leftTrialPostSwitch: leftTrialPostSwitch,
      postSwitchTrials: postSwitchTrials,
      postSwitchCorrect: postSwitchCorrect,
      mathHits: mathHits,
      mathWrongs: mathWrongs,
    );
    // print(scores); // Uncomment when debugging
    return scores;
  }

  group('SplitTapGrading – Spec-based behavioral tests', () {
    // =========================================================
    // 0. NO DATA / EDGE CASE
    // =========================================================
    test('No trials & no math → all scores zero', () {
      final scores = gradeHelper(
        leftTargets: 0,
        leftDistractors: 0,
        leftHitsT: 0,
        leftCorrectRejections: 0,
        leftTrialCorrect: const [],
        leftTrialPostSwitch: const [],
        postSwitchTrials: 0,
        postSwitchCorrect: 0,
        mathHits: 0,
        mathWrongs: 0,
      );

      expect(scores['Response Inhibition'], equals(0.0));
      expect(scores['Cognitive Flexibility'], equals(0.0));
      expect(scores['Instruction Adherence'], equals(0.0));
      expect(scores['Observation / Vigilance'], equals(0.0));
      expect(scores['Quantitative Reasoning'], equals(0.0));
    });

    // =========================================================
    // 1. DUAL-TASK HERO
    //
    // Very strong performance on BOTH streams:
    // - Visual: almost perfect hits + very few false alarms
    // - Switches: stays accurate after rule changes
    // - Math: high accuracy
    //
    // This is the "top ~5–10%" style performance. All scores should be
    // very high (around 0.9+), not just "slightly above average".
    // =========================================================
    test('Dual-task hero – consistently high on all skills', () {
      final scores = gradeHelper(
        leftTargets: 20,
        leftDistractors: 20,
        leftHitsT: 19, // 95% hits
        leftCorrectRejections: 19, // only 1 false alarm
        // 40 flashes: 30 correct, 10 wrong
        leftTrialCorrect: List<bool>.filled(30, true)
          ..addAll([true, true, false, true, true, false, true, false, true, false]),
        leftTrialPostSwitch: [
          // first 15 pre-switch, next 25 post-switch
          ...List<bool>.filled(15, false),
          ...List<bool>.filled(25, true),
        ],
        postSwitchTrials: 10,
        postSwitchCorrect: 9, // 90% on rule-changed trials
        mathHits: 27,
        mathWrongs: 3, // 90% math accuracy
      );

      final ri = scores['Response Inhibition']!;
      final cf = scores['Cognitive Flexibility']!;
      final ia = scores['Instruction Adherence']!;
      final ov = scores['Observation / Vigilance']!;
      final qr = scores['Quantitative Reasoning']!;

      // These are "elite" scores – should be clearly above 0.8–0.9
      expect(ri, greaterThan(0.85));
      expect(cf, greaterThan(0.8));
      expect(ia, greaterThan(0.8));
      expect(ov, greaterThan(0.8));
      expect(qr, greaterThan(0.9));

      // Sanity: nothing should exceed 1.0
      expect(ri, inInclusiveRange(0.0, 1.0));
      expect(cf, inInclusiveRange(0.0, 1.0));
      expect(ia, inInclusiveRange(0.0, 1.0));
      expect(ov, inInclusiveRange(0.0, 1.0));
      expect(qr, inInclusiveRange(0.0, 1.0));
    });

    // =========================================================
    // 2. TRIGGER-HAPPY TAPPER
    //
    // Player taps almost everything:
    // - High hits but huge false alarm rate
    // - Math is still very good
    //
    // Expect:
    // - Response Inhibition: very low (≈ 0.1 or below)
    // - Observation/Vigilance: low-ish
    // - Quantitative Reasoning: high (0.8+)
    // =========================================================
    test('Trigger-happy tapper – low inhibition, good math', () {
      final scores = gradeHelper(
        leftTargets: 20,
        leftDistractors: 20,
        leftHitsT: 18, // taps on almost every target
        leftCorrectRejections: 4, // 16 false alarms out of 20
        leftTrialCorrect: [
          // 40 trials, only ~60% correct
          ...List<bool>.filled(12, true),
          ...List<bool>.filled(8, false),
          ...List<bool>.filled(10, true),
          ...List<bool>.filled(10, false),
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(20, false),
          ...List<bool>.filled(20, true),
        ],
        postSwitchTrials: 8,
        postSwitchCorrect: 4, // meh post-switch
        mathHits: 24,
        mathWrongs: 6, // 80% math accuracy
      );

      final ri = scores['Response Inhibition']!;
      final ov = scores['Observation / Vigilance']!;
      final qr = scores['Quantitative Reasoning']!;

      // Inhibition should be near the floor
      expect(ri, lessThan(0.2));

      // Vigilance: not zero, but clearly below average
      expect(ov, lessThan(0.4));

      // Math reasoning: still solid
      expect(qr, greaterThan(0.75));
    });

    // =========================================================
    // 3. OVER-CAUTIOUS WATCHER
    //
    // Almost never taps:
    // - Very few false alarms (good inhibition)
    // - Many misses on targets (poor vigilance)
    // - Math decent
    //
    // Expect:
    // - Response Inhibition: high
    // - Observation/Vigilance: low-ish/mid
    // =========================================================
    test('Over-cautious watcher – great inhibition, poor vigilance', () {
      final scores = gradeHelper(
        leftTargets: 18,
        leftDistractors: 22,
        leftHitsT: 5,  // lots of misses
        leftCorrectRejections: 21, // almost never false alarms
        leftTrialCorrect: [
          // Roughly 60% correct overall (many misses)
          ...List<bool>.filled(10, true),
          ...List<bool>.filled(10, false),
          ...List<bool>.filled(10, true),
          ...List<bool>.filled(10, false),
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(15, false),
          ...List<bool>.filled(25, true),
        ],
        postSwitchTrials: 8,
        postSwitchCorrect: 5,
        mathHits: 20,
        mathWrongs: 8,
      );

      final ri = scores['Response Inhibition']!;
      final ov = scores['Observation / Vigilance']!;
      final qr = scores['Quantitative Reasoning']!;

      // Response Inhibition should be clearly above average
      expect(ri, greaterThan(0.7));

      // Vigilance is hurt by many misses → clearly below average
      expect(ov, lessThan(0.5));

      // Math roughly average
      expect(qr, closeTo(0.5, 0.15));
    });

    // =========================================================
    // 4. MATH STAR vs VISUAL STAR
    //
    // Same-ish visual performance, different math performance.
    // We expect Quantitative Reasoning to separate them, while
    // visual-related scores remain similar.
    // =========================================================
    test('Math star vs visual star – QuantReasoning splits them', () {
      // Player A: average-ish visuals, amazing math
      final scoresMathStar = gradeHelper(
        leftTargets: 18,
        leftDistractors: 18,
        leftHitsT: 13,
        leftCorrectRejections: 13,
        leftTrialCorrect: [
          ...List<bool>.filled(12, true),
          ...List<bool>.filled(4, false),
          ...List<bool>.filled(8, true),
          ...List<bool>.filled(6, false),
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(15, false),
          ...List<bool>.filled(15, true),
        ],
        postSwitchTrials: 6,
        postSwitchCorrect: 4,
        mathHits: 26,
        mathWrongs: 2, // ~93% accuracy
      );

      // Player B: same visuals, but math struggles (~55%)
      final scoresMathWeak = gradeHelper(
        leftTargets: 18,
        leftDistractors: 18,
        leftHitsT: 13,
        leftCorrectRejections: 13,
        leftTrialCorrect: [
          ...List<bool>.filled(12, true),
          ...List<bool>.filled(4, false),
          ...List<bool>.filled(8, true),
          ...List<bool>.filled(6, false),
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(15, false),
          ...List<bool>.filled(15, true),
        ],
        postSwitchTrials: 6,
        postSwitchCorrect: 4,
        mathHits: 15,
        mathWrongs: 12, // ~55% accuracy
      );

      final qrA = scoresMathStar['Quantitative Reasoning']!;
      final qrB = scoresMathWeak['Quantitative Reasoning']!;

      final riA = scoresMathStar['Response Inhibition']!;
      final riB = scoresMathWeak['Response Inhibition']!;
      final ovA = scoresMathStar['Observation / Vigilance']!;
      final ovB = scoresMathWeak['Observation / Vigilance']!;

      // Quant Reasoning should clearly distinguish them
      expect(qrA, greaterThan(qrB + 0.2));

      // Visual-related skills should be roughly similar (difference < 0.1)
      expect((riA - riB).abs(), lessThan(0.1));
      expect((ovA - ovB).abs(), lessThan(0.1));
    });

    // =========================================================
    // 5. FLEXIBLE vs RIGID SWITCHING
    //
    // Same baseline accuracy. One player adapts quickly after
    // rule changes; the other crashes on post-switch trials.
    //
    // We expect:
    // - Cognitive Flexibility(high) > Cognitive Flexibility(low) by ≥ 0.2
    // - Instruction Adherence similarly higher for flexible player
    // =========================================================
    test('Flexible vs rigid switching – Cognitive Flexibility & Instruction Adherence', () {
      // FLEXIBLE: baseline high, switch-only slightly lower
      final flexScores = gradeHelper(
        leftTargets: 16,
        leftDistractors: 16,
        leftHitsT: 14,
        leftCorrectRejections: 14,
        // 34 trials: very good baseline, good post-switch
        leftTrialCorrect: [
          ...List<bool>.filled(24, true), // pre-switch
          ...[true, true, true, true, true, true, true, false, true, false], // 8/10 post
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(22, false),
          ...List<bool>.filled(12, true),
        ],
        postSwitchTrials: 10,
        postSwitchCorrect: 8,
        mathHits: 20,
        mathWrongs: 5,
      );

      // RIGID: baseline high, but collapses on post-switch
      final rigidScores = gradeHelper(
        leftTargets: 16,
        leftDistractors: 16,
        leftHitsT: 14,
        leftCorrectRejections: 14,
        leftTrialCorrect: [
          ...List<bool>.filled(24, true), // pre-switch
          ...[false, false, true, false, false, false, true, false, false, false],
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(22, false),
          ...List<bool>.filled(12, true),
        ],
        postSwitchTrials: 10,
        postSwitchCorrect: 3,
        mathHits: 20,
        mathWrongs: 5,
      );

      final cfFlex = flexScores['Cognitive Flexibility']!;
      final cfRigid = rigidScores['Cognitive Flexibility']!;
      final iaFlex = flexScores['Instruction Adherence']!;
      final iaRigid = rigidScores['Instruction Adherence']!;

      // Flex player should be clearly higher
      expect(cfFlex, greaterThan(cfRigid + 0.2));
      expect(iaFlex, greaterThan(iaRigid + 0.2));
    });

    // =========================================================
    // 6. SUSTAINED VIGILANCE vs EARLY DROP-OFF
    //
    // Same overall accuracy, but different time pattern:
    // - Stable: roughly equal early & late.
    // - Drop-off: very good early, much worse late.
    //
    // We expect Observation/Vigilance(stable) > Observation/Vigilance(drop)
    // by at least 0.2.
    // =========================================================
    test('Sustained vigilance vs fatigue – Observation/Vigilance must separate patterns', () {
      // Stable accuracy: 70% correct across whole block
      final stableScores = gradeHelper(
        leftTargets: 15,
        leftDistractors: 15,
        leftHitsT: 11,
        leftCorrectRejections: 10,
        leftTrialCorrect: [
          ...[true, true, false, true, false, true, true, false, true, true],  // early 10
          ...[true, false, true, true, false, true, false, true, true, false], // late 10
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(10, false),
          ...List<bool>.filled(10, true),
        ],
        postSwitchTrials: 6,
        postSwitchCorrect: 4,
        mathHits: 18,
        mathWrongs: 7,
      );

      // Drop-off: 90% early, 50% late, overall still ~70%
      final dropScores = gradeHelper(
        leftTargets: 15,
        leftDistractors: 15,
        leftHitsT: 11,
        leftCorrectRejections: 10,
        leftTrialCorrect: [
          ...[true, true, true, true, true, true, true, true, true, false],      // early 10 (9/10)
          ...[true, false, true, false, false, true, false, true, false, false], // late 10 (5/10)
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(10, false),
          ...List<bool>.filled(10, true),
        ],
        postSwitchTrials: 6,
        postSwitchCorrect: 4,
        mathHits: 18,
        mathWrongs: 7,
      );

      final ovStable = stableScores['Observation / Vigilance']!;
      final ovDrop = dropScores['Observation / Vigilance']!;

      expect(ovStable, greaterThan(ovDrop + 0.2));
    });

    // =========================================================
    // 7. AVERAGE PLAYER ANCHOR
    //
    // Roughly 65–70% correct on both tasks, some FAs, some misses,
    // decent switches.
    //
    // This should hover around 0.5 on most skills.
    // =========================================================
    test('Average-ish performer should land near 0.5 on most skills', () {
      final scores = gradeHelper(
        leftTargets: 18,
        leftDistractors: 18,
        leftHitsT: 12,
        leftCorrectRejections: 12, // 6 FAs, 6 misses
        // 36 trials: 24 correct, 12 incorrect (~67%)
        leftTrialCorrect: [
          ...List<bool>.filled(24, true),
          ...List<bool>.filled(12, false),
        ],
        leftTrialPostSwitch: [
          ...List<bool>.filled(18, false),
          ...List<bool>.filled(18, true),
        ],
        postSwitchTrials: 8,
        postSwitchCorrect: 5, // ~62%
        mathHits: 19,
        mathWrongs: 9, // ~68% math accuracy
      );

      final ri = scores['Response Inhibition']!;
      final cf = scores['Cognitive Flexibility']!;
      final ia = scores['Instruction Adherence']!;
      final ov = scores['Observation / Vigilance']!;
      final qr = scores['Quantitative Reasoning']!;

      // Anchor: around 0.5 ± 0.15 for all
      expect(ri, inInclusiveRange(0.35, 0.65));
      expect(cf, inInclusiveRange(0.35, 0.65));
      expect(ia, inInclusiveRange(0.35, 0.65));
      expect(ov, inInclusiveRange(0.35, 0.65));
      expect(qr, inInclusiveRange(0.35, 0.65));
    });
  });
}
