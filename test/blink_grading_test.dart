import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/blink_grading.dart';

void main() {
  // Helper to create input lists from aggregate stats for testing
  // This allows us to keep the original test logic (which used counts)
  // while testing the new grading API (which uses raw lists).
  Map<String, double> gradeFromStatsHelper({
    required int targets,
    required int distractors,
    required int hits,
    required int falseAlarms,
    required int correctRejections,
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
    List<bool> isTarget = [];
    List<bool> userClaimed = [];

    // Helper to add trials
    void addTrials(int t, int h, int d, int fa, int cr) {
      // Targets with Hits
      for (int i = 0; i < h; i++) {
        isTarget.add(true);
        userClaimed.add(true);
      }
      // Targets Missed (Target - Hits)
      for (int i = 0; i < (t - h); i++) {
        isTarget.add(true);
        userClaimed.add(false);
      }
      // Distractors with False Alarms
      for (int i = 0; i < fa; i++) {
        isTarget.add(false);
        userClaimed.add(true);
      }
      // Distractors Correctly Rejected
      // Note: We use the provided 'cr' count to ensure we match the test's intent,
      // assuming d >= fa + cr. If d > fa + cr, we add extra CRs (unspecified).
      // If d < fa + cr, we prefer fa and clamp cr.
      int effectiveCR = cr;
      if (fa + cr > d) effectiveCR = d - fa;
      
      for (int i = 0; i < effectiveCR; i++) {
        isTarget.add(false);
        userClaimed.add(false);
      }
      
      // Fill remaining distractors (if any discrepancy) as CRs
      int usedD = fa + effectiveCR;
      if (usedD < d) {
         for (int i = 0; i < (d - usedD); i++) {
           isTarget.add(false);
           userClaimed.add(false);
         }
      }
    }

    // FIRST HALF
    addTrials(firstHalfTargets, firstHalfHits, firstHalfDistractors, 
              (firstHalfDistractors - firstHalfCorrectRejections), // approximated FAs if not explicit
              firstHalfCorrectRejections);

    // SECOND HALF
    addTrials(secondHalfTargets, secondHalfHits, secondHalfDistractors, 
              (secondHalfDistractors - secondHalfCorrectRejections), // approximated FAs
              secondHalfCorrectRejections);
              
    // Safety: ensure totals match (mostly for debugging)
    // assert(isTarget.where((t) => t).length == targets);
    // assert(isTarget.where((t) => !t).length == distractors);

    return gradeBlinkFromStats(
      isTarget: isTarget,
      userClaimed: userClaimed,
      hitReactionTimesMs: hitReactionTimesMs,
    );
  }

  group('Blink Match Grading – Deterministic Tests', () {
    test('Perfect player', () {
      final scores = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 0,
        correctRejections: 11,
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
      final scores = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 1,
        correctRejections: 10,
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
    });

    test('Passive player (no engagement)', () {
      final scores = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 0,
        falseAlarms: 0,
        correctRejections: 11,
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
      final scores = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 11,
        correctRejections: 0,
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
      final scores = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 6,
        falseAlarms: 2,
        correctRejections: 9,
        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,
        secondHalfHits: 2, // Missed 1
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 4, // 2 FAs
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(6, 700),
      );

      expect(
        scores["Observation / Vigilance"],
        lessThan(scores["Working Memory"]!),
      );
    });

    test('Engagement threshold works', () {
      final scores = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 2,
        falseAlarms: 0,
        correctRejections: 11,
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
      final lowFA = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,
        correctRejections: 10,
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

      final highFA = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 5,
        correctRejections: 6,
        firstHalfHits: 3,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 0,
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
      final slow = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,
        correctRejections: 10,
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

      final fast = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,
        correctRejections: 10,
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
      final impulsive = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 3,
        correctRejections: 8,
        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 3,
        firstHalfDistractors: 5,
        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 5,
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 500),
      );

      final inattentive = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 3,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,
        secondHalfHits: 2,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(5, 700),
      );

      expect(
          inattentive["Response Inhibition"],
          greaterThan(impulsive["Response Inhibition"]!),
          reason: "Player with 0 false alarms must have better Inhibition than one with 3 errors."
      );

      expect(
          impulsive["Working Memory"],
          greaterThan(inattentive["Working Memory"]!),
          reason: "Player who found all targets demonstrated better retention of 'what to look for', despite being messy."
      );
    });

    test('Scenario: "The Late Crasher" (Vigilance Logic)', () {
      final consistent = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 4,
        falseAlarms: 0,
        correctRejections: 11,
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

      final crasher = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 4,
        falseAlarms: 0,
        correctRejections: 11,
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

    test('Scenario: "The Sleeper" (Misses do not hurt Inhibition)', () {
      final minimalEffort = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 3,
        falseAlarms: 0,
        correctRejections: 11,
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
          reason: "If False Alarms are 0, Response Inhibition should be perfect."
      );
    });
  });

  group('Blink Match Grading – Edge Cases & Constraints', () {

    test('Edge Case: Median Robustness (One terrible click shouldn\'t kill score)', () {
      final consistentPlayer = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: [550, 550, 550, 550, 550, 550, 550], 
      );

      final outlierPlayer = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: [550, 550, 550, 5000, 550, 550, 550],
      );

      expect(
          outlierPlayer["Reaction Time (Choice)"],
          equals(consistentPlayer["Reaction Time (Choice)"]),
          reason: "The grading must use Median RT to be robust against single outliers."
      );
    });

    test('Edge Case: The "Lucky Guesser" Penalty (Sqrt constricts WM)', () {
      final luckyGuesser = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 5,
        correctRejections: 6, 
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 2, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 4, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 600),
      );

      expect(luckyGuesser["Working Memory"], greaterThan(0.5));
      expect(luckyGuesser["Working Memory"], lessThan(0.8));
      expect(
          luckyGuesser["Working Memory"],
          greaterThan(luckyGuesser["Response Inhibition"]!),
          reason: "High hits + High FAs should punish RI more than WM."
      );
    });

    test('Edge Case: Natural Variance vs True Fatigue', () {
      final naturalVariance = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 600),
      );

      final fatigueDrop = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 5, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(5, 600),
      );

      expect(naturalVariance["Observation / Vigilance"], closeTo(1.0, 0.05));
      expect(
          fatigueDrop["Observation / Vigilance"],
          lessThan(naturalVariance["Observation / Vigilance"]! - 0.3),
      );
    });

    test('Edge Case: The "Lazy Clicker" (Engagement Scaling)', () {
      final lazyPlayer = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 2, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 1, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: [550, 550],
      );

      expect(
          lazyPlayer["Response Inhibition"],
          lessThan(1.0),
          reason: "Perfect accuracy should not yield perfect score if engagement is below minimum threshold."
      );
      expect(lazyPlayer["Response Inhibition"], closeTo(0.95, 0.02));
    });

    test('Scenario: "The Slow Fade" (Minor vs Major Fatigue)', () {
      final majorCrash = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 5, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(5, 600),
      );

      final minorSlip = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 6, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 2, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(6, 600),
      );

      expect(majorCrash["Observation / Vigilance"], closeTo(0.57, 0.05));
      expect(minorSlip["Observation / Vigilance"], greaterThan(0.85));
    });

    test('Scenario: "Waking Up" (Reverse Fatigue)', () {
      final wakingUp = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 4, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 2, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(4, 600),
      );

      expect(wakingUp["Observation / Vigilance"], lessThan(0.7));
      expect(wakingUp["Observation / Vigilance"], closeTo(0.6, 0.10));
    });

    test('Scenario: "The Nervous Start" (Instability via False Alarms)', () {
      final nervousStart = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 2,
        correctRejections: 9,
        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 3, // 2 FAs
        firstHalfDistractors: 5,
        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 6,
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 550),
      );

      expect(nervousStart["Observation / Vigilance"], closeTo(0.79, 0.05));
    });

    test('Scenario: "The Trigger Happy Meltdown" (Losing control later)', () {
      final meltdown = gradeFromStatsHelper(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 4,
        correctRejections: 7,
        firstHalfHits: 4,
        firstHalfTargets: 4,
        firstHalfCorrectRejections: 5,
        firstHalfDistractors: 5,
        secondHalfHits: 3,
        secondHalfTargets: 3,
        secondHalfCorrectRejections: 2, // 4 FAs
        secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 550),
      );

      expect(meltdown["Observation / Vigilance"], lessThan(0.60));
    });

    test('Reaction Time Purity: Misses do NOT hurt Speed score', () {
      final perfectAim = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 600),
      );

      final blindBat = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 3, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 2, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 1, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(3, 600),
      );

      expect(
          blindBat["Reaction Time (Choice)"],
          closeTo(perfectAim["Reaction Time (Choice)"]!, 0.001),
      );
    });

    test('Reaction Time Purity: False Alarms DO hurt Speed score', () {
      final legitFast = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 0,
        correctRejections: 11,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 5, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 6, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 400),
      );

      final gambler = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 5,
        correctRejections: 6,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 2, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 4, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 400),
      );

      expect(
          gambler["Reaction Time (Choice)"],
          lessThan(legitFast["Reaction Time (Choice)"]! - 0.2),
      );
    });

    test('Invariants: Spammer gets 0 on Memory/Inhibition', () {
      final spammer = gradeFromStatsHelper(
        targets: 7, distractors: 11, hits: 7, falseAlarms: 11,
        correctRejections: 0,
        firstHalfHits: 4, firstHalfTargets: 4, firstHalfCorrectRejections: 0, firstHalfDistractors: 5,
        secondHalfHits: 3, secondHalfTargets: 3, secondHalfCorrectRejections: 0, secondHalfDistractors: 6,
        hitReactionTimesMs: List.filled(7, 450),
      );

      expect(spammer["Response Inhibition"], equals(0.0));
      expect(spammer["Working Memory"], equals(0.0));
    });
  });
}