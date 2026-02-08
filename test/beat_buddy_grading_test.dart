import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/beat_buddy_grading.dart';
// test/grading/beat_buddy_grading_test.dart

void main() {
  group('BeatBuddyGrading', () {
    const eps = 0.05;

    bool closeTo(double actual, double expected, double epsilon) {
      return (actual - expected).abs() <= epsilon;
    }

    // =========================================================================
    // BEHAVIORAL SCENARIOS
    // =========================================================================

    group('Behavioral Scenarios', () {
      test('1. Perfect performance - both skills maxed', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0, 0.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 1.00, eps), true,
            reason: 'Perfect pitch matching should be 1.0');
        expect(result['Auditory Rhythm']!, equals(1.00),
            reason: 'Perfect rhythm discrimination should be 1.0');
      });

      test('2. Musical person - good pitch, good rhythm', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [18.0, 25.0], // ~21.5 cents avg
          rhythmCorrect: 4,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.84, eps), true,
            reason: 'Good pitch matching should score ~0.84');
        expect(result['Auditory Rhythm']!, equals(0.80),
            reason: '4/5 rhythm should be 0.80');
      });

      test('3. Average adult - typical performance', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [65.0, 75.0], // ~70 cents avg
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.50, eps), true,
            reason: '70 cents avg should map to exactly 0.50');
        expect(result['Auditory Rhythm']!, equals(0.60),
            reason: '3/5 rhythm is average performance');
      });

      test('4. Tone-deaf person - poor pitch, intact rhythm', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [195.0, 215.0], // ~205 cents avg
          rhythmCorrect: 4,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.06, eps), true,
            reason: 'Tone-deaf range should score very low');
        expect(result['Auditory Rhythm']!, equals(0.80),
            reason: 'Rhythm can be intact despite pitch deficit');
      });

      test('5. Rushed player - inconsistent pitch, poor rhythm', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [110.0, 130.0], // ~120 cents avg
          rhythmCorrect: 2,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.25, eps), true,
            reason: 'Below average pitch should score ~0.25');
        expect(result['Auditory Rhythm']!, equals(0.40),
            reason: '2/5 rhythm is below average');
      });

      test('6. Lucky guesser - poor pitch, random rhythm success', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [140.0, 160.0], // ~150 cents avg
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.16, eps), true,
            reason: 'Poor pitch perception should score low');
        expect(result['Auditory Rhythm']!, equals(0.60),
            reason: '60% is slightly above chance (50%)');
      });

      test('7. Early quit - player stops after 3 rhythm trials', () {
        // Player quit early: finished both pitch rounds, only 3/5 rhythm trials
        // The 2 unfinished rhythm trials count as WRONG (0 points)
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0], // Completed both pitch rounds
          rhythmCorrect: 2,
          rhythmTotal: 5, // All 5 trials happened (last 2 timed out = wrong)
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.50, eps), true,
            reason: 'Average pitch performance');
        expect(result['Auditory Rhythm']!, equals(0.40),
            reason: 'Got 2/5 correct (3 answered, 2 correct, then quit = 2 timeouts)');
      });

      test('7b. Pitch timeout - slider left at default', () {
        // Timer ran out, slider never moved from 440 Hz default
        // Target was 500 Hz → error = ~225 cents
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [225.0, 225.0], // Both rounds timed out at default
          rhythmCorrect: 0,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.04, eps), true,
            reason: 'Timeout with default slider should score very poorly');
        expect(result['Auditory Rhythm']!, equals(0.00),
            reason: 'No rhythm answers given');
      });

      test('7c. Rhythm timeout - no answer given', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 0,
          rhythmTotal: 5, // All 5 trials timed out
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.50, eps), true,
            reason: 'Pitch unaffected by rhythm timeout');
        expect(result['Auditory Rhythm']!, equals(0.00),
            reason: 'All rhythm timeouts count as wrong (0/5)');
      });

      test('10. Perfectionist - excellent on both', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [3.0, 7.0], // ~5 cents avg
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.97, eps), true,
            reason: 'Expert-level pitch should score ~0.97');
        expect(result['Auditory Rhythm']!, equals(1.00),
            reason: 'Perfect rhythm discrimination');
      });

      test('11. Beginner who improved - learning curve', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [120.0, 50.0], // Improved from 120 to 50
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        // Average = 85 cents
        expect(closeTo(result['Auditory Pitch/Tone']!, 0.40, eps), true,
            reason: '85 cents avg should be in average-low range');
        expect(result['Auditory Rhythm']!, equals(0.60),
            reason: 'Got better at detecting patterns');
      });

      test('12. Complete failure - no discrimination shown', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [310.0, 320.0], // ~315 cents (>3 semitones)
          rhythmCorrect: 0,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.00, eps), true,
            reason: 'Extreme pitch error should score 0.00');
        expect(result['Auditory Rhythm']!, equals(0.00),
            reason: 'No correct rhythm discrimination');
      });

      test('13. Excellent pitch with poor rhythm', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [8.0, 12.0], // ~10 cents avg
          rhythmCorrect: 1,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.93, eps), true,
            reason: 'Expert pitch matching should score high');
        expect(result['Auditory Rhythm']!, equals(0.20),
            reason: 'Skills are independent - pitch doesn\'t help rhythm');
      });

      test('14. Poor pitch with excellent rhythm', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [190.0, 210.0], // ~200 cents avg
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.07, eps), true,
            reason: 'Poor pitch perception despite good rhythm');
        expect(result['Auditory Rhythm']!, equals(1.00),
            reason: 'Skills are independent - rhythm doesn\'t need pitch');
      });

      test('15. Both skills average independently', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [68.0, 72.0], // ~70 cents avg
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.50, eps), true,
            reason: 'Average pitch performance');
        expect(result['Auditory Rhythm']!, equals(0.60),
            reason: 'Average rhythm performance');
      });

      test('16. Wildly inconsistent pitch performance', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [5.0, 155.0], // One perfect, one terrible
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        // Average = 80 cents
        expect(closeTo(result['Auditory Pitch/Tone']!, 0.43, eps), true,
            reason: 'Inconsistency averages to moderate score');
        expect(result['Auditory Rhythm']!, equals(0.60),
            reason: 'Rhythm unaffected by pitch inconsistency');
      });
    });

    // =========================================================================
    // PITCH SCORING CURVE VERIFICATION
    // =========================================================================

    group('Pitch Scoring Curve', () {
      test('17. Perfect pitch (0 cents) scores 1.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0, 0.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 1.00, eps), true);
      });

      test('18. Expert range (8-12 cents avg) scores ~0.92-0.95', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [10.0, 12.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.93, eps), true,
            reason: 'Expert musician level');
      });

      test('19. Good range (25-35 cents avg) scores ~0.75-0.82', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [28.0, 32.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.78, eps), true,
            reason: 'Above average pitch perception');
      });

      test('20. Average range (60-80 cents avg) scores ~0.45-0.55', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [65.0, 75.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.50, eps), true,
            reason: 'Calibration point - 70 cents = 0.50');
      });

      test('21. Below average (110-140 cents avg) scores ~0.18-0.25', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [120.0, 130.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.23, eps), true,
            reason: 'Below average pitch discrimination');
      });

      test('22. Poor range (190-210 cents avg) scores ~0.05-0.09', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [195.0, 205.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.07, eps), true,
            reason: 'Tone-deaf range');
      });

      test('23. Very poor (300+ cents) scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [310.0, 320.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.00, eps), true,
            reason: 'Beyond 3 semitones = complete failure');
      });

      test('24. Single pitch trial - game crashed after round 1', () {
        // Edge case: game crashed/quit after first pitch round
        // In reality, this shouldn't happen, but testing grading handles it
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0], // Only 1 round before crash
          rhythmCorrect: 0,
          rhythmTotal: 5, // Rhythm still happened (all wrong/timeout)
        );

        expect(closeTo(result['Auditory Pitch/Tone']!, 0.50, eps), true,
            reason: 'Single 70-cent trial should score 0.50');
        expect(result['Auditory Rhythm']!, equals(0.00),
            reason: 'All rhythm trials timed out');
      });

      test('25. Maximum possible error (600 cents) scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [600.0, 600.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result['Auditory Pitch/Tone']!, equals(0.00),
            reason: 'Beyond reasonable range');
      });
    });

    // =========================================================================
    // RHYTHM SCORING VERIFICATION
    // =========================================================================

    group('Rhythm Scoring', () {
      test('26. Perfect rhythm (5/5) scores 1.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        expect(result['Auditory Rhythm']!, equals(1.00));
      });

      test('27. Excellent rhythm (4/5) scores 0.80', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 4,
          rhythmTotal: 5,
        );

        expect(result['Auditory Rhythm']!, equals(0.80));
      });

      test('28. Good rhythm (3/5) scores 0.60', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result['Auditory Rhythm']!, equals(0.60));
      });

      test('29. Below average rhythm (2/5) scores 0.40', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 2,
          rhythmTotal: 5,
        );

        expect(result['Auditory Rhythm']!, equals(0.40),
            reason: 'Approaching random guessing territory');
      });

      test('30. Poor rhythm (1/5) scores 0.20', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 1,
          rhythmTotal: 5,
        );

        expect(result['Auditory Rhythm']!, equals(0.20));
      });

      test('31. No rhythm discrimination (0/5) scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 0,
          rhythmTotal: 5,
        );

        expect(result['Auditory Rhythm']!, equals(0.00));
      });

      test('32. Game crashed before rhythm stage', () {
        // Edge case: game crashed after pitch but before rhythm started
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 70.0],
          rhythmCorrect: 0,
          rhythmTotal: 0, // Rhythm stage never started
        );

        expect(result['Auditory Rhythm']!, equals(0.00),
            reason: 'No rhythm data = no score');
      });
    });

    // =========================================================================
    // SKILL ISOLATION TESTS
    // =========================================================================

    group('Skill Isolation', () {
      test('33. Pitch and rhythm are independently measurable', () {
        final excellentPitchPoorRhythm = BeatBuddyGrading.grade(
          pitchErrorsCents: [8.0, 12.0],
          rhythmCorrect: 1,
          rhythmTotal: 5,
        );

        final poorPitchExcellentRhythm = BeatBuddyGrading.grade(
          pitchErrorsCents: [190.0, 210.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        // These should show clear independence
        expect(excellentPitchPoorRhythm['Auditory Pitch/Tone']! > 0.90, true);
        expect(excellentPitchPoorRhythm['Auditory Rhythm']! < 0.30, true);

        expect(poorPitchExcellentRhythm['Auditory Pitch/Tone']! < 0.10, true);
        expect(poorPitchExcellentRhythm['Auditory Rhythm']! == 1.00, true);
      });

      test('34. Pitch score monotonically decreases with error', () {
        final scores = <double>[];

        for (var cents in [0.0, 20.0, 50.0, 80.0, 120.0, 180.0, 250.0]) {
          final result = BeatBuddyGrading.grade(
            pitchErrorsCents: [cents, cents],
            rhythmCorrect: 3,
            rhythmTotal: 5,
          );
          scores.add(result['Auditory Pitch/Tone']!);
        }

        // Should be strictly decreasing
        for (int i = 1; i < scores.length; i++) {
          expect(scores[i] < scores[i-1], true,
              reason: 'Higher pitch error should always give lower score');
        }
      });

      test('35. Rhythm score monotonically increases with correct answers', () {
        final scores = <double>[];

        for (var correct in [0, 1, 2, 3, 4, 5]) {
          final result = BeatBuddyGrading.grade(
            pitchErrorsCents: [70.0, 70.0],
            rhythmCorrect: correct,
            rhythmTotal: 5,
          );
          scores.add(result['Auditory Rhythm']!);
        }

        // Should be strictly increasing
        for (int i = 1; i < scores.length; i++) {
          expect(scores[i] > scores[i-1], true,
              reason: 'More correct answers should give higher score');
        }
      });

      test('36. Pitch is purely perceptual - no order effects', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [30.0, 110.0], // Good then bad
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [110.0, 30.0], // Bad then good
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result1['Auditory Pitch/Tone']!, equals(result2['Auditory Pitch/Tone']!),
            reason: 'Order of pitch errors should not matter');
      });
    });

    // =========================================================================
    // BOUNDARY CONDITIONS
    // =========================================================================

    group('Boundary Conditions', () {
      test('37. Boundary at 15 cents (expert → good transition)', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [14.0, 14.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [16.0, 16.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result1['Auditory Pitch/Tone']! - result2['Auditory Pitch/Tone']!, lessThan(0.03),
            reason: 'Smooth transition at boundary');
      });

      test('38. Boundary at 40 cents (good → average transition)', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [39.0, 39.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [41.0, 41.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result1['Auditory Pitch/Tone']! - result2['Auditory Pitch/Tone']!, lessThan(0.03),
            reason: 'Smooth transition at boundary');
      });

      test('39. Boundary at 100 cents (average → below average transition)', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [99.0, 99.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [101.0, 101.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result1['Auditory Pitch/Tone']! - result2['Auditory Pitch/Tone']!, lessThan(0.02),
            reason: 'Smooth transition at boundary');
      });

      test('40. Scores rounded to 2 decimal places', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [33.3333, 33.3333],
          rhythmCorrect: 2,
          rhythmTotal: 5,
        );

        // Check formatting
        expect(result['Auditory Pitch/Tone'].toString().split('.')[1].length, lessThanOrEqualTo(2));
        expect(result['Auditory Rhythm'].toString().split('.')[1].length, lessThanOrEqualTo(2));
      });
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    group('Edge Cases', () {
      test('41. Empty pitch data returns zeros', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );

        expect(result['Auditory Pitch/Tone']!, equals(0.0));
        expect(result['Auditory Rhythm']!, equals(0.0));
      });

      test('42. All scores clamped to [0, 1] range', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0, 0.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        result.forEach((skill, score) {
          expect(score >= 0.0 && score <= 1.0, true,
              reason: '$skill score should be in [0,1] range');
        });
      });

      test('43. Scores never exceed 1.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0, 0.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );

        expect(result['Auditory Pitch/Tone']!, lessThanOrEqualTo(1.00));
        expect(result['Auditory Rhythm']!, lessThanOrEqualTo(1.00));
      });

      test('44. Scores never go below 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [1000.0, 1000.0],
          rhythmCorrect: 0,
          rhythmTotal: 5,
        );

        expect(result['Auditory Pitch/Tone']!, greaterThanOrEqualTo(0.00));
        expect(result['Auditory Rhythm']!, greaterThanOrEqualTo(0.00));
      });

      test('45. All skills present in output map', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [50.0, 50.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );

        expect(result.keys.length, equals(2));
        expect(result.containsKey('Auditory Pitch/Tone'), isTrue);
        expect(result.containsKey('Auditory Rhythm'), isTrue);
      });
    });

    // =========================================================================
    // SCORE DISTRIBUTION VERIFICATION
    // =========================================================================

    group('Score Distribution', () {
      test('46. Pitch scores span full 0.0 to 1.0 range appropriately', () {
        final performances = [
          [300.0, 300.0],  // Worst
          [150.0, 150.0],  // Poor
          [70.0, 70.0],    // Average
          [30.0, 30.0],    // Good
          [0.0, 0.0],      // Perfect
        ];

        final scores = performances.map((cents) {
          final result = BeatBuddyGrading.grade(
            pitchErrorsCents: cents,
            rhythmCorrect: 0,
            rhythmTotal: 0,
          );
          return result['Auditory Pitch/Tone']!;
        }).toList();

        // Should be monotonically increasing (less error = higher score)
        for (int i = 1; i < scores.length; i++) {
          expect(scores[i] > scores[i-1], true,
              reason: 'Better pitch performance should yield higher scores');
        }

        // Should span significant range
        expect(scores.last - scores.first, greaterThan(0.9),
            reason: 'Score range should span nearly full 0-1 range');
      });

      test('47. Rhythm scores span full 0.0 to 1.0 range', () {
        final performances = [0, 1, 2, 3, 4, 5];

        final scores = performances.map((correct) {
          final result = BeatBuddyGrading.grade(
            pitchErrorsCents: [70.0],
            rhythmCorrect: correct,
            rhythmTotal: 5,
          );
          return result['Auditory Rhythm']!;
        }).toList();

        // Should span exactly 0.0 to 1.0
        expect(scores.first, equals(0.0));
        expect(scores.last, equals(1.0));
        expect(scores.last - scores.first, equals(1.0));
      });
    });
  });
}