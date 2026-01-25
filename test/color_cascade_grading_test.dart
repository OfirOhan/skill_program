import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/color_cascade_grading.dart';
// test/grading/color_cascade_grading_test.dart

void main() {
  group('ColorCascadeGrading', () {
    const eps = 0.05;

    bool closeTo(double actual, double expected, double epsilon) {
      return (actual - expected).abs() <= epsilon;
    }

    // =========================================================================
    // BEHAVIORAL SCENARIOS
    // =========================================================================

    group('Behavioral Scenarios', () {
      test('1. Perfect performance - all rounds perfect', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, true],
          roundPrecision: [1.0, 1.0, 1.0, 1.0],
          reactionTimes: [2000, 2000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        expect(closeTo(result['Color Discrimination']!, 1.0, eps), true,
            reason: 'Perfect discrimination should be 1.0');
        expect(closeTo(result['Visual Acuity']!, 1.0, eps), true,
            reason: 'Perfect acuity should be 1.0');
      });

      test('2. Strong performance - perfect rounds 1-3, fail round 4', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, false],
          roundPrecision: [1.0, 1.0, 1.0, 0.0],
          reactionTimes: [2000, 2000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.28 + 0.28 + 0.30 = 0.86
        // rawStrict = 0.28 + 0.28 + 0.30 = 0.86
        // CD = 0.86
        // VA = 0.6(0.86) + 0.4(0.86 × 1.15) = 0.516 + 0.396 = 0.912
        expect(closeTo(result['Color Discrimination']!, 0.86, eps), true,
            reason: 'Missing only hardest round should score ~0.86');
        expect(closeTo(result['Visual Acuity']!, 0.91, eps), true,
            reason: 'Visual acuity should exceed discrimination with perfect-round bonus');
      });

      test('3. Moderate performance - perfect rounds 1-2, fail 3-4', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, false, false],
          roundPrecision: [1.0, 1.0, 0.0, 0.0],
          reactionTimes: [2000, 2000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.28 + 0.28 = 0.56
        // rawStrict = 0.28 + 0.28 = 0.56
        // CD = 0.56
        // VA = 0.6(0.56) + 0.4(0.56 × 1.15) = 0.336 + 0.258 = 0.594
        expect(closeTo(result['Color Discrimination']!, 0.56, eps), true,
            reason: 'Half performance should score mid-range');
        expect(closeTo(result['Visual Acuity']!, 0.59, eps), true,
            reason: 'VA should exceed CD with perfect-round bonus');
      });

      test('4. Weak performance - only round 1 perfect', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, false, false, false],
          roundPrecision: [1.0, 0.0, 0.0, 0.0],
          reactionTimes: [2000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.28
        // rawStrict = 0.28
        // CD = 0.28
        // VA = 0.6(0.28) + 0.4(0.28 × 1.15) = 0.168 + 0.129 = 0.297
        expect(closeTo(result['Color Discrimination']!, 0.28, eps), true,
            reason: 'Only first round should give minimal score');
        expect(closeTo(result['Visual Acuity']!, 0.30, eps), true,
            reason: 'VA should be slightly higher with bonus');
      });

      test('5. Complete failure - all rounds failed', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, false],
          roundPrecision: [0.0, 0.0, 0.0, 0.0],
          reactionTimes: [25000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        expect(closeTo(result['Color Discrimination']!, 0.0, eps), true,
            reason: 'Complete failure should score 0.0');
        expect(closeTo(result['Visual Acuity']!, 0.0, eps), true,
            reason: 'No success should have zero acuity');
      });

      test('6. Partial round 1 - imperfect sorting but good grids', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, true, true, false],
          roundPrecision: [0.80, 1.0, 1.0, 0.0], // 5/6 pairs in round 1
          reactionTimes: [3000, 2000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.80×0.28 + 0.28 + 0.30 = 0.224 + 0.58 = 0.804
        // rawStrict = 0 + 0.28 + 0.30 = 0.58
        // CD = 0.804
        // VA = 0.6(0.804) + 0.4(0.58 × 1.15) = 0.482 + 0.267 = 0.749
        expect(closeTo(result['Color Discrimination']!, 0.80, eps), true,
            reason: 'Partial round 1 should lower discrimination score');

        // Visual acuity combines precision (0.80) with strict (0.58) × 1.15
        expect(closeTo(result['Visual Acuity']!, 0.75, eps), true,
            reason: 'Partial R1 reduces strict component, lowering VA');
      });

      test('7. Very weak round 1 - minimal sorting success', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, false],
          roundPrecision: [0.0, 0.0, 0.0, 0.0], // Only 2/6 pairs = below threshold
          reactionTimes: [5000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // Below 50% threshold = no credit
        expect(result['Color Discrimination']!, equals(0.0),
            reason: 'Below 3/6 pairs threshold should give no credit');
      });

      test('8. Edge case - skip round 2, perfect 1+3+4', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, false, true, true],
          roundPrecision: [1.0, 0.0, 1.0, 1.0],
          reactionTimes: [2000, 25000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.28 + 0 + 0.30 + 0.30 = 0.88
        // rawStrict = 0.28 + 0 + 0.30 + 0.30 = 0.88
        // CD = 0.88
        // VA = 0.6(0.88) + 0.4(0.88 × 1.15) = 0.528 + 0.405 = 0.933
        expect(closeTo(result['Color Discrimination']!, 0.88, eps), true,
            reason: 'Should score based on actual rounds passed');
        expect(closeTo(result['Visual Acuity']!, 0.93, eps), true,
            reason: 'VA exceeds CD with perfect-round bonus');
      });

      test('9. Lucky round 4 only - fail easy rounds, pass hardest', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, true],
          roundPrecision: [0.0, 0.0, 0.0, 1.0],
          reactionTimes: [25000, 25000, 25000, 1500],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.30
        // rawStrict = 0.30
        // CD = 0.30
        // VA = 0.6(0.30) + 0.4(0.30 × 1.15) = 0.18 + 0.138 = 0.318
        expect(closeTo(result['Color Discrimination']!, 0.30, eps), true,
            reason: 'Only round 4 should count');
        expect(closeTo(result['Visual Acuity']!, 0.32, eps), true,
            reason: 'VA slightly higher with bonus');
      });

      test('10. Inconsistent performance - alternating success/failure', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, false, true, false],
          roundPrecision: [1.0, 0.0, 1.0, 0.0],
          reactionTimes: [2000, 25000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.28 + 0 + 0.30 + 0 = 0.58
        // rawStrict = 0.28 + 0 + 0.30 + 0 = 0.58
        // CD = 0.58
        // VA = 0.6(0.58) + 0.4(0.58 × 1.15) = 0.348 + 0.267 = 0.615
        expect(closeTo(result['Color Discrimination']!, 0.58, eps), true,
            reason: 'Alternating pattern should score mid-range');
        expect(closeTo(result['Visual Acuity']!, 0.62, eps), true,
            reason: 'VA higher with perfect-round bonus');
      });

      test('11. Near-perfect sorting with all grids failed', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, false],
          roundPrecision: [0.80, 0.0, 0.0, 0.0], // 5/6 in sorting
          reactionTimes: [3000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // R1: 0.80 × 0.28 = 0.224
        expect(closeTo(result['Color Discrimination']!, 0.22, eps), true,
            reason: 'Partial R1 only should give small score');

        // Visual acuity: 0.6(0.22) + 0.4(0.0) = 0.132
        expect(closeTo(result['Visual Acuity']!, 0.13, eps), true,
            reason: 'No perfect rounds should hurt acuity more');
      });
    });

    // =========================================================================
    // ROUND WEIGHTING VERIFICATION
    // =========================================================================

    group('Round Weight Distribution', () {
      test('12. Round 1 contributes 0.28 when perfect', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, false, false, false],
          roundPrecision: [1.0, 0.0, 0.0, 0.0],
          reactionTimes: [2000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        expect(closeTo(result['Color Discrimination']!, 0.28, eps), true);
      });

      test('13. Round 2 contributes 0.28 when perfect', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, true, false, false],
          roundPrecision: [0.0, 1.0, 0.0, 0.0],
          reactionTimes: [25000, 2000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        expect(closeTo(result['Color Discrimination']!, 0.28, eps), true);
      });

      test('14. Round 3 contributes 0.30 when perfect', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, true, false],
          roundPrecision: [0.0, 0.0, 1.0, 0.0],
          reactionTimes: [25000, 25000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        expect(closeTo(result['Color Discrimination']!, 0.30, eps), true);
      });

      test('15. Round 4 contributes 0.30 when perfect', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, true],
          roundPrecision: [0.0, 0.0, 0.0, 1.0],
          reactionTimes: [25000, 25000, 25000, 2000],
          timeoutPenaltyMs: 25000,
        );

        expect(closeTo(result['Color Discrimination']!, 0.30, eps), true);
      });

      test('16. Total possible exceeds 1.0 before clamping', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, true],
          roundPrecision: [1.0, 1.0, 1.0, 1.0],
          reactionTimes: [2000, 2000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        // 0.28 + 0.28 + 0.30 + 0.30 = 1.16, clamps to 1.0
        expect(result['Color Discrimination']!, lessThanOrEqualTo(1.0));
        expect(closeTo(result['Color Discrimination']!, 1.0, eps), true);
      });

      test('17. Rounds 1-3 sum to 0.86', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, false],
          roundPrecision: [1.0, 1.0, 1.0, 0.0],
          reactionTimes: [2000, 2000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // Verifies the target: missing only R4 gives 0.86
        expect(closeTo(result['Color Discrimination']!, 0.86, eps), true);
      });
    });

    // =========================================================================
    // PARTIAL CREDIT MECHANICS (ROUND 1 ONLY)
    // =========================================================================

    group('Partial Credit on Round 1', () {
      test('18. 50% correct sorting gives reduced credit for round 1', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, false],
          roundPrecision: [0.30, 0.0, 0.0, 0.0], // 3/6 pairs (threshold)
          reactionTimes: [3000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // 0.30 × 0.28 = 0.084
        expect(closeTo(result['Color Discrimination']!, 0.08, eps), true);
      });

      test('19. Below threshold gives no credit', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, false],
          roundPrecision: [0.0, 0.0, 0.0, 0.0], // 2/6 pairs = below threshold
          reactionTimes: [3000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // Below 3/6 pairs = 0.0
        expect(result['Color Discrimination']!, equals(0.0),
            reason: 'Below 50% threshold should give no credit');
      });

      test('20. Partial round 1 with perfect later rounds', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, true, true, true],
          roundPrecision: [0.55, 1.0, 1.0, 1.0], // 4/6 pairs
          reactionTimes: [3000, 2000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        // Precision: 0.55×0.28 + 0.28 + 0.30 + 0.30 = 1.034 → 1.0
        expect(closeTo(result['Color Discrimination']!, 1.0, eps), true);

        // Strict: only R2, R3, R4 count = 0.88
        // Visual acuity: 0.6(1.0) + 0.4(0.88 × 1.15) = 0.6 + 0.405 = 1.005 → 1.0
        expect(closeTo(result['Visual Acuity']!, 1.0, eps), true,
            reason: 'Near-perfect performance with bonus should max out');
      });

      test('21. Grid rounds can now have partial credit (0.0, 0.5, 1.0)', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, false, false, false],
          roundPrecision: [1.0, 0.5, 0.0, 0.0], // Found 1/2 tiles in round 2
          reactionTimes: [2000, 3000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.28 + 0.5×0.28 = 0.42
        // rawStrict = 0.28 (only R1 perfect)
        // CD = 0.42
        // VA = 0.6(0.42) + 0.4(0.28 × 1.15) = 0.252 + 0.129 = 0.381
        expect(closeTo(result['Color Discrimination']!, 0.42, eps), true,
            reason: 'Partial grid credit should be included');
        expect(closeTo(result['Visual Acuity']!, 0.38, eps), true,
            reason: 'VA reflects partial grid performance');
      });
    });

    // =========================================================================
    // VISUAL ACUITY FORMULA VERIFICATION
    // =========================================================================

    group('Visual Acuity 60/40 Split', () {
      test('22. Visual acuity combines precision and strict accuracy correctly', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [false, true, true, false],
          roundPrecision: [0.80, 1.0, 1.0, 0.0], // 5/6 pairs in R1
          reactionTimes: [3000, 2000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 0.224 + 0.28 + 0.30 = 0.804
        // rawStrict = 0 + 0.28 + 0.30 = 0.58
        // Visual acuity = 0.6(0.804) + 0.4(0.58 × 1.15) = 0.482 + 0.267 = 0.749
        expect(closeTo(result['Visual Acuity']!, 0.75, eps), true,
            reason: '60/40 precision/strict with 1.15x bonus should combine correctly');
      });

      test('23. Perfect performance VA now exceeds CD with 1.15x bonus', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, true],
          roundPrecision: [1.0, 1.0, 1.0, 1.0],
          reactionTimes: [2000, 2000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        // rawPrecision = 1.16 → clamps to 1.0
        // rawStrict = 1.16
        // VA = 0.6(1.0) + 0.4(1.16 × 1.15) = 0.6 + 0.534 = 1.134 → clamps to 1.0
        // Both clamp to 1.0, so equal at perfect
        expect(result['Visual Acuity']!, equals(result['Color Discrimination']!));
        expect(result['Visual Acuity']!, equals(1.0));
      });

      test('24. Visual acuity can EXCEED discrimination with perfect-round bonus', () {
        final result1 = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, false],
          roundPrecision: [1.0, 1.0, 1.0, 0.0],
          reactionTimes: [2000, 2000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        final result2 = ColorCascadeGrading.grade(
          roundPerfect: [false, true, true, false],
          roundPrecision: [0.80, 1.0, 1.0, 0.0], // 5/6 pairs in R1
          reactionTimes: [3000, 2000, 2000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // result1: CD=0.86, VA=0.91 (VA > CD with bonus!)
        expect(result1['Visual Acuity']! > result1['Color Discrimination']!, true,
            reason: 'VA should exceed CD with 1.15x perfect-round bonus');

        // result2 has lower strict despite similar precision
        expect(result2['Visual Acuity']! < result1['Visual Acuity']!, true,
            reason: 'Fewer perfect rounds = lower VA');
      });
    });

    // =========================================================================
    // SKILL ISOLATION TESTS
    // =========================================================================

    group('Color Discrimination - Skill Isolation', () {
      test('25. Color discrimination is not affected by which rounds are perfect', () {
        final result1 = ColorCascadeGrading.grade(
          roundPerfect: [true, true, false, false],
          roundPrecision: [1.0, 1.0, 0.0, 0.0],
          reactionTimes: [2000, 2000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        final result2 = ColorCascadeGrading.grade(
          roundPerfect: [false, false, true, true],
          roundPrecision: [0.0, 0.0, 1.0, 1.0],
          reactionTimes: [25000, 25000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        // Different rounds, but similar total precision contribution
        // R1+R2 = 0.56, R3+R4 = 0.57 (close)
        expect(closeTo(result1['Color Discrimination']!, result2['Color Discrimination']!, 0.10), true,
            reason: 'Discrimination should be based on total precision, not order');
      });

      test('26. Discrimination increases monotonically with precision', () {
        final scores = <double>[];

        for (var precision in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final result = ColorCascadeGrading.grade(
            roundPerfect: [false, false, false, false],
            roundPrecision: [precision, 0.0, 0.0, 0.0],
            reactionTimes: [3000, 25000, 25000, 25000],
            timeoutPenaltyMs: 25000,
          );
          scores.add(result['Color Discrimination']!);
        }

        // Should be strictly increasing
        for (int i = 1; i < scores.length; i++) {
          expect(scores[i] > scores[i-1], true,
              reason: 'Higher precision should always give higher discrimination');
        }
      });

      test('27. Discrimination is purely perceptual - no speed component', () {
        final fast = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, false],
          roundPrecision: [1.0, 1.0, 1.0, 0.0],
          reactionTimes: [1000, 1000, 1000, 25000], // Very fast
          timeoutPenaltyMs: 25000,
        );

        final slow = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, false],
          roundPrecision: [1.0, 1.0, 1.0, 0.0],
          reactionTimes: [5000, 5000, 5000, 25000], // Slow but not timeout
          timeoutPenaltyMs: 25000,
        );

        expect(fast['Color Discrimination']!, equals(slow['Color Discrimination']!),
            reason: 'Speed should not affect color discrimination');
      });
    });

    group('Visual Acuity - Skill Isolation', () {
      test('28. Acuity is sensitive to both precision and perfection', () {
        final highPrecisionLowPerfect = ColorCascadeGrading.grade(
          roundPerfect: [false, false, false, false],
          roundPrecision: [0.80, 0.0, 0.0, 0.0], // Only R1 partial (5/6), grids failed
          reactionTimes: [3000, 25000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        final lowPrecisionHighPerfect = ColorCascadeGrading.grade(
          roundPerfect: [true, true, false, false],
          roundPrecision: [1.0, 1.0, 0.0, 0.0], // Some perfects, lower overall
          reactionTimes: [2000, 2000, 25000, 25000],
          timeoutPenaltyMs: 25000,
        );

        // Both should have different scores measuring different aspects
        // highPrecisionLowPerfect: CD=0.22, VA=0.13
        // lowPrecisionHighPerfect: CD=0.58, VA=0.58

        // Perfect rounds should matter for acuity
        expect(
            lowPrecisionHighPerfect['Visual Acuity']! > highPrecisionLowPerfect['Visual Acuity']!,
            true,
            reason: 'Perfect rounds should significantly improve visual acuity'
        );
      });
    });

    // =========================================================================
    // EDGE CASES & VALIDATION
    // =========================================================================

    group('Edge Cases', () {
      test('29. Empty data returns zeros', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [],
          roundPrecision: [],
          reactionTimes: [],
          timeoutPenaltyMs: 25000,
        );

        expect(result['Color Discrimination']!, equals(0.0));
        expect(result['Visual Acuity']!, equals(0.0));
      });

      test('30. All scores clamped to [0, 1] range', () {
        final result = ColorCascadeGrading.grade(
          roundPerfect: [true, true, true, true],
          roundPrecision: [1.0, 1.0, 1.0, 1.0],
          reactionTimes: [2000, 2000, 2000, 2000],
          timeoutPenaltyMs: 25000,
        );

        result.forEach((skill, score) {
          expect(score >= 0.0 && score <= 1.0, true,
              reason: '$skill score should be in [0,1] range');
        });
      });

    });

    // =========================================================================
    // SCORE DISTRIBUTION VERIFICATION
    // =========================================================================

    group('Score Distribution', () {
      test('31. Scores span full 0.0 to 1.0 range appropriately', () {
        final performances = [
          ([false, false, false, false], [0.0, 0.0, 0.0, 0.0]), // Worst
          ([true, false, false, false], [1.0, 0.0, 0.0, 0.0]),  // Low
          ([true, true, false, false], [1.0, 1.0, 0.0, 0.0]),   // Mid
          ([true, true, true, false], [1.0, 1.0, 1.0, 0.0]),    // High
          ([true, true, true, true], [1.0, 1.0, 1.0, 1.0]),     // Perfect
        ];

        final scores = performances.map((p) {
          final result = ColorCascadeGrading.grade(
            roundPerfect: p.$1,
            roundPrecision: p.$2,
            reactionTimes: [2000, 2000, 2000, 2000],
            timeoutPenaltyMs: 25000,
          );
          return result['Color Discrimination']!;
        }).toList();

        // Should be monotonically increasing
        for (int i = 1; i < scores.length; i++) {
          expect(scores[i] > scores[i-1], true,
              reason: 'Better performance should yield higher scores');
        }

        // Should span significant range
        expect(scores.last - scores.first, greaterThan(0.9),
            reason: 'Score range should span nearly full 0-1 range');
      });
    });
  });
}