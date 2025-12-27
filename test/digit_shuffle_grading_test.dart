import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/digit_shuffle_grading.dart';

void main() {
  group('Digit Shuffle Grading Tests', () {
    test('Zero Data', () {
      final scores = DigitShuffleGrading.grade(
        roundAccuracies: [],
        roundTimesMs: [],
        roundTaskTypes: [],
      );
      expect(scores["Working Memory"], equals(0.0));
    });

    test('Perfect Score', () {
      // 3 rounds: Recall, Sort, Add. All perfect.
      final scores = DigitShuffleGrading.grade(
        roundAccuracies: [1.0, 1.0, 1.0],
        roundTimesMs: [1000, 1000, 1000],
        roundTaskTypes: [0, 1, 2],
      );
      expect(scores["Rote Memorization"], equals(1.0));
      expect(scores["Working Memory"], equals(1.0));
      expect(scores["Quantitative Reasoning"], equals(1.0));
    });

    test('Cognitive Flexibility Test', () {
      // 3 rounds, switching tasks.
      // Round 0: Type 0 (Start)
      // Round 1: Type 1 (Switch)
      // Round 2: Type 1 (Stay)
      final scores = DigitShuffleGrading.grade(
        roundAccuracies: [1.0, 1.0, 1.0],
        roundTimesMs: [1000, 1000, 1000],
        roundTaskTypes: [0, 1, 1],
      );
      // Both switch and stay accuracy is 1.0, time is 1000. Ratios are 1.0.
      expect(scores["Cognitive Flexibility"], closeTo(1.0, 0.01));
    });
  });
}
