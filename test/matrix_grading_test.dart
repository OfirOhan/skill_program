import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/matrix_grading.dart';

void main() {
  group('Matrix Logic Grading – Scenarios', () {

    // Helper to run grading quickly
    Map<String, double> runGrade({
      required List<String> types,
      required List<int> diffs,
      required List<bool> results,
      List<int>? times,
    }) {
      return gradeMatrixFromStats(
        itemDescriptions: types,
        itemDifficulties: diffs,
        itemResults: results,
        itemTimesMs: times ?? List.filled(types.length, 5000),
      );
    }

    test('Scenario: "The Mathematician" (Quantitative Specialist)', () {
      // LOGIC: Player gets math questions right, but misses pattern/logic questions.

      final scores = runGrade(
        types: ["Arithmetic", "Subtraction", "Rotation", "Sudoku Logic (Unique Row/Col)"],
        diffs: [5, 2, 1, 4],
        results: [true, true, false, false], // Got Math (5+2) right, missed others
      );

      expect(scores["Quantitative Reasoning"], equals(1.0),
          reason: "Got 100% of the Quantitative difficulty points.");

      expect(scores["Inductive Reasoning"], equals(0.0),
          reason: "Missed the Inductive (Rotation) item.");

      expect(scores["Deductive Reasoning"], equals(0.0),
          reason: "Missed the Deductive (Sudoku) item.");
    });

    test('Scenario: "The Pattern Spotter" (Inductive Specialist)', () {
      // LOGIC: Player sees rotations/cycles easily, but fails math/deduction.

      final scores = runGrade(
        types: ["Rotation", "Cyclic Pattern", "Arithmetic"],
        diffs: [1, 3, 5],
        results: [true, true, false],
      );

      expect(scores["Inductive Reasoning"], equals(1.0));
      expect(scores["Quantitative Reasoning"], equals(0.0));
    });

    test('Scenario: "The Fast Guesser" (Speed vs Accuracy)', () {
      // LOGIC:
      // Player A: 100ms answers, all wrong.
      // Player B: 5000ms answers, all right.

      final fastGuesser = runGrade(
        types: ["Rotation"],
        diffs: [1],
        results: [false],
        times: [100], // 0.1s
      );

      final steadyPlayer = runGrade(
        types: ["Rotation"],
        diffs: [1],
        results: [true],
        times: [5000], // 5s
      );

      // Fast guesser should get 0 speed score because Accuracy is 0.
      expect(fastGuesser["Information Processing Speed"], equals(0.0),
          reason: "Speed score must be 0 if accuracy is 0 (prevents spamming).");

      expect(steadyPlayer["Information Processing Speed"], greaterThan(0.6),
          reason: "Reasonable speed with accuracy yields good score.");
    });

    test('Scenario: "The Deep Thinker" (Hard vs Easy Items)', () {
      // LOGIC:
      // Player A gets Hard items (Diff 6) right.
      // Player B gets Easy items (Diff 1) right.
      // Both have same raw count (1/2), but Player A has higher Weighted Accuracy.
      // Therefore, Player A should have a slightly higher Speed Score (if times are equal).

      final deepThinker = runGrade(
        types: ["Column XOR", "Rotation"],
        diffs: [6, 1],
        results: [true, false], // Got Hard (6)
        times: [5000, 5000],
      );

      final averageJoe = runGrade(
        types: ["Column XOR", "Rotation"],
        diffs: [6, 1],
        results: [false, true], // Got Easy (1)
        times: [5000, 5000],
      );

      // Deep Thinker Weighted Acc: 6 / 7 = 0.85
      // Average Joe Weighted Acc: 1 / 7 = 0.14

      expect(
          deepThinker["Information Processing Speed"],
          greaterThan(averageJoe["Information Processing Speed"]! * 3), // Much higher
          reason: "Solving harder problems implies deeper/better processing, boosting the score."
      );
    });

    test('Edge Case: Median Calculation (Outlier Protection)', () {
      // 3 items. 2 normal (2s), 1 massive delay (14s).
      final outlierScores = runGrade(
        types: ["Rotation", "Rotation", "Rotation"],
        diffs: [1, 1, 1],
        results: [true, true, true],
        times: [2000, 2000, 14000],
      );

      // Median is 2000.
      // Score should be high.
      expect(outlierScores["Information Processing Speed"], greaterThan(0.8));
    });

  });
}