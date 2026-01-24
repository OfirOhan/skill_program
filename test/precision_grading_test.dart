import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/precision_grading.dart';
// test/grading/precision_grading_test.dart


void main() {
  group('PrecisionGrading - Core Scenarios', () {

    test('1. Perfect performance: flawless execution', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );

      expect(result["Fine Motor Control"], closeTo(1.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(1.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(1.0, 0.05));
    });

    test('2. Complete failure: unable to perform task', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 0,
        sumOffRate: 3.0,
        sumDevNorm: 3.0,
      );

      expect(result["Fine Motor Control"], closeTo(0.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.0, 0.05));
    });

    test('3. Your actual performance: 5.3% dev, 1.2% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.037,
        sumDevNorm: 0.16,
      );

      expect(result["Fine Motor Control"], closeTo(0.82, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.91, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.86, 0.05));
    });

  });

  group('PrecisionGrading - Excellence Levels', () {

    test('4. Near perfect: 2% dev, 1% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.03,
        sumDevNorm: 0.06,
      );

      expect(result["Fine Motor Control"], closeTo(0.91, 0.05));
      expect(result["Visuomotor Integration"], closeTo(1.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.90, 0.05));
    });

    test('5. Excellent: 5% dev, 3% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.09,
        sumDevNorm: 0.15,
      );

      expect(result["Fine Motor Control"], closeTo(0.76, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.83, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.72, 0.05));
    });

    test('6. Very good: 10% dev, 5% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.15,
        sumDevNorm: 0.30,
      );

      expect(result["Fine Motor Control"], closeTo(0.56, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.61, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.52, 0.05));
    });

    test('7. Good: 15% dev, 8% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.24,
        sumDevNorm: 0.45,
      );

      expect(result["Fine Motor Control"], closeTo(0.32, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.34, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.24, 0.05));
    });

  });

  group('PrecisionGrading - Average to Poor', () {

    test('8. Above average: 20% dev, 9% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.27,
        sumDevNorm: 0.60,
      );

      expect(result["Fine Motor Control"], closeTo(0.16, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.17, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.12, 0.05));
    });

    test('9. Average: 25% dev, 10% off (at thresholds)', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.30,
        sumDevNorm: 0.75,
      );

      expect(result["Fine Motor Control"], closeTo(0.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.0, 0.05));
    });

    test('10. Below average: over thresholds, incomplete', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 2,
        sumOffRate: 0.36,
        sumDevNorm: 0.90,
      );

      expect(result["Fine Motor Control"], closeTo(0.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.0, 0.05));
    });

    test('11. Poor: way over thresholds', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 1,
        sumOffRate: 0.45,
        sumDevNorm: 1.05,
      );

      expect(result["Fine Motor Control"], closeTo(0.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.0, 0.05));
    });

    test('12. Anti-cheat triggered', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 1,
        sumOffRate: 2.4,
        sumDevNorm: 2.4,
      );

      expect(result["Fine Motor Control"], closeTo(0.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.0, 0.05));
    });

  });

  group('PrecisionGrading - HIGH DEV, LOW OFF (Shaky but Contained)', () {

    test('13. Shaky contained: 25% dev, 3% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.09,
        sumDevNorm: 0.75,
      );

      expect(result["Fine Motor Control"], closeTo(0.28, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.35, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.56, 0.05));

      // Steadiness should be HIGHEST
      expect(
          result["Movement Steadiness"]!,
          greaterThan(result["Fine Motor Control"]! + 0.20),
          reason: "Low off-path = high steadiness"
      );
    });

    test('14. Tremor moderate: 20% dev, 2% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.06,
        sumDevNorm: 0.60,
      );

      expect(result["Fine Motor Control"], closeTo(0.44, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.52, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.68, 0.05));
    });

    test('15. Wobbly on-path: 30% dev, 5% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.15,
        sumDevNorm: 0.90,
      );

      expect(result["Fine Motor Control"], closeTo(0.20, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.25, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.40, 0.05));
    });

  });

  group('PrecisionGrading - LOW DEV, HIGH OFF (Precise but Crosses Boundaries)', () {

    test('16. Crosses boundaries: 5% dev, 15% off, incomplete', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 2,
        sumOffRate: 0.45,
        sumDevNorm: 0.15,
      );

      expect(result["Fine Motor Control"], closeTo(0.48, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.40, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.16, 0.05));

      // Steadiness should be LOWEST
      expect(
          result["Movement Steadiness"]!,
          lessThan(result["Fine Motor Control"]!),
          reason: "High off-path crushes steadiness"
      );
    });

    test('17. Edge rider: 8% dev, 12% off, incomplete', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 2,
        sumOffRate: 0.36,
        sumDevNorm: 0.24,
      );

      expect(result["Fine Motor Control"], closeTo(0.41, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.34, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.14, 0.05));
    });

    test('18. Frequent off-path: 6% dev, 10% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.30,
        sumDevNorm: 0.18,
      );

      expect(result["Fine Motor Control"], closeTo(0.46, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.46, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.15, 0.05));
    });

  });

  group('PrecisionGrading - Balanced & Patterns', () {

    test('19. Balanced errors: 15% dev, 6% off', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.18,
        sumDevNorm: 0.45,
      );

      expect(result["Fine Motor Control"], closeTo(0.40, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.44, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.40, 0.05));
    });

    test('20. Heavy balanced: 20% dev, 8% off, incomplete', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 2,
        sumOffRate: 0.24,
        sumDevNorm: 0.60,
      );

      expect(result["Fine Motor Control"], closeTo(0.20, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.18, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.20, 0.05));
    });

    test('21. Improving pattern', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.27,
        sumDevNorm: 0.75,
      );

      expect(result["Fine Motor Control"], closeTo(0.04, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.05, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.08, 0.05));
    });

    test('22. Declining pattern: incomplete', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 2,
        sumOffRate: 0.30,
        sumDevNorm: 0.60,
      );

      expect(result["Fine Motor Control"], closeTo(0.12, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.10, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.04, 0.05));
    });

    test('23. Single level: 1/3 completion (70% bonus)', () {
      final result = PrecisionGrading.grade(
        metricLevels: 1,
        levelsCompleted: 1,
        sumOffRate: 0.06,
        sumDevNorm: 0.15,
      );

      // Fine and Steadiness unaffected, Visuomotor gets 70% bonus
      expect(result["Fine Motor Control"], closeTo(0.40, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.28, 0.05));
      expect(result["Movement Steadiness"], closeTo(0.40, 0.05));
    });

  });

  group('PrecisionGrading - Completion Impact (Only Visuomotor)', () {

    test('24. Perfect tracking, no completion', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 0,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );

      // Fine and Steadiness unaffected, Visuomotor gets 50% penalty
      expect(result["Fine Motor Control"], closeTo(1.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.50, 0.05));
      expect(result["Movement Steadiness"], closeTo(1.0, 0.05));
    });

    test('25. Perfect tracking, partial completion', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 2,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );

      // Fine and Steadiness at 1.0, Visuomotor at 90%
      expect(result["Fine Motor Control"], closeTo(1.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(0.90, 0.05));
      expect(result["Movement Steadiness"], closeTo(1.0, 0.05));
    });

    test('26. Perfect tracking, full completion gets BONUS', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );

      // All at 1.0 (visuomotor bonus clamped)
      expect(result["Fine Motor Control"], closeTo(1.0, 0.05));
      expect(result["Visuomotor Integration"], closeTo(1.0, 0.05));
      expect(result["Movement Steadiness"], closeTo(1.0, 0.05));
    });

    test('27. Good tracking, completion affects only visuomotor', () {
      final noCompletion = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 0,
        sumOffRate: 0.15,
        sumDevNorm: 0.30,
      );

      final fullCompletion = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.15,
        sumDevNorm: 0.30,
      );

      // Fine Motor should be identical
      expect(
          (noCompletion["Fine Motor Control"]! -
              fullCompletion["Fine Motor Control"]!).abs(),
          lessThan(0.02),
          reason: "Fine motor unaffected by completion"
      );

      // Visuomotor should increase significantly
      expect(
          fullCompletion["Visuomotor Integration"]!,
          greaterThan(noCompletion["Visuomotor Integration"]! + 0.30),
          reason: "Visuomotor requires completion"
      );

      // Steadiness should be identical
      expect(
          (noCompletion["Movement Steadiness"]! -
              fullCompletion["Movement Steadiness"]!).abs(),
          lessThan(0.02),
          reason: "Steadiness unaffected by completion"
      );
    });

  });

  group('PrecisionGrading - Skill Differentiation', () {

    test('28. Steadiness prioritizes off-path over deviation', () {
      final lowOffHighDev = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.09,
        sumDevNorm: 0.75,
      );

      final highOffLowDev = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.30,
        sumDevNorm: 0.15,
      );

      expect(
          lowOffHighDev["Movement Steadiness"]!,
          greaterThan(highOffLowDev["Movement Steadiness"]! + 0.30),
          reason: "Steadiness cares 80% about off-path"
      );
    });

  });

  group('PrecisionGrading - Edge Cases', () {

    test('29. No data: returns zeros', () {
      final result = PrecisionGrading.grade(
        metricLevels: 0,
        levelsCompleted: 0,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );

      expect(result["Fine Motor Control"], 0.0);
      expect(result["Visuomotor Integration"], 0.0);
      expect(result["Movement Steadiness"], 0.0);
    });

    test('30. Values clamped to [0, 1]', () {
      final result = PrecisionGrading.grade(
        metricLevels: 3,
        levelsCompleted: 3,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );

      result.forEach((skill, score) {
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      });
    });

  });
}