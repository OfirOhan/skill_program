import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/precision_grading.dart';

void main() {
  group('Precision Grading Tests', () {
    test('No Levels', () {
      final scores = PrecisionGrading.grade(
        metricLevels: 0,
        levelsCompleted: 0,
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );
      expect(scores["Fine Motor Control"], equals(0.0));
    });

    test('Perfect Precision', () {
      final scores = PrecisionGrading.grade(
        metricLevels: 1,
        levelsCompleted: 3, // Full game
        sumOffRate: 0.0,
        sumDevNorm: 0.0,
      );
      expect(scores["Fine Motor Control"], equals(1.0));
      expect(scores["Visuomotor Integration"], equals(1.0));
    });

    test('Shaky Hand', () {
      final scores = PrecisionGrading.grade(
        metricLevels: 1,
        levelsCompleted: 3,
        sumOffRate: 0.5, // 50% off track
        sumDevNorm: 0.2,
      );
      expect(scores["Movement Steadiness"], lessThan(1.0));
      expect(scores["Fine Motor Control"], lessThan(1.0));
    });
  });
}
