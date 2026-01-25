import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/beat_buddy_grading.dart';
// test/grading/beat_buddy_grading_test.dart


void main() {
  group('BeatBuddyGrading -', () {

    // ==========================================
    // PITCH MATCHING TESTS
    // ==========================================

    group('Pitch Matching -', () {

      test('perfect pitch matching (0 cents error) scores 1.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0, 0.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(1.00, 0.05));
      });

      test('excellent pitch matching (5-15 cents avg) scores ~0.97-0.99', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [10.0, 12.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.98, 0.05));
      });

      test('very good pitch matching (20-25 cents avg) scores ~0.95-0.96', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [22.0, 24.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.95, 0.05));
      });

      test('good pitch matching (35-45 cents avg) scores ~0.85-0.88', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [38.0, 42.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.86, 0.05));
      });

      test('average pitch matching (70-80 cents avg) scores ~0.62-0.68', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [72.0, 78.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.65, 0.05));
      });

      test('below average pitch matching (120-150 cents avg) scores ~0.35-0.44', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [125.0, 145.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.39, 0.05));
      });

      test('poor pitch matching (200+ cents avg) scores <0.20', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [210.0, 220.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], lessThan(0.20));
      });

      test('very poor pitch matching (300+ cents = semitone) scores ~0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [310.0, 320.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.00, 0.05));
      });

      test('wildly inconsistent performance averages out correctly', () {
        // One perfect, one terrible - should average to moderate score
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [5.0, 200.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        // Average: 102.5 cents -> should be in below average range
        expect(result["Auditory Pitch/Tone"], closeTo(0.49, 0.05));
      });

      test('single trial performance is evaluated correctly', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [50.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.80, 0.05));
      });

      test('no pitch trials attempted scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], equals(0.00));
      });
    });

    // ==========================================
    // RHYTHM DISCRIMINATION TESTS
    // ==========================================

    group('Rhythm Discrimination -', () {

      test('perfect rhythm discrimination (5/5) scores 1.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(1.00));
      });

      test('excellent rhythm discrimination (4/5) scores 0.80', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 4,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(0.80));
      });

      test('good rhythm discrimination (3/5) scores 0.60', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(0.60));
      });

      test('below average rhythm discrimination (2/5) scores 0.40', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 2,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(0.40));
      });

      test('poor rhythm discrimination (1/5) scores 0.20', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 1,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(0.20));
      });

      test('no correct rhythm discrimination (0/5) scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 0,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(0.00));
      });

      test('no rhythm trials attempted scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Rhythm"], equals(0.00));
      });
    });

    // ==========================================
    // SKILL INDEPENDENCE TESTS
    // ==========================================

    group('Skill Independence -', () {

      test('excellent pitch with poor rhythm shows independent scoring', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [8.0, 12.0], // ~10 cents avg = excellent
          rhythmCorrect: 1,
          rhythmTotal: 5, // 20% = poor
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.98, 0.05));
        expect(result["Auditory Rhythm"], equals(0.20));
      });

      test('poor pitch with excellent rhythm shows independent scoring', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [180.0, 220.0], // ~200 cents avg = poor
          rhythmCorrect: 5,
          rhythmTotal: 5, // 100% = perfect
        );
        expect(result["Auditory Pitch/Tone"], lessThan(0.25));
        expect(result["Auditory Rhythm"], equals(1.00));
      });

      test('both skills can be average independently', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [70.0, 80.0], // ~75 cents avg = average
          rhythmCorrect: 3,
          rhythmTotal: 5, // 60% = average
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.65, 0.05));
        expect(result["Auditory Rhythm"], equals(0.60));
      });

      test('both skills can be excellent independently', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [5.0, 8.0], // ~6.5 cents avg = excellent
          rhythmCorrect: 5,
          rhythmTotal: 5, // 100% = perfect
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.99, 0.05));
        expect(result["Auditory Rhythm"], equals(1.00));
      });
    });

    // ==========================================
    // REALISTIC GAME SCENARIO TESTS
    // ==========================================

    group('Realistic Game Scenarios -', () {

      test('musical person: good pitch, good rhythm', () {
        // Someone with musical training
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [15.0, 20.0], // ~17.5 cents avg
          rhythmCorrect: 4,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.97, 0.05));
        expect(result["Auditory Rhythm"], equals(0.80));
      });

      test('non-musical person: average pitch, average rhythm', () {
        // Typical adult with no musical training
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [85.0, 95.0], // ~90 cents avg
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.56, 0.05));
        expect(result["Auditory Rhythm"], equals(0.60));
      });

      test('tone-deaf person: poor pitch, but can still detect rhythm', () {
        // Pitch perception deficit but intact rhythm
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [240.0, 280.0], // ~260 cents avg
          rhythmCorrect: 4,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.08, 0.05));
        expect(result["Auditory Rhythm"], equals(0.80));
      });

      test('rushed player: inconsistent pitch, missed some rhythm', () {
        // Someone rushing through without careful listening
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [120.0, 140.0], // ~130 cents avg
          rhythmCorrect: 2,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.41, 0.05));
        expect(result["Auditory Rhythm"], equals(0.40));
      });

      test('lucky guesser in rhythm section', () {
        // Poor pitch, got rhythm by chance (~50% would be pure guessing)
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [150.0, 170.0], // ~160 cents avg
          rhythmCorrect: 3,
          rhythmTotal: 5, // 60% - slightly above chance
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.32, 0.05));
        expect(result["Auditory Rhythm"], equals(0.60));
      });

      test('timeout scenario: some trials completed, others skipped', () {
        // Player ran out of time mid-game
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [50.0], // Only completed 1 pitch trial
          rhythmCorrect: 2,
          rhythmTotal: 3, // Only completed 3/5 rhythm trials
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.80, 0.05));
        expect(result["Auditory Rhythm"], closeTo(0.67, 0.05));
      });

      test('perfectionist: took time, excellent on both', () {
        // Someone who carefully matched everything
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [3.0, 7.0], // ~5 cents avg
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], closeTo(0.99, 0.05));
        expect(result["Auditory Rhythm"], equals(1.00));
      });

      test('beginner who improved during game', () {
        // Started poorly, got better with practice
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [150.0, 60.0], // Improved from 150 to 60 cents
          rhythmCorrect: 3,
          rhythmTotal: 5, // Got better at detecting patterns
        );
        // Average of 105 cents
        expect(result["Auditory Pitch/Tone"], closeTo(0.48, 0.05));
        expect(result["Auditory Rhythm"], equals(0.60));
      });
    });

    // ==========================================
    // EDGE CASES & BOUNDARY CONDITIONS
    // ==========================================

    group('Edge Cases -', () {

      test('maximum possible pitch error (800 Hz range = ~600 cents) scores 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [600.0, 600.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result["Auditory Pitch/Tone"], equals(0.00));
      });

      test('boundary at 25 cents (transition from excellent to good)', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [24.0, 24.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [26.0, 26.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result1["Auditory Pitch/Tone"]! - result2["Auditory Pitch/Tone"]!, lessThan(0.02));
      });

      test('boundary at 50 cents (transition from good to average)', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [49.0, 49.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [51.0, 51.0],
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        expect(result1["Auditory Pitch/Tone"]! - result2["Auditory Pitch/Tone"]!, lessThan(0.02));
      });

      test('scores are properly rounded to 2 decimal places', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [33.3333, 33.3333],
          rhythmCorrect: 1,
          rhythmTotal: 3,
        );
        // Check that scores have exactly 2 decimal places
        expect(result["Auditory Pitch/Tone"].toString().split('.')[1].length, lessThanOrEqualTo(2));
        expect(result["Auditory Rhythm"].toString().split('.')[1].length, lessThanOrEqualTo(2));
      });

      test('all skills present in output map', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [50.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );
        expect(result.keys.length, equals(2));
        expect(result.containsKey("Auditory Pitch/Tone"), isTrue);
        expect(result.containsKey("Auditory Rhythm"), isTrue);
      });

      test('scores never exceed 1.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [0.0, 0.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], lessThanOrEqualTo(1.00));
        expect(result["Auditory Rhythm"], lessThanOrEqualTo(1.00));
      });

      test('scores never go below 0.00', () {
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [1000.0, 1000.0],
          rhythmCorrect: 0,
          rhythmTotal: 5,
        );
        expect(result["Auditory Pitch/Tone"], greaterThanOrEqualTo(0.00));
        expect(result["Auditory Rhythm"], greaterThanOrEqualTo(0.00));
      });
    });

    // ==========================================
    // DIFFICULTY CURVE VALIDATION
    // ==========================================

    group('Difficulty Curve Validation -', () {

      test('early rounds (easy) allow for higher rhythm scores', () {
        // With 300ms and 200ms deltas (rounds 0-1), even average people should score well
        // This is implicitly tested by the 60% = 3/5 scoring average
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [100.0, 100.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(0.60));
      });

      test('later rounds (hard) make perfect scores meaningful', () {
        // With 60ms deltas (round 4), 5/5 = truly exceptional temporal discrimination
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [100.0, 100.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );
        expect(result["Auditory Rhythm"], equals(1.00));
      });

      test('pitch difficulty is consistent across rounds', () {
        // Pitch uses random 300-700 Hz range consistently
        // Both rounds should contribute equally to average
        final result = BeatBuddyGrading.grade(
          pitchErrorsCents: [30.0, 90.0], // One good round, one worse round
          rhythmCorrect: 0,
          rhythmTotal: 0,
        );
        // Average = 60 cents, should be in average range
        expect(result["Auditory Pitch/Tone"], closeTo(0.74, 0.05));
      });
    });

    // ==========================================
    // COMPARATIVE SCENARIOS
    // ==========================================

    group('Comparative Scenarios -', () {

      test('better pitch performance yields higher score', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [20.0, 25.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );
        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [80.0, 90.0],
          rhythmCorrect: 3,
          rhythmTotal: 5,
        );
        expect(result1["Auditory Pitch/Tone"]!, greaterThan(result2["Auditory Pitch/Tone"]!));
      });

      test('better rhythm performance yields higher score', () {
        final result1 = BeatBuddyGrading.grade(
          pitchErrorsCents: [50.0, 50.0],
          rhythmCorrect: 5,
          rhythmTotal: 5,
        );
        final result2 = BeatBuddyGrading.grade(
          pitchErrorsCents: [50.0, 50.0],
          rhythmCorrect: 2,
          rhythmTotal: 5,
        );
        expect(result1["Auditory Rhythm"]!, greaterThan(result2["Auditory Rhythm"]!));
      });

      test('pitch score changes smoothly with performance', () {
        // Verify no sudden jumps in scoring
        final scores = <double>[];
        for (double cents = 0; cents <= 100; cents += 10) {
          final result = BeatBuddyGrading.grade(
            pitchErrorsCents: [cents, cents],
            rhythmCorrect: 0,
            rhythmTotal: 0,
          );
          scores.add(result["Auditory Pitch/Tone"]!);
        }

        // Each score should be less than previous (monotonic decrease)
        for (int i = 1; i < scores.length; i++) {
          expect(scores[i], lessThan(scores[i - 1]));
        }
      });
    });
  });
}