import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/word_ladder_grading.dart';

Map<String, double> runGrading({
  required List<bool> results,
  required List<int> times,
}) {
  return WordLadderGrading.grade(
    results: results,
    reactionTimes: times,
  );
}

void main() {
  group('Logic Sprint – Weighted Cognitive Profiling (15s Limit)', () {

    // 1. PERFECT GENIUS
    test('Perfect Genius', () {
      final scores = runGrading(
        results: [true, true, true, true, true, true],
        times: [3000, 3000, 3000, 3000, 3000, 3000],
      );

      expect(scores["Inductive Reasoning"], closeTo(1.0, 0.01));
      expect(scores["Abstract Thinking"], closeTo(1.0, 0.01));
      expect(scores["Information Processing Speed"], closeTo(1.0, 0.01));
    });

    // 2. THE ENGINEER
    test('The Engineer (Pattern Matcher)', () {
      final scores = runGrading(
        results: [true, false, false, true, false, false],
        times: [5000, 5000, 5000, 5000, 5000, 5000],
      );
      expect(scores["Inductive Reasoning"], closeTo(0.58, 0.02));
      expect(scores["Abstract Thinking"], closeTo(0.15, 0.02));
    });

    // 3. THE POET
    test('The Poet (Deep Thinker)', () {
      final scores = runGrading(
        results: [false, false, false, false, true, true],
        times: [5000, 5000, 5000, 5000, 5000, 5000],
      );
      expect(scores["Inductive Reasoning"], closeTo(0.19, 0.02));
      expect(scores["Abstract Thinking"], closeTo(0.44, 0.02));
    });

    // 4. SPEED DEMON
    test('Speed Demon Efficiency', () {
      final scores = runGrading(
        results: [true, false, true, false, true, false],
        times: [3000, 3000, 3000, 3000, 3000, 3000],
      );
      expect(scores["Information Processing Speed"], closeTo(0.7, 0.02));
    });

    // 5. SLOW THINKER (Updated for 15s)
    test('Slow Thinker', () {
      // 100% Accuracy, taking full 15s per question
      // This hits the 0.5 floor exactly.
      final scores = runGrading(
        results: [true, true, true, true, true, true],
        times: [15000, 15000, 15000, 15000, 15000, 15000],
      );

      expect(scores["Inductive Reasoning"], closeTo(1.0, 0.01));
      expect(scores["Abstract Thinking"], closeTo(1.0, 0.01));
      expect(scores["Information Processing Speed"], closeTo(0.5, 0.02));
    });
  });
  group('Logic Sprint – Comprehensive Grading Tests', () {

    // --- BASELINE PROFILES ---

    // 6. PERFECT GENIUS
    test('One Timing Elapse', () {
      final scores = runGrading(
        results: [true, true, true, true, true, true],
        times: [3000, 3000, 3000, 3000, 3000, 12000],
      );
      expect(scores["Inductive Reasoning"], closeTo(1.0, 0.01));
      expect(scores["Abstract Thinking"], closeTo(1.0, 0.01));
      expect(scores["Information Processing Speed"], closeTo(1.0, 0.05));
    });

    // 7. TOTAL FAILURE (0 Correct)
    test('Total Failure', () {
      final scores = runGrading(
        results: [false, false, false, false, false, false],
        times: [2000, 2000, 2000, 2000, 2000, 2000], // Fast but wrong
      );
      expect(scores["Inductive Reasoning"], closeTo(0.0, 0.01));
      expect(scores["Abstract Thinking"], closeTo(0.0, 0.01));
      // Speed should be 0 because accuracy is 0 (Spam prevention)
      expect(scores["Information Processing Speed"], closeTo(0.0, 0.01));
    });

    // 8. THE "AVERAGE JOE" (Middle of the road)
    test('The Average Joe', () {
      final scores = runGrading(
        results: [true, true, false, true, false, false],
        times: [9000, 9000, 9000, 9000, 9000, 9000],
      );
      // IPS = 0.75 * sqrt(0.5) = 0.75 * 0.707 = 0.53
      expect(scores["Information Processing Speed"], closeTo(0.53, 0.02));

      expect(scores["Inductive Reasoning"], closeTo(0.69, 0.02));

      // Abstract: (0.2 + 0.6 + 0.3) / 3.4 = 1.1 / 3.4 = 0.32
      expect(scores["Abstract Thinking"], closeTo(0.35, 0.02));

    });
    // 9. THE "PANIC MODE" USER
    // Starts confident (Fast/Correct), then crashes (Slow/Wrong) under pressure.
    // Rounds 0-2: 2000ms (1.0 speed), Correct
    // Rounds 3-5: 14000ms (~0.54 speed), Wrong
    test('Panic Mode (Start Strong, End Weak)', () {
      final scores = runGrading(
        results: [true, true, true, false, false, false],
        times: [2000, 2000, 2000, 14000, 14000, 14000],
      );

      // Raw Speed Avg: (1.0 + 1.0 + 1.0 + 0.54 + 0.54 + 0.54) / 6 = ~0.77
      // Accuracy: 0.5
      // IPS: 0.77 * sqrt(0.5) = 0.77 * 0.707 = 0.54
      expect(scores["Information Processing Speed"], closeTo(0.54, 0.02));

      // Inductive: Got easy ones (0), missed easy ones (3).
      // Abstract: Got easy ones (1,2), missed hard ones (4,5).
      expect(scores["Inductive Reasoning"], closeTo(0.5, 0.02));
      expect(scores["Abstract Thinking"], closeTo(0.5, 0.02));
    });

    // 10. THE "CLUTCH PERFORMER"
    // Fails early (Fast/Wrong), but locks in for hard questions (Slow/Correct).
    // This tests if the code fairly rewards late-game success.
    test('Clutch Performer (Start Weak, End Strong)', () {
      final scores = runGrading(
        results: [false, false, false, true, true, true],
        times: [2000, 2000, 2000, 10000, 10000, 10000],
      );

      // 10000ms speed score: 1.0 - ((10000-3000)/12000)*0.5 = 1.0 - 0.29 = 0.71
      // Raw Speed Avg: (1.0 + 1.0 + 1.0 + 0.71 + 0.71 + 0.71) / 6 = 0.85
      // Accuracy: 0.5
      // IPS: 0.85 * 0.707 = 0.60
      expect(scores["Information Processing Speed"], closeTo(0.60, 0.02));

      // They nailed the Hard/Abstract items (4, 5) and Systems (3)
      expect(scores["Inductive Reasoning"], closeTo(0.5, 0.02)); // 0.7+0.2+0.1 / total
      expect(scores["Abstract Thinking"], closeTo(0.5, 0.02)); // 0.3+0.8+0.9 / total
    });

    // 11. THE "LUCKY GUESSER"
    // Extremely Fast (1s) but Random Accuracy (True/False/True/False...)
    // This ensures fast times don't completely mask poor accuracy.
    test('Lucky Guesser', () {
      final scores = runGrading(
        results: [true, false, true, false, true, false],
        times: [1000, 1000, 1000, 1000, 1000, 1000],
      );

      // Raw Speed: 1.0 (Elite)
      // Accuracy: 0.5
      // IPS: 1.0 * sqrt(0.5) = 0.707
      expect(scores["Information Processing Speed"], closeTo(0.71, 0.02));
    });

    // 12. THE "CONSISTENT TURTLE"
    // 100% Correct, but consistently at the 14s mark.
    // Should get a decent score because they are reliable.
    test('Consistent Turtle', () {
      final scores = runGrading(
        results: [true, true, true, true, true, true],
        times: [14000, 14000, 14000, 14000, 14000, 14000],
      );

      // 14000ms Speed Score: ~0.54
      // Accuracy: 1.0
      // IPS: 0.54 * 1.0 = 0.54
      expect(scores["Information Processing Speed"], closeTo(0.54, 0.02));
    });

    // 13. THE "GIVE UP"
    // User played 1 round, got it wrong, then quit.
    // Should handle single-item arrays gracefully.
    test('Give Up Early', () {
      final scores = runGrading(
        results: [false],
        times: [5000],
      );

      // Accuracy 0 -> IPS 0
      expect(scores["Information Processing Speed"], 0.0);
      expect(scores["Inductive Reasoning"], 0.0);
    });
  });
}