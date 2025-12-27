import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/color_cascade_grading.dart';

void main() {
  group('Color Cascade Grading Tests', () {
    test('No Rounds', () {
      final scores = ColorCascadeGrading.grade(
        totalCorrect: 0,
        totalPrecision: 0.0,
        rounds: 0,
        reactionTimes: [],
        timeoutPenaltyMs: 30000,
      );
      expect(scores["Color Discrimination"], equals(0.0));
    });

    test('Perfect Play', () {
      final scores = ColorCascadeGrading.grade(
        totalCorrect: 5,
        totalPrecision: 5.0,
        rounds: 5,
        reactionTimes: [2000, 2000, 2000, 2000, 2000], // Fast
        timeoutPenaltyMs: 30000,
      );
      expect(scores["Color Discrimination"], equals(1.0));
      expect(scores["Information Processing Speed"], greaterThan(0.9));
    });

    test('Low Precision', () {
      final scores = ColorCascadeGrading.grade(
        totalCorrect: 0, // No perfect sorts
        totalPrecision: 2.5, // 50% precision overall
        rounds: 5,
        reactionTimes: [10000, 10000, 10000, 10000, 10000],
        timeoutPenaltyMs: 30000,
      );
      expect(scores["Color Discrimination"], equals(0.5));
      expect(scores["Pattern Recognition"], lessThan(0.5)); // Penalized by lack of perfect sorts
    });
  });
}
