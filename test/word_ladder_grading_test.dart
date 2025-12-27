import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/word_ladder_grading.dart';

void main() {
  group('Word Ladder Grading Tests', () {
    test('Zero Items', () {
      final scores = WordLadderGrading.grade(
        totalItems: 0,
        results: [],
        reactionTimes: [],
        categories: [],
      );
      expect(scores["Inductive Reasoning"], equals(0.0));
    });

    test('Inductive vs Abstract', () {
      final scores = WordLadderGrading.grade(
        totalItems: 4,
        results: [true, true, false, false],
        reactionTimes: [1000, 1000, 1000, 1000],
        categories: ["SCALE", "SYSTEMS", "OTHER", "OTHER"],
      );
      // "SCALE" and "SYSTEMS" are Inductive. Both true -> 1.0
      // "OTHER" is Abstract. Both false -> 0.0
      expect(scores["Inductive Reasoning"], equals(1.0));
      expect(scores["Abstract Thinking"], equals(0.0));
    });

    test('Speed Scaling', () {
      final scores = WordLadderGrading.grade(
        totalItems: 2,
        results: [true, true],
        reactionTimes: [800, 800], // Very fast -> speed 1.0
        categories: ["SCALE", "SCALE"],
      );
      expect(scores["Information Processing Speed"], greaterThan(0.9));
    });
  });
}
