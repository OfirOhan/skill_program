import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/brick_grading.dart';

void main() {
  group('Brick Grading Tests', () {
    test('No Ideas', () {
      final scores = BrickGrading.grade(
        ideas: [],
        keywordFrequency: {},
        divergentDuration: 45,
        divergentUsedMs: 45000,
        convergentChosen: false,
        selectedOptionIndex: -1,
        convergentDecisionMs: -1,
        convergentDuration: 10,
      );
      expect(scores["Ideation Fluency"], equals(0.0));
    });

    test('One Valid Idea, No Choice', () {
      final scores = BrickGrading.grade(
        ideas: ["build a wall"],
        keywordFrequency: {"build": 1, "wall": 1},
        divergentDuration: 45,
        divergentUsedMs: 45000,
        convergentChosen: false,
        selectedOptionIndex: -1,
        convergentDecisionMs: -1,
        convergentDuration: 10,
      );
      // 1 idea over 45 seconds is slow, so fluency should be low but > 0
      expect(scores["Ideation Fluency"], greaterThan(0.0));
      expect(scores["Planning & Prioritization"], equals(0.0));
    });

    test('Valid Creative Session', () {
      final scores = BrickGrading.grade(
        ideas: ["doorstop", "paperweight"], // Common ideas, low originality
        keywordFrequency: {"doorstop": 1, "paperweight": 1},
        divergentDuration: 45,
        divergentUsedMs: 10000, // Very fast
        convergentChosen: true,
        selectedOptionIndex: 0,
        convergentDecisionMs: 2000, // Fast decision
        convergentDuration: 10,
      );
      // 2 ideas in 10s = 0.2 ideas/sec = 1 idea/5sec = target. Fluency should be high.
      expect(scores["Ideation Fluency"], closeTo(1.0, 0.1));
      expect(scores["Decision Under Pressure"], greaterThan(0.0));
    });
  });
}
