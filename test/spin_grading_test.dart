import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/spin_grading.dart';

void main() {
  group('Spin Grading Tests', () {
    test('Empty Game', () {
      final scores = SpinGrading.grade(
        results: [],
        reactionTimes: [],
        limits: [],
      );
      expect(scores["Mental Rotation"], equals(0.0));
    });

    test('Perfect Rotator', () {
      final scores = SpinGrading.grade(
        results: [true, true, true],
        reactionTimes: [0, 0, 0], // Instant
        limits: [5000, 5000, 5000],
      );
      // Smoothed Acc: (3+1)/(3+2) = 4/5 = 0.8
      // Speed: 1.0
      // Mental Rotation: 0.75*0.8 + 0.25*(1.0*0.8) = 0.6 + 0.2 = 0.8
      expect(scores["Mental Rotation"], equals(0.8));
    });

    test('Inaccurate Player', () {
      final scores = SpinGrading.grade(
        results: [false, false, false],
        reactionTimes: [1000, 1000, 1000],
        limits: [5000, 5000, 5000],
      );
      // Smoothed Acc: (0+1)/(3+2) = 0.2
      expect(scores["Mental Rotation"], closeTo(0.19, 0.01)); // 0.75*0.2 + 0.25*speed*0.2
    });
  });
}
