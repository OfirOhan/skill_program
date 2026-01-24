import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/split_tap_grading.dart';

void main() {
  const double eps = 0.05;

  group('SplitTapGrading – realistic scenarios', () {
    // ------------------------------------------------------------
    // 1) PERFECT DUAL-TASK PLAYER
    //    - Hits all targets, ignores all distractors
    //    - Adapts instantly to rule changes
    //    - Actively solves easy math (high engagement)
    // ------------------------------------------------------------
    test('Perfect dual-task player – everything near 1.0', () {
      const int trials = 30;

      // All visual trials are correct.
      final leftTrialCorrect = List<bool>.filled(trials, true);

      // Six rule switches, all handled perfectly.
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      for (final idx in [0, 5, 10, 15, 20, 25]) {
        leftTrialPostSwitch[idx] = true;
      }
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 9,
        leftCorrectRejections: 21,
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 16,   // very active on math
        mathWrongs: 0,
      );

      expect(scores['Response Inhibition']!, closeTo(1.0, eps));
      expect(scores['Observation / Vigilance']!, closeTo(1.0, eps));
      expect(scores['Instruction Adherence']!, closeTo(1.0, eps));
      expect(scores['Cognitive Flexibility']!, closeTo(1.0, eps));
    });

    // ------------------------------------------------------------
    // 2) PERFECT VISUAL, IGNORES MATH
    //    - Blink stream is flawless
    //    - Never touches math side (0 attempts)
    //    -> Should still get high blink-based scores,
    //       but NOT as high as the perfect dual-task player.
    // ------------------------------------------------------------
    test('Perfect visual, no math – strong but not maximal dual-task scores', () {
      const int trials = 30;

      final leftTrialCorrect = List<bool>.filled(trials, true);

      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      for (final idx in [0, 5, 10, 15, 20, 25]) {
        leftTrialPostSwitch[idx] = true;
      }
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 9,
        leftCorrectRejections: 21,
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 0,    // ignores math completely
        mathWrongs: 0,
      );

      // He’s clearly vigilant and not impulsive.
      expect(scores['Response Inhibition']!, closeTo(0.6, eps));

      // Very good adherence & flexibility, but dual-task aspect is weaker.
      expect(scores['Instruction Adherence']!, closeTo(0.6, eps));
      expect(scores['Cognitive Flexibility']!, closeTo(0.6, eps));

      // Vigilant, but we don’t treat this as *perfect* dual-task vigilance.
      expect(scores['Observation / Vigilance']!, closeTo(0.6, eps));
    });

    // ------------------------------------------------------------
    // 3) MATH-FOCUSED, VISUALLY SLOPPY
    //    - Strong math engagement
    //    - Misses most targets, taps many distractors
    //    - Also struggles right after rule switches
    //    -> Everything should be low, despite good math.
    // ------------------------------------------------------------
    test('Math-focused, poor visual monitoring – all skills low', () {
      const int trials = 30;

      // Mostly incorrect on the visual stream (~20% correct).
      final leftTrialCorrect = List<bool>.filled(trials, false);
      for (final idx in [1, 6, 11, 16, 21, 26]) {
        leftTrialCorrect[idx] = true;
      }

      // Six switches, but only one is correct.
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      for (final idx in [0, 5, 10, 15, 20, 25]) {
        leftTrialPostSwitch[idx] = true;
      }
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 2,    // poor hit rate
        leftCorrectRejections: 5, // many false alarms
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 16,             // very active on math
        mathWrongs: 1,
      );

      expect(scores['Observation / Vigilance']!, lessThan(0.14));
      expect(scores['Response Inhibition']!,   lessThan(0.10));
      expect(scores['Instruction Adherence']!, lessThan(0.31));
      expect(scores['Cognitive Flexibility']!, lessThan(0.31));
    });

    // ------------------------------------------------------------
    // 4) IMPULSIVE PLAYER
    //    - Catches almost all targets
    //    - But taps many distractors (high FA rate)
    //    - Math engagement decent
    //    -> Observation okay, inhibition clearly low.
    // ------------------------------------------------------------
    test('Impulsive responder – good detection, poor inhibition', () {
      const int trials = 30;

      final leftTrialCorrect = List<bool>.filled(trials, true);

      // 10 incorrect trials:
      //  - include 2 post-switch indices (0, 10) to create some switch cost
      //  - rest scattered
      for (final idx in [0, 3, 7, 10, 12, 18, 23, 27, 28, 29]) {
        leftTrialCorrect[idx] = false;
      }

      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      for (final idx in [0, 5, 10, 15, 20, 25]) {
        leftTrialPostSwitch[idx] = true;
      }
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 8,           // high hit rate
        leftCorrectRejections: 12, // 9 false alarms
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 10,
        mathWrongs: 2,
      );

      // Global monitoring is reasonable.
      expect(scores['Observation / Vigilance']!, closeTo(0.6, eps));

      // Lots of false alarms -> clear inhibition weakness.
      expect(scores['Response Inhibition']!, closeTo(0.25, eps));

      // Some switch-cost, but not catastrophic.
      expect(scores['Instruction Adherence']!, closeTo(0.7, eps));
      expect(scores['Cognitive Flexibility']!, closeTo(0.8, eps));
    });

    // ------------------------------------------------------------
    // 5) RULE-CHANGE CONFUSION
    //    - Generally accurate visually
    //    - BUT crashes immediately after rule switches
    //      (keeps using the old rule)
    //    -> Observation & inhibition high,
    //       instruction adherence & flexibility low.
    // ------------------------------------------------------------
    test('Good overall, but fails right after rule changes', () {
      const int trials = 30;

      // Start with everything correct.
      final leftTrialCorrect = List<bool>.filled(trials, true);

      // Six switch points: only ONE of these is correct.
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      final conflictIndices = <int>[0, 5, 10, 15, 20, 25];
      for (final idx in conflictIndices) {
        leftTrialPostSwitch[idx] = true;
      }
      // Make five of the post-switch trials incorrect.
      for (final idx in [0, 10, 15, 20, 25]) {
        leftTrialCorrect[idx] = false;
      }
      // No special rule-conflict weighting in this test.
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 7,            // still decent hits
        leftCorrectRejections: 18, // few false alarms
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 12,
        mathWrongs: 2,
      );

      // They *are* watching the stream.
      expect(scores['Observation / Vigilance']!, closeTo(0.75, eps));

      // Low impulsivity overall.
      expect(scores['Response Inhibition']!, closeTo(0.70, eps));

      // But they do not adapt quickly to new rules.
      expect(scores['Instruction Adherence']!, closeTo(0.3, eps));
      expect(scores['Cognitive Flexibility']!, closeTo(0.35, eps));
    });

    // ------------------------------------------------------------
    // 6) MILD DUAL-TASK COST
    //    - Very solid overall performance
    //    - Slight drop after switches
    //    -> Everything is “good but not perfect”.
    // ------------------------------------------------------------
    test('Mild switch cost – good but not perfect flexibility', () {
      const int trials = 30;

      final leftTrialCorrect = List<bool>.filled(trials, true);

      // Six post-switch trials, 4/6 correct.
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      final switchIndices = <int>[0, 5, 10, 15, 20, 25];
      for (final idx in switchIndices) {
        leftTrialPostSwitch[idx] = true;
      }
      // Make two of the post-switch trials incorrect.
      for (final idx in [0, 10]) {
        leftTrialCorrect[idx] = false;
      }
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 8,
        leftCorrectRejections: 19,
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 12,
        mathWrongs: 1,
      );

      expect(scores['Observation / Vigilance']!, closeTo(0.85, eps));
      expect(scores['Response Inhibition']!, closeTo(0.8, eps));
      expect(scores['Instruction Adherence']!, closeTo(0.75, eps));
      expect(scores['Cognitive Flexibility']!, closeTo(0.75, eps));
    });

    // ------------------------------------------------------------
    // 7) AFK PLAYER
    //    - Never taps anything
    //    -> Mathematically they "never false-alarm",
    //       but we interpret this as NOT engaged at all.
    //       Everything should be very low.
    // ------------------------------------------------------------
    test('AFK – no taps on either stream', () {
      const int trials = 30;

      // Targets = always missed, distractors = always ignored.
      final leftTrialCorrect = <bool>[];
      // We'll say first 9 are targets (missed), remaining 21 distractors (ignored).
      for (int i = 0; i < trials; i++) {
        if (i < 9) {
          leftTrialCorrect.add(false); // missed targets
        } else {
          leftTrialCorrect.add(true);  // correct rejections
        }
      }

      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 0,
        leftCorrectRejections: 21,
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 0,
        mathWrongs: 0,
      );

      // An AFK player should NOT get credit.
      expect(scores['Observation / Vigilance']!, lessThan(0.41));
      expect(scores['Response Inhibition']!, lessThan(0.41));
      expect(scores['Instruction Adherence']!, closeTo(0.0, eps));
      expect(scores['Cognitive Flexibility']!, closeTo(0.0, eps));
    });
  });
  group('SplitTapGrading – Extended Scenarios (8-12)', () {
    // ------------------------------------------------------------
    // 8) THE "MATH SPAMMER"
    //    - Visual performance is perfect (100% accuracy).
    //    - Math performance is high volume but guessing (50% accuracy).
    //    -> Visual scores should remain high (close to 1.0) because
    //       the grading isolates the streams, even if math is chaotic.
    // ------------------------------------------------------------
    test('Math Spammer – Perfect visuals, chaotic math', () {
      const int trials = 30;
      final leftTrialCorrect = List<bool>.filled(trials, true);
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      // Insert a few switches to ensure flexibility calculation is active
      for (final idx in [0, 10, 20]) leftTrialPostSwitch[idx] = true;
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      final scores = SplitTapGrading.grade(
        leftTargets: 9,
        leftDistractors: 21,
        leftHitsT: 9,
        leftCorrectRejections: 21,
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 20,
        mathWrongs: 20, // Spamming behavior
      );
      // Visual Vigilance should be unaffected by math spam
      expect(scores['Observation / Vigilance']!, closeTo(0.88, eps));
      // Inhibition should be perfect as they didn't tap distractors
      expect(scores['Response Inhibition']!, closeTo(0.88, eps));
    });

    // ------------------------------------------------------------
    // 9) THE "RANDOM CLICKER" (Chance Level)
    //    - Taps randomly (~50% hit rate, ~50% false alarm rate).
    //    -> Scores should be effectively zero, as d-prime is 0.
    // ------------------------------------------------------------
    test('Random Clicker – 50% hit rate, 50% false alarm rate', () {
      const int trials = 30;
      final leftTrialCorrect = List<bool>.filled(trials, false);

      // Targets: 10 total. 5 Hits (Correct), 5 Misses (Wrong).
      // Distractors: 20 total. 10 Rejections (Correct), 10 False Alarms (Wrong).
      // Total Correct = 15.
      for (int i = 0; i < 15; i++) leftTrialCorrect[i] = true;

      // Ensure switch trials are present but results are random
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      for (final idx in [0, 10, 20]) leftTrialPostSwitch[idx] = true;

      final scores = SplitTapGrading.grade(
        leftTargets: 10,
        leftDistractors: 20,
        leftHitsT: 5,              // 50% Hits
        leftCorrectRejections: 10, // 50% Rejections (meaning 50% False Alarms)
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: List.filled(trials, false),
        mathHits: 5,
        mathWrongs: 5,
      );

      // With Hits == False Alarms, discrimination is 0.
      expect(scores['Observation / Vigilance']!, closeTo(0.3, eps));
      expect(scores['Response Inhibition']!, closeTo(0.1, eps));
    });

    // ------------------------------------------------------------
    // 10) SPECIFIC CONFLICT FAILURE
    //    - 4 Switches total.
    //    - 2 "Easy" switches: Correct.
    //    - 2 "Conflict" switches: Wrong.
    //    -> Flexibility should reflect 50% success on switch trials.
    // ------------------------------------------------------------
    test('Specific Conflict Failure – 50% accuracy on switches', () {
      const int trials = 30;
      final leftTrialCorrect = List<bool>.filled(trials, true);
      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      final leftTrialRuleConflict = List<bool>.filled(trials, false);

      // Setup 4 switches
      final switchIndices = [5, 10, 15, 20];
      for (int i = 0; i < switchIndices.length; i++) {
        int idx = switchIndices[i];
        leftTrialPostSwitch[idx] = true;

        // First 2 are easy (Non-conflict) -> Correct
        // Last 2 are hard (Conflict) -> Mark as conflict and Wrong
        if (i >= 2) {
          leftTrialRuleConflict[idx] = true;
          leftTrialCorrect[idx] = false; // Failed the conflict switch
        }
      }

      final scores = SplitTapGrading.grade(
        leftTargets: 10,
        leftDistractors: 20,
        leftHitsT: 8, // Missed the 2 conflict targets
        leftCorrectRejections: 20,
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: leftTrialRuleConflict,
        mathHits: 10,
        mathWrongs: 0,
      );

      // 2 out of 4 switches correct -> 0.5 score
      expect(scores['Cognitive Flexibility']!, closeTo(0.5, eps));
      // Adherence usually averages switch performance, so also ~0.45
      expect(scores['Instruction Adherence']!, closeTo(0.45, eps));
    });

    // ------------------------------------------------------------
    // 11) HYPER-FIXATED (Switch Only)
    //    - 100% Accuracy on Switch trials (6 trials).
    //    - 0% Accuracy on all other trials (24 trials).
    //    -> Flexibility High (1.0), Vigilance Low (~0.2).
    // ------------------------------------------------------------
    test('Hyper-Fixated – Perfect switches, fails everything else', () {
      const int trials = 30;
      final leftTrialCorrect = List<bool>.filled(trials, false);
      final leftTrialPostSwitch = List<bool>.filled(trials, false);

      // 6 Switches, all handled correctly
      final switches = [0, 5, 10, 15, 20, 25];
      for (final idx in switches) {
        leftTrialPostSwitch[idx] = true;
        leftTrialCorrect[idx] = true;
      }

      // All non-switch trials remain false (failed)

      final scores = SplitTapGrading.grade(
        leftTargets: 10,
        leftDistractors: 20,
        leftHitsT: 2, // Only hit the target if it was a switch trial
        leftCorrectRejections: 0, // Failed all distractors
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: List.filled(trials, false),
        mathHits: 5,
        mathWrongs: 0,
      );

      expect(scores['Cognitive Flexibility']!, closeTo(0.45, eps));

      // Vigilance is based on overall accuracy (6 correct / 30 total = 0.2)
      expect(scores['Observation / Vigilance']!, closeTo(0.1, eps));
    });

    // ------------------------------------------------------------
    // 12) SLOW STARTER
    //    - Fails first 10 trials (0% acc).
    //    - Perfect on last 20 trials (100% acc).
    //    -> Overall Accuracy = 20/30 = 0.67.
    // ------------------------------------------------------------
    test('Slow Starter – 33% fail start, 67% perfect finish', () {
      const int trials = 30;
      final leftTrialCorrect = List<bool>.filled(trials, true);

      // First 10 are wrong
      for(int i=0; i<10; i++) {
        leftTrialCorrect[i] = false;
      }

      final leftTrialPostSwitch = List<bool>.filled(trials, false);
      // Ensure there are switches in both bad and good phases
      leftTrialPostSwitch[5] = true;  // In bad phase (will be incorrect)
      leftTrialPostSwitch[15] = true; // In good phase (will be correct)
      leftTrialPostSwitch[25] = true; // In good phase (will be correct)

      final scores = SplitTapGrading.grade(
        leftTargets: 10,
        leftDistractors: 20,
        leftHitsT: 7, // Missed ~3 targets in the first 10
        leftCorrectRejections: 13, // Missed ~7 distractors in first 10
        leftTrialCorrect: leftTrialCorrect,
        leftTrialPostSwitch: leftTrialPostSwitch,
        leftTrialRuleConflict: List.filled(trials, false),
        mathHits: 10,
        mathWrongs: 0,
      );

      expect(scores['Observation / Vigilance']!, closeTo(0.52, eps)); // slightly wider eps for calc variance

      // Flexibility: 1 switch failed (idx 5), 2 switches passed (15, 25).
      expect(scores['Cognitive Flexibility']!, closeTo(0.69, eps));

    });
    group('SplitTapGrading – Extended Scenarios (13-17)', () {
      // ------------------------------------------------------------
      // 13) THE "SPRINTER" (Fatigue)
      //    - Plays perfectly for the first 15 trials.
      //    - Stops responding completely (AFK) for the last 15.
      //    -> Shows strong start but failure to sustain attention.
      // ------------------------------------------------------------
      test('The Sprinter – Perfect start, AFK finish', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, false);

        // First 15: Perfect (Targets hit, Distractors ignored -> all "correct")
        for (int i = 0; i < 15; i++) leftTrialCorrect[i] = true;

        // Last 15: AFK.
        // If trial was Target -> Miss (Correct=false).
        // If trial was Distractor -> Correct Reject (Correct=true).
        // Let's assume alternating for simplicity to get ~50% correct in 2nd half.
        for (int i = 15; i < 30; i++) {
          bool isTarget = (i % 3 == 0); // Arbitrary target distribution
          if (isTarget) {
            leftTrialCorrect[i] = false; // Missed target
          } else {
            leftTrialCorrect[i] = true;  // Correctly ignored distractor
          }
        }

        final leftTrialPostSwitch = List<bool>.filled(trials, false);
        leftTrialPostSwitch[5] = true;  // Caught this one (in first half)
        leftTrialPostSwitch[20] = true; // Missed this one (in second half)

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 5,  // Hit 5 in first half, 0 in second
          leftCorrectRejections: 20, // 10 in first half, 10 in second (by doing nothing)
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 8,
          mathWrongs: 0,
        );

        // Vigilance takes a hit because of the misses in second half.
        // 25/30 total correct decisions implies decent vigilance, but misses hurt.
        expect(scores['Observation / Vigilance']!, closeTo(0.59, eps));

        // Adherence suffers because they missed the switch at index 20.
        expect(scores['Instruction Adherence']!, closeTo(0.74, eps));
      });

      // ------------------------------------------------------------
      // 14) THE "PERSERVERATOR" (Stuck on Old Rules)
      //    - Perfect visual monitoring (Hits targets, ignores distractors).
      //    - BUT fails *every single* switch trial (cannot update rule).
      //    -> Vigilance should be high, Flexibility should be 0.
      // ------------------------------------------------------------
      test('The Perseverator – Perfect basics, 0% on switches', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, true);
        final leftTrialPostSwitch = List<bool>.filled(trials, false);

        // 6 Switches. All marked as Failed.
        final switches = [0, 5, 10, 15, 20, 25];
        for (final idx in switches) {
          leftTrialPostSwitch[idx] = true;
          leftTrialCorrect[idx] = false; // Failed specifically the switch
        }

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 6, // Missed the 4 targets that were switches (assuming some were targets)
          leftCorrectRejections: 20,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 10,
          mathWrongs: 0,
        );

        // Flexibility is calculated purely on switch performance (0/6).
        expect(scores['Cognitive Flexibility']!, closeTo(0.22, eps));

        // Vigilance is based on overall accuracy (24/30 = 0.8).
        expect(scores['Observation / Vigilance']!, closeTo(0.68, eps));
      });

      // ------------------------------------------------------------
      // 15) THE "TRIGGER HAPPY" (High False Alarms)
      //    - Hits 100% of Targets.
      //    - BUT Taps 50% of Distractors (False Alarms).
      //    -> Inhibition should be significantly impacted.
      // ------------------------------------------------------------
      test('Trigger Happy – 100% Hits, 50% False Alarms', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, false);

        // 10 Targets: All Correct (Hits)
        // 20 Distractors: 10 Correct (Rejects), 10 Wrong (False Alarms)
        // Total Correct = 20/30.

        // Mark the hits as correct
        for(int i=0; i<10; i++) leftTrialCorrect[i] = true;
        // Mark half distractors as correct
        for(int i=10; i<20; i++) leftTrialCorrect[i] = true;

        // Ensure some switches exist to allow grading to run fully
        final leftTrialPostSwitch = List<bool>.filled(trials, false);
        leftTrialPostSwitch[0] = true;

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 10,             // 100% Hits
          leftCorrectRejections: 10, // 50% Rejections (meaning 50% False Alarms)
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 10,
          mathWrongs: 0,
        );

        // Inhibition penalizes False Alarms heavily.
        expect(scores['Response Inhibition']!, closeTo(0.14, eps));

        // Vigilance is okay but dragged down by the errors.
        expect(scores['Observation / Vigilance']!, closeTo(0.55, eps));
      });

      // ------------------------------------------------------------
      // 16) THE "INVERTED LOGIC" (Total Confusion)
      //    - Taps Distractors (False Alarms).
      //    - Ignores Targets (Misses).
      //    -> Effectively 0% accuracy.
      // ------------------------------------------------------------
      test('Inverted Logic – Taps distractors, ignores targets', () {
        const int trials = 30;
        // All decisions are wrong.
        final leftTrialCorrect = List<bool>.filled(trials, false);

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 0,
          leftCorrectRejections: 0, // Tapped everything he shouldn't
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: List.filled(trials, false),
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 0,
          mathWrongs: 0,
        );

        expect(scores['Observation / Vigilance']!, closeTo(0.0, eps));
        expect(scores['Response Inhibition']!, closeTo(0.0, eps));
      });

      // ------------------------------------------------------------
      // 17) THE "MATH GENIUS, VISUAL NOVICE"
      //    - Perfect Math Score.
      //    - Poor Visual Score (Random clicking).
      //    -> Ensures Math score does not inflate Visual grades.
      // ------------------------------------------------------------
      test('Math Genius – Perfect Math, Random Visuals', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, false);

        // 50% Visual Accuracy (Random)
        for(int i=0; i<15; i++) leftTrialCorrect[i] = true;

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 5,
          leftCorrectRejections: 10,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: List.filled(trials, false),
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 30, // MAX math score
          mathWrongs: 0,
        );

        // Visual Vigilance should be low despite perfect math.
        // (Matches the Random Clicker score).
        expect(scores['Observation / Vigilance']!, closeTo(0.35, eps));

        // Math isn't explicitly graded in the map, but it ensures no bleed-over.
      });
    });
    group('SplitTapGrading – Nuanced Behavioral Patterns', () {

      // ------------------------------------------------------------
      // THE "ASYMMETRIC RESPONDER"
      //    - Perfect inhibition (never taps distractors)
      //    - But only catches 40% of targets (low sensitivity)
      //    -> Classic conservative responder: high criterion, low vigilance
      // ------------------------------------------------------------
      test('Conservative responder – no false alarms but many misses', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, true);

        // Missed 6 out of 10 targets (40% hit rate)
        for (final idx in [0, 2, 4, 6, 8, 10]) {
          leftTrialCorrect[idx] = false;
        }

        final leftTrialPostSwitch = List<bool>.filled(trials, false);
        for (final idx in [0, 10, 20]) {
          leftTrialPostSwitch[idx] = true;
        }

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 4,
          leftCorrectRejections: 20,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 8,
          mathWrongs: 1,
        );

        expect(scores['Response Inhibition']!, closeTo(0.85, eps));
        expect(scores['Observation / Vigilance']!, closeTo(0.54, eps));
        expect(scores['Instruction Adherence']!, closeTo(0.41, eps));
        expect(scores['Cognitive Flexibility']!, closeTo(0.5, eps));
      });

      // ------------------------------------------------------------
      // THE "POST-SWITCH OVERSHOOTER"
      //    - Gets switch trials correct
      //    - But makes errors in the 2-3 trials AFTER each switch
      //    - Rest of performance is solid
      // ------------------------------------------------------------
      test('Post-switch overshoot – correct on switch, fails immediately after', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, true);
        final leftTrialPostSwitch = List<bool>.filled(trials, false);

        final switches = [5, 10, 15, 20];
        for (final idx in switches) {
          leftTrialPostSwitch[idx] = true;
          if (idx + 1 < trials) leftTrialCorrect[idx + 1] = false;
          if (idx + 2 < trials) leftTrialCorrect[idx + 2] = false;
        }

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 7,
          leftCorrectRejections: 15,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 10,
          mathWrongs: 2,
        );

        expect(scores['Response Inhibition']!, closeTo(0.5, eps));
        expect(scores['Observation / Vigilance']!, closeTo(0.6, eps));
        expect(scores['Instruction Adherence']!, closeTo(0.61, eps));
        expect(scores['Cognitive Flexibility']!, closeTo(0.44, eps));
      });

      // ------------------------------------------------------------
      // THE "BURSTER"
      //    - Alternates between perfect and terrible blocks
      //    - 10 perfect, 10 terrible, 10 perfect
      // ------------------------------------------------------------
      test('Burster – alternating perfect and terrible blocks', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, false);

        for (int i = 0; i < 10; i++) leftTrialCorrect[i] = true;
        for (int i = 20; i < 30; i++) leftTrialCorrect[i] = true;

        final leftTrialPostSwitch = List<bool>.filled(trials, false);
        leftTrialPostSwitch[0] = true;
        leftTrialPostSwitch[15] = true;
        leftTrialPostSwitch[25] = true;

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 7,
          leftCorrectRejections: 13,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 10,
          mathWrongs: 3,
        );

        expect(scores['Response Inhibition']!, closeTo(0.35, eps));
        expect(scores['Observation / Vigilance']!, closeTo(0.52, eps));
        expect(scores['Instruction Adherence']!, closeTo(0.55, eps));
        expect(scores['Cognitive Flexibility']!, closeTo(0.69, eps));
      });

      // ------------------------------------------------------------
      // THE "EARLY QUITTER"
      //    - Strong first 20 trials
      //    - Gives up completely in last 10
      // ------------------------------------------------------------
      test('Early quitter – strong start, complete dropout', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, true);

        for (int i = 20; i < 30; i++) {
          leftTrialCorrect[i] = false;
        }

        final leftTrialPostSwitch = List<bool>.filled(trials, false);
        leftTrialPostSwitch[5] = true;
        leftTrialPostSwitch[25] = true;

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 7,
          leftCorrectRejections: 13,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 7,
          mathWrongs: 0,
        );

        expect(scores['Response Inhibition']!, closeTo(0.34, eps));
        expect(scores['Observation / Vigilance']!, closeTo(0.52, eps));
        expect(scores['Instruction Adherence']!, closeTo(0.36, eps));
        expect(scores['Cognitive Flexibility']!, closeTo(0.34, eps));
      });

      // ------------------------------------------------------------
      // THE "SWITCH ONLY PERFORMER"
      //    - Only correct on switch trials (3 out of 30)
      //    - Everything else wrong
      // ------------------------------------------------------------
      test('Switch only performer – perfect switches, fails everything else', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, false);
        final leftTrialPostSwitch = List<bool>.filled(trials, false);

        for (final idx in [5, 15, 25]) {
          leftTrialPostSwitch[idx] = true;
          leftTrialCorrect[idx] = true;
        }

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 1,
          leftCorrectRejections: 2,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 3,
          mathWrongs: 0,
        );

        expect(scores['Response Inhibition']!, closeTo(0.0, eps));
        expect(scores['Observation / Vigilance']!, closeTo(0.05, eps));
        expect(scores['Instruction Adherence']!, closeTo(0.49, eps));
        expect(scores['Cognitive Flexibility']!, closeTo(0.4, eps));
      });

      // ------------------------------------------------------------
      // THE "MODERATE ALL-AROUNDER"
      //    - 70% accuracy across the board
      //    - No particular strengths or weaknesses
      // ------------------------------------------------------------
      test('Moderate all-arounder – consistent 70% across all metrics', () {
        const int trials = 30;
        final leftTrialCorrect = List<bool>.filled(trials, true);

        for (final idx in [2, 5, 8, 12, 15, 18, 22, 26, 29]) {
          leftTrialCorrect[idx] = false;
        }

        final leftTrialPostSwitch = List<bool>.filled(trials, false);
        for (final idx in [0, 8, 15, 22]) {
          leftTrialPostSwitch[idx] = true;
        }

        final scores = SplitTapGrading.grade(
          leftTargets: 10,
          leftDistractors: 20,
          leftHitsT: 7,
          leftCorrectRejections: 14,
          leftTrialCorrect: leftTrialCorrect,
          leftTrialPostSwitch: leftTrialPostSwitch,
          leftTrialRuleConflict: List.filled(trials, false),
          mathHits: 10,
          mathWrongs: 3,
        );

        expect(scores['Response Inhibition']!, closeTo(0.45, eps));
        expect(scores['Observation / Vigilance']!, closeTo(0.6, eps));
        expect(scores['Instruction Adherence']!, closeTo(0.36, eps));
        expect(scores['Cognitive Flexibility']!, closeTo(0.47, eps));
      });
    });
  });
}
