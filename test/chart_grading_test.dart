import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/chart_grading.dart';

void main() {
  group('Chart Grading Tests', () {
    test('Empty Data', () {
      final scores = ChartGrading.grade(
        results: [],
        reactionTimes: [],
        isMathQuestion: [],
      );
      expect(scores["Quantitative Reasoning"], equals(0.0));
    });

    test('Perfect Score', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, true, true],
        reactionTimes: [1500, 1500, 1500, 1500, 1500], // Very fast
        isMathQuestion: [true, true, true, true, true], // All math
      );
      expect(scores["Quantitative Reasoning"], equals(1.0));
      expect(scores["Information Processing Speed"], equals(1.0));
    });

    test('Mixed Performance', () {
      final scores = ChartGrading.grade(
        results: [true, false],
        reactionTimes: [5000, 5000],
        isMathQuestion: [true, false],
      );
      // Math: 1 question, correct. Accuracy 100%, but evidence low (1/5).
      expect(scores["Quantitative Reasoning"], lessThan(1.0));
      expect(scores["Quantitative Reasoning"], greaterThan(0.0));
    });
  });
}
