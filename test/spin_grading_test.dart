import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/spin_grading.dart';

void main() {
  const double eps = 0.05;

  group('SpinGrading – Realistic Behavioral Scenarios (4 Levels)', () {

    test('Perfect spatial master – all correct, all fast', () {
      final scores = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [3000, 4000, 4500, 3500],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(1.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(1.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(1.0, eps));
    });

    test('Total failure – cannot rotate mentally', () {
      final scores = SpinGrading.grade(
        results: [false, false, false, false],
        reactionTimes: [10000, 12000, 15000, 18000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.0, eps));
    });

    test('Slow but accurate – can rotate but takes full time', () {
      final scores = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [18000, 19000, 18500, 19500],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(1.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(1.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.53, eps));
    });

    test('Fast but wrong – speed without spatial ability', () {
      final scores = SpinGrading.grade(
        results: [false, false, false, false],
        reactionTimes: [4000, 5000, 5500, 4500],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.0, eps));
    });

    test('Learning curve – fails early, succeeds later', () {
      final scores = SpinGrading.grade(
        results: [false, false, true, true],
        reactionTimes: [15000, 14000, 8000, 7000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.5, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.5, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.44, eps));
    });

    test('Fatigue or difficulty spike – strong start, weak finish', () {
      final scores = SpinGrading.grade(
        results: [true, true, false, false],
        reactionTimes: [6000, 7000, 16000, 18000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.5, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.5, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.48, eps));
    });

    test('Moderate performer – all correct, average speed', () {
      final scores = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [10000, 11000, 10500, 11500],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(1.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(1.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.81, eps));
    });

    test('Three out of four correct – good but not perfect', () {
      final scores = SpinGrading.grade(
        results: [true, false, true, true],
        reactionTimes: [7000, 12000, 9000, 8000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.75, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.75, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.74, eps));
    });

    test('Alternating success – inconsistent', () {
      final scores = SpinGrading.grade(
        results: [true, false, true, false],
        reactionTimes: [8000, 14000, 9000, 15000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.5, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.5, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.44, eps));
    });

    test('Only level 1 correct – minimal spatial ability', () {
      final scores = SpinGrading.grade(
        results: [true, false, false, false],
        reactionTimes: [8000, 15000, 16000, 17000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.25, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.25, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.15, eps));
    });

    test('Only level 4 correct – got lucky or focused only on hard', () {
      final scores = SpinGrading.grade(
        results: [false, false, false, true],
        reactionTimes: [10000, 12000, 14000, 6000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.25, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.25, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.16, eps));
    });

    test('All timeouts – complete failure to engage', () {
      final scores = SpinGrading.grade(
        results: [false, false, false, false],
        reactionTimes: [20000, 20000, 20000, 20000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.0, eps));
    });

    test('Perfect accuracy with varied speed', () {
      final scores = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [4000, 19000, 8000, 15000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(1.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(1.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.78, eps));
    });

    test('Getting faster – learning to process quicker', () {
      final scores = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [15000, 12000, 9000, 6000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(1.0, eps));
      expect(scores['Spatial Awareness']!, closeTo(1.0, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.82, eps));
    });

    test('Half correct – 50% spatial ability', () {
      final scores = SpinGrading.grade(
        results: [true, true, false, false],
        reactionTimes: [10000, 11000, 14000, 15000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(scores['Mental Rotation']!, closeTo(0.5, eps));
      expect(scores['Spatial Awareness']!, closeTo(0.5, eps));
      expect(scores['Information Processing Speed']!, closeTo(0.41, eps));
    });
  });

  group('SpinGrading – Skill Isolation Logic', () {

    test('Mental Rotation ignores speed', () {
      final fast = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [2000, 3000, 2500, 3500],
        limits: [20000, 20000, 20000, 20000],
      );

      final slow = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [18000, 19000, 18500, 19500],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(fast['Mental Rotation']!, closeTo(1.0, eps));
      expect(slow['Mental Rotation']!, closeTo(1.0, eps));
    });

    test('Spatial Awareness with half wrong', () {
      final halfWrong = SpinGrading.grade(
        results: [true, false, true, false],
        reactionTimes: [8000, 10000, 9000, 11000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(halfWrong['Mental Rotation']!, closeTo(0.5, eps));
      expect(halfWrong['Spatial Awareness']!, closeTo(0.5, eps));
    });

    test('IPS rewards fast correct answers', () {
      final fast = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [3000, 4000, 3500, 4500],
        limits: [20000, 20000, 20000, 20000],
      );

      final slow = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [15000, 16000, 17000, 18000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(fast['Information Processing Speed']!, closeTo(1.0, eps));
      expect(slow['Information Processing Speed']!, closeTo(0.62, eps));
    });

    test('IPS gives zero for wrong answers', () {
      final fastWrong = SpinGrading.grade(
        results: [false, false, false, false],
        reactionTimes: [1000, 2000, 1500, 2500],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(fastWrong['Information Processing Speed']!, closeTo(0.0, eps));
    });

    test('IPS at perfect threshold is maximum', () {
      final atThreshold = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [5000, 5000, 5000, 5000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(atThreshold['Information Processing Speed']!, closeTo(1.0, eps));
    });

    test('IPS linear scaling verification', () {
      final at10s = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [10000, 10000, 10000, 10000],
        limits: [20000, 20000, 20000, 20000],
      );

      final at12_5s = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [12500, 12500, 12500, 12500],
        limits: [20000, 20000, 20000, 20000],
      );

      final at15s = SpinGrading.grade(
        results: [true, true, true, true],
        reactionTimes: [15000, 15000, 15000, 15000],
        limits: [20000, 20000, 20000, 20000],
      );

      expect(at10s['Information Processing Speed']!, closeTo(0.83, eps));
      expect(at12_5s['Information Processing Speed']!, closeTo(0.75, eps));
      expect(at15s['Information Processing Speed']!, closeTo(0.67, eps));
    });
  });
}