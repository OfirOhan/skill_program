import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/logic_blocks_grading.dart';

void main() {
  group('Logic Blocks Grading Tests', () {
    test('Empty Game', () {
      final scores = LogicBlocksGrading.grade(
        playedGridSizes: [],
        levelSolved: [],
        levelTimeMs: [],
        levelMovesList: [],
        levelWastedCycles: [],
      );
      expect(scores["Deductive Reasoning"], equals(0.0));
    });

    test('Perfect Game', () {
      final scores = LogicBlocksGrading.grade(
        playedGridSizes: [3], // 9 tiles
        levelSolved: [true],
        levelTimeMs: [1000],
        levelMovesList: [9], // Minimum moves
        levelWastedCycles: [0],
      );
      expect(scores["Deductive Reasoning"], equals(1.0));
      // algorithmic logic > 0 since solved efficiently
      expect(scores["Algorithmic Logic"], greaterThan(0.0));
    });

    test('Failed Level', () {
      final scores = LogicBlocksGrading.grade(
        playedGridSizes: [3],
        levelSolved: [false],
        levelTimeMs: [10000],
        levelMovesList: [20],
        levelWastedCycles: [5],
      );
      expect(scores["Deductive Reasoning"], equals(0.0));
    });
  });
}
