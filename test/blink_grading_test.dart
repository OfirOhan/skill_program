import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/blink_grading.dart';

void main() {
  group('Blink Match Grading – Deterministic Tests', () {
    test('Perfect player', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 0,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(7, 550),
      );

      expect(scores["Working Memory"], equals(1.0));
      expect(scores["Response Inhibition"], equals(1.0));
      expect(scores["Reaction Time (Choice)"], equals(1.0));
      expect(scores["Observation / Vigilance"], equals(1.0));
    });

    test('Single false alarm', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 1,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 4, // 1 error here
        firstHalfDistractors: 5,

        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(7, 600),
      );

      expect(scores["Response Inhibition"], lessThan(1.0));
      expect(scores["Response Inhibition"], greaterThan(0.85));
      expect(
        scores["Response Inhibition"]!,
        lessThan(scores["Working Memory"]!),
        reason: 'RI (error penalty) should be stricter than WM (hit reward) for a single slip',
      );
      expect(
        scores["Response Inhibition"]!,
        lessThan(scores["Observation / Vigilance"]!),
        reason: 'RI should be lower than Vigilance for a single impulse error',
      );
    });

    test('Passive player (no engagement)', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 0,
        falseAlarms: 0,

        firstHalfHits: 0,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 0,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: [],
      );

      scores.forEach((_, v) => expect(v, equals(0.0)));
    });

    test('Spammer (presses everything)', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 11,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 0,
        firstHalfDistractors: 5,

        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 0,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(7, 450),
      );

      expect(scores["Response Inhibition"], equals(0.0));
      expect(scores["Working Memory"], equals(0.0));
    });

    test('Fatigue effect only hurts vigilance', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 6,
        falseAlarms: 2,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5, // Perfect start
        firstHalfDistractors: 5,

        secondHalfHits: 2, // Missed 1
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 4, // 2 False Alarms here
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(6, 700),
      );

      expect(
        scores["Observation / Vigilance"],
        lessThan(scores["Working Memory"]!),
      );
    });

    test('Engagement threshold works', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 2,
        falseAlarms: 0,

        firstHalfHits: 1,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 1,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: [800, 820],
      );

      expect(scores["Working Memory"], lessThan(0.5));
    });
  });

  group('Blink Match Grading – Invariants', () {
    test('Increasing FA never increases RI', () {
      final lowFA = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,

        firstHalfHits: 3,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 4,
        firstHalfDistractors: 5,

        secondHalfHits: 2,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(5, 650),
      );

      final highFA = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 5,

        firstHalfHits: 3,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 0, // 5 errors
        firstHalfDistractors: 5,

        secondHalfHits: 2,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(5, 650),
      );

      expect(
        highFA["Response Inhibition"],
        lessThanOrEqualTo(lowFA["Response Inhibition"]!),
      );
    });

    test('Better RT never reduces RT score', () {
      final slow = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,

        firstHalfHits: 3,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 4,
        firstHalfDistractors: 5,

        secondHalfHits: 2,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(5, 1200),
      );

      final fast = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,

        firstHalfHits: 3,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 4,
        firstHalfDistractors: 5,

        secondHalfHits: 2,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(5, 600),
      );

      expect(
        fast["Reaction Time (Choice)"],
        greaterThanOrEqualTo(slow["Reaction Time (Choice)"]!),
      );
    });
  });

  group('Blink Match Grading – Logical Scenarios', () {
    test('Scenario: "The Impulsive" vs "The Inattentive"', () {
      // IMPULSIVE: Hits all 7 targets, but has 3 False Alarms
      final impulsive = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 3,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 3, // 2 FAs
        firstHalfDistractors: 5,

        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 5, // 1 FA
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(7, 500),
      );

      // INATTENTIVE: Misses 2 targets, but 0 False Alarms
      final inattentive = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 0,

        firstHalfHits: 3, // Missed 1
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 2, // Missed 1
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(5, 700),
      );

      // 1. The Inattentive player has better self-control (RI)
      expect(
          inattentive["Response Inhibition"],
          greaterThan(impulsive["Response Inhibition"]!),
          reason: "Player with 0 false alarms must have better Inhibition than one with 3 errors."
      );

      // 2. The Impulsive player has better Working Memory (found all targets)
      expect(
          impulsive["Working Memory"],
          greaterThan(inattentive["Working Memory"]!),
          reason: "Player who found all targets demonstrated better retention of 'what to look for', despite being messy."
      );
    });

    test('Scenario: "The Late Crasher" (Vigilance Logic)', () {
      // CONSISTENT: Hits 2 in first half, 2 in second half (Total 4)
      final consistent = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 4,
        falseAlarms: 0,

        firstHalfHits: 2,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 2,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(4, 600),
      );

      // CRASHER: Hits 4 in first half (Perfect), 0 in second half (Total 4)
      final crasher = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 4,
        falseAlarms: 0,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 0,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(4, 600),
      );

      expect(
          consistent["Observation / Vigilance"],
          greaterThan(crasher["Observation / Vigilance"]!),
          reason: "A player who crashes in the second half has poor vigilance compared to a stable player."
      );
    });

    test('Scenario: "Speed is Nothing Without Control"', () {
      // RUSHER: Fast (400ms) but only 3 hits (Missed 4)
      final rusher = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 3,
        falseAlarms: 0,

        firstHalfHits: 2,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 1,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(3, 400),
      );

      // STEADY: Average (700ms) but hits all 7
      final steady = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 0,

        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: List.filled(7, 700),
      );

      expect(
          steady["Reaction Time (Choice)"],
          greaterThan(rusher["Reaction Time (Choice)"]!),
          reason: "Fast reaction time is useless if accuracy is low. The score should reflect 'Effective' RT."
      );
    });

    test('Scenario: "The Sleeper" (Misses do not hurt Inhibition)', () {
      // To test pure Inhibition logic, we give enough hits to pass engagement (3 hits),
      // but keep False Alarms at 0.
      final minimalEffort = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 3,
        falseAlarms: 0,

        firstHalfHits: 2,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,

        secondHalfHits: 1,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,

        hitReactionTimesMs: [800, 800, 800],
      );

      expect(
          minimalEffort["Response Inhibition"],
          equals(1.0),
          reason: "If False Alarms are 0, Response Inhibition should be perfect regardless of how many targets were missed."
      );
    });
  });
  group('Blink Match Grading – Edge Cases & Constraints', () {

    test('Edge Case: Median Robustness (One terrible click shouldn\'t kill score)', () {
      // Logic: Median filtering is used to ignore outliers.
      // A player with 6 fast clicks and 1 sneeze (5000ms) should score
      // almost identical to a perfect player.

      final consistentPlayer = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: [550, 550, 550, 550, 550, 550, 550], // All perfect
      );

      final outlierPlayer = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        // 6 perfect clicks, 1 massive outlier (5000ms)
        hitReactionTimesMs: [550, 550, 550, 5000, 550, 550, 550],
      );

      // The scores should be identical because the median (550) is the same.
      // If you used 'Mean/Average', the outlierPlayer would fail.
      expect(
          outlierPlayer["Reaction Time (Choice)"],
          equals(consistentPlayer["Reaction Time (Choice)"]),
          reason: "The grading must use Median RT to be robust against single outliers (sneezes/distractions)."
      );
    });

    test('Edge Case: The "Lucky Guesser" Penalty (Sqrt constricts WM)', () {
      // Logic: A player hits 100% of targets (7/7) but has 5 False Alarms.
      // Specificity is 6/11 (~0.54).
      // Linear Math: 1.0 * 0.54 = 0.54
      // Sqrt Math:   1.0 * sqrt(0.54) = ~0.73
      //
      // This test ensures we are NOT being too lenient, but also not linear.
      // We want to ensure Working Memory is strictly penalized by the lack of specificity.

      final luckyGuesser = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 5,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 2, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 4, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 600),
      );

      // They found all targets, so WM > 0.5
      expect(luckyGuesser["Working Memory"], greaterThan(0.5));
      // But they guessed a lot, so it MUST be significantly less than 1.0
      expect(luckyGuesser["Working Memory"], lessThan(0.8));

      // Crucially, WM (0.73) must be higher than RI (0.54)
      // Because they DID remember the target, they just lacked control.
      expect(
          luckyGuesser["Working Memory"],
          greaterThan(luckyGuesser["Response Inhibition"]!),
          reason: "High hits + High FAs should punish RI more than WM."
      );
    });

    test('Edge Case: Natural Variance vs True Fatigue', () {
      // Player A: 4 hits first half, 3 hits second half. (Natural variance of odd numbers)
      // Player B: 4 hits first half, 1 hit second half. (True Fatigue drop)

      final naturalVariance = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 600),
      );

      final fatigueDrop = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 5, falseAlarms: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(5, 600),
      );

      // Natural variance (4 vs 3) should result in basically perfect Vigilance (~1.0)
      expect(naturalVariance["Observation / Vigilance"], closeTo(1.0, 0.05));

      // Fatigue drop (4 vs 1) is a 75% drop in hit rate for that half.
      // Vigilance should be significantly punished.
      expect(
          fatigueDrop["Observation / Vigilance"],
          lessThan(naturalVariance["Observation / Vigilance"]! - 0.3), // At least 30% worse
          reason: "A drop from 100% to 33% hit rate must be penalized as fatigue."
      );
    });

    test('Edge Case: The "Lazy Clicker" (Engagement Scaling)', () {
      // Logic: A player plays perfectly but only clicks twice.
      // Hits: 2/7. FA: 0.
      // Accuracy is High (100% of clicks were correct).
      // RT is Good.
      // BUT 'Engagement' factor should scale everything down.

      final lazyPlayer = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 2, falseAlarms: 0,
        firstHalfHits: 1, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: [550, 550],
      );

      // Min Engagement is 30% of 7 targets = 2.1.
      // They engaged 2 times. 2 < 2.1.
      // Factor is 2 / 2.1 = ~0.95.

      // If we didn't have engagement factor, WM would be ~0.28 (2/7).
      // With engagement factor, it shouldn't change much for WM (since hits are low anyway).

      // Let's look at RI.
      // Raw RI = 1.0 (No errors).
      // But because they didn't engage enough, their RI score should be reduced.
      expect(
          lazyPlayer["Response Inhibition"],
          lessThan(1.0),
          reason: "Perfect accuracy should not yield perfect score if engagement is below minimum threshold."
      );

      expect(lazyPlayer["Response Inhibition"], closeTo(0.95, 0.02));
    });
    test('Scenario: "The Slow Fade" (Minor vs Major Fatigue)', () {
      // 1. MAJOR CRASH (The one we just discussed)
      // First Half: 4/4 hits. Second Half: 1/3 hits.
      final majorCrash = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 5, falseAlarms: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(5, 600),
      );

      // 2. MINOR SLIP (The normal player)
      // First Half: 4/4 hits. Second Half: 2/3 hits (Just missed 1).
      final minorSlip = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 6, falseAlarms: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 2, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(6, 600),
      );

      // The "Major Crash" gets ~0.57.
      // The "Minor Slip" has a much smaller Diff.
      // BA1 = 1.0. BA2 = ~0.83. Diff = 0.17.
      // Penalty = 0.17^2 * 3 = ~0.08.
      // Score should be ~0.90+.

      expect(majorCrash["Observation / Vigilance"], closeTo(0.57, 0.05));

      expect(
          minorSlip["Observation / Vigilance"],
          greaterThan(0.85),
          reason: "Missing just 1 item in the second half is normal variance, score should remain 'A' grade."
      );

      // The gap between a minor slip and a crash should be huge
      expect(
          minorSlip["Observation / Vigilance"]! - majorCrash["Observation / Vigilance"]!,
          greaterThan(0.25),
          reason: "There must be a clear distinction between a slip and a crash."
      );
    });

    test('Scenario: "Waking Up" (Reverse Fatigue)', () {
      // Player is asleep at start (1/4 hits), but wakes up (3/3 hits).
      // Mathematically, the 'Diff' is the same as the crash, just reversed.
      // Stability score should be identical to the crash.

      final wakingUp = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 4, falseAlarms: 0,
        firstHalfHits: 2, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(4, 600),
      );

      // We expect this to be penalized heavily too.
      expect(wakingUp["Observation / Vigilance"], lessThan(0.7));

      // It should be roughly equal to the crash scenario (~0.57)
      // (Allowing small delta for floating point or slight target count imbalance differences)
      expect(wakingUp["Observation / Vigilance"], closeTo(0.6, 0.10));
    });
    test('Scenario: "The Nervous Start" (Instability via False Alarms)', () {
      // First Half: Hits 4/4 (Good), but 2 False Alarms (Nervous).
      // Specificity ~0.60. BA1 ~0.80.

      // Second Half: Hits 3/3 (Good), 0 False Alarms (Calmed down).
      // Specificity 1.0. BA2 1.0.

      final nervousStart = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 2,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 3, // 2 Errors here
        firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, // Perfect finish
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 550),
      );

      // Diff is |0.8 - 1.0| = 0.2.
      // Penalty = 0.2^2 * 3 = 0.04 * 3 = 0.12.
      // Stability score = 0.88.
      // Overall Accuracy is high (~0.9).
      // Result should be around 0.88 * 0.9 = ~0.79.

      expect(
          nervousStart["Observation / Vigilance"],
          closeTo(0.79, 0.05),
          reason: "Fluctuating False Alarms (nervousness) hurts vigilance, even if hits are perfect."
      );

      // Crucially, this should score lower than a perfectly steady player
      expect(nervousStart["Observation / Vigilance"], lessThan(0.95));
    });

    test('Scenario: "The Trigger Happy Meltdown" (Losing control later)', () {
      // First Half: Perfect. (BA = 1.0)

      // Second Half: Hits 3/3 (Good), but 4 False Alarms (Disaster).
      // Specificity = 2/6 = 0.33.
      // BA2 = (1.0 + 0.33) / 2 = 0.66.

      final meltdown = gradeBlinkFromStats(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 4,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 2, // 4 Errors here
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 550),
      );

      // Diff is |1.0 - 0.66| = 0.34.
      // Penalty = 0.34^2 * 3 = 0.115 * 3 = ~0.35.
      // Stability = 0.65.
      // Result ~0.55.

      expect(
          meltdown["Observation / Vigilance"],
          lessThan(0.60),
          reason: "Losing impulse control in the second half is a massive vigilance failure."
      );

      // It should be comparable to the "Fatigue Crash" (where they stopped clicking).
      // Both are failures of sustained attention.
      expect(meltdown["Observation / Vigilance"], closeTo(0.55, 0.10));
    });
  });
}