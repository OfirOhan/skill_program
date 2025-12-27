import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/word_group_grading.dart';

void main() {
  group('Word Group Grading Tests', () {
    test('Empty Game', () {
      final scores = WordGroupGrading.grade(
        totalItems: 0,
        correctCount: 0,
        reactionTimes: [],
      );
      expect(scores["Vocabulary Breadth"], equals(0.0));
      // Default slow RT -> Fluency 0.0
      expect(scores["Verbal Fluency"], equals(0.0));
    });

    test('Perfect & Fast', () {
      final scores = WordGroupGrading.grade(
        totalItems: 10,
        correctCount: 10,
        reactionTimes: [2000, 2000], // 2000ms is the fast benchmark
      );
      expect(scores["Vocabulary Breadth"], equals(1.0));
      expect(scores["Verbal Fluency"], equals(1.0));
    });

    test('Slow & Wrong', () {
      final scores = WordGroupGrading.grade(
        totalItems: 5,
        correctCount: 0,
        reactionTimes: [7000, 7000], // 7000ms is very slow
      );
      expect(scores["Vocabulary Breadth"], equals(0.0));
      expect(scores["Verbal Fluency"], equals(0.0));
    });
  });
}
