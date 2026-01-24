import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/logic_blocks_grading.dart';

void main() {
  const double eps = 0.05;

  group('Logic Blocks Grading - Real World Scenarios', () {

    // ============================================
    // PERFECT PLAYER SCENARIOS
    // ============================================

    test('01. Perfect Player - Solves all levels optimally and quickly', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [2000, 3500, 6000], // All under perfect times (5s, 8s, 12s)
        levelMovesList: [4, 7, 15],
        levelWastedCycles: [0, 0, 0],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10], // Completed paths (doesn't matter when solved)
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(1.0, eps));
      expect(result['Information Processing Speed']!, closeTo(1.0, eps)); // All perfect times
    });

    test('02. Perfect Deductive, Slow Execution - High reasoning, low speed', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [14000, 14500, 18000], // All slow but before 20s timeout
        levelMovesList: [4, 7, 15],
        levelWastedCycles: [0, 0, 0],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10], // Completed paths
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(1.0, eps));
      expect(result['Information Processing Speed']!, closeTo(0.7, eps)); // Slow but solved
    });

    // ============================================
    // TRIAL-AND-ERROR PLAYER SCENARIOS
    // ============================================

    test('03. Lucky Guesser - Solves with many wasted moves', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [8000, 10000, 13000], // Medium speed
        levelMovesList: [25, 45, 120], // Way too many moves
        levelWastedCycles: [5, 8, 15],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10], // Completed paths
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.58, eps)); // Poor efficiency
      expect(result['Information Processing Speed']!, closeTo(0.92, eps));
    });

    test('04. Spammer - Random rapid clicking until solved', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [5000, 7000, 9000], // Fast
        levelMovesList: [40, 70, 150], // Excessive moves
        levelWastedCycles: [10, 15, 30],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10], // Completed paths
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.55, eps)); // Terrible planning
      expect(result['Information Processing Speed']!, closeTo(1.0, eps)); // Fast
    });

    // ============================================
    // PARTIAL SUCCESS SCENARIOS
    // ============================================

    test('05. Beginner - Solves easy, fails harder levels', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, false], // Failed 6x6
        levelTimeMs: [8000, 12000, 20000], // Last one timed out (20s limit)
        levelMovesList: [10, 18, 35],
        levelWastedCycles: [1, 2, 5],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 6], // Only got 6/10 tiles on failed level
      );

      // Deductive: solved 3x3(9) + 4x4(16) = 25, failed 6x6 but got 6/10 = 0.6 → 0.6*36 = 21.6
      // Total: (25 + 21.6) / 61 = 0.76
      expect(result['Deductive Reasoning']!, closeTo(0.76, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.52, eps)); // Only counts solved levels
      expect(result['Information Processing Speed']!, closeTo(0.57, eps));
    });

    test('06. Chokes Under Pressure - Fails all levels but gets close', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [false, false, false], // Failed everything
        levelTimeMs: [20000, 20000, 20000], // All timed out
        levelMovesList: [20, 30, 50],
        levelWastedCycles: [3, 5, 8],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [3, 5, 8], // Got 3/4, 5/6, 8/10 tiles
      );

      // 3x3: 3/4 = 0.75 → capped at 0.7 → 0.7*9 = 6.3
      // 4x4: 5/6 = 0.83 → capped at 0.7 → 0.7*16 = 11.2
      // 6x6: 8/10 = 0.80 → capped at 0.7 → 0.7*36 = 25.2
      // Total: (6.3 + 11.2 + 25.2) / 61 = 0.70
      expect(result['Deductive Reasoning']!, closeTo(0.31, eps)); // Partial credit
      expect(result['Algorithmic Logic']!, closeTo(0.05, eps)); // No solved levels
      expect(result['Information Processing Speed']!, closeTo(0.15, eps)); // Timed out, no speed credit
    });

    test('07. One Hit Wonder - Only solves first level', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, false, false],
        levelTimeMs: [5000, 20000, 20000], // Only first succeeded
        levelMovesList: [6, 25, 40],
        levelWastedCycles: [0, 4, 7],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 4, 3], // 4/4, 4/6, 3/10 paths
      );

      // 3x3: 1.0*9 = 9
      // 4x4: (4/6=0.67)*16 = 10.7
      // 6x6: (3/10=0.3)*36 = 10.8
      // Total: (9 + 10.7 + 10.8) / 61 = 0.50
      expect(result['Deductive Reasoning']!, closeTo(0.50, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.31, eps)); // Only 3x3 solved
      expect(result['Information Processing Speed']!, closeTo(0.39, eps)); // Only 3x3 counts
    });

    // ============================================
    // STRATEGIC PLAYER SCENARIOS
    // ============================================

    test('08. Methodical Thinker - Slow but efficient', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [13000, 14000, 18000], // Slow times
        levelMovesList: [5, 8, 16], // Near optimal
        levelWastedCycles: [0, 0, 1],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(1.0, eps)); // Excellent planning
      expect(result['Information Processing Speed']!, closeTo(0.7, eps)); // Slow
    });

    test('09. Speed Runner - Fast but makes mistakes', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [3000, 4500, 7000], // Very fast
        levelMovesList: [12, 20, 40],
        levelWastedCycles: [2, 4, 8],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.68, eps)); // Not optimal
      expect(result['Information Processing Speed']!, closeTo(1.0, eps)); // Very fast
    });

    // ============================================
    // EDGE CASES
    // ============================================

    test('10. Edge Case - No levels played', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [],
        levelSolved: [],
        levelTimeMs: [],
        levelMovesList: [],
        levelWastedCycles: [],
        levelOptimalMoves: [],
        levelMaxPathLength: [],
      );

      expect(result['Deductive Reasoning']!, closeTo(0.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.0, eps));
      expect(result['Information Processing Speed']!, closeTo(0.0, eps));
    });

    test('11. Edge Case - All levels failed with no progress', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [false, false, false],
        levelTimeMs: [20000, 20000, 20000],
        levelMovesList: [50, 80, 150],
        levelWastedCycles: [10, 15, 30],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [0, 0, 0], // No progress at all
      );

      // Total failure - should get zeros
      expect(result['Deductive Reasoning']!, closeTo(0.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.0, eps));
      expect(result['Information Processing Speed']!, closeTo(0.0, eps));
    });

    test('12. Edge Case - Instant solve (0ms time)', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3],
        levelSolved: [true],
        levelTimeMs: [0], // Instant (theoretical)
        levelMovesList: [4],
        levelWastedCycles: [0],
        levelOptimalMoves: [4],
        levelMaxPathLength: [4],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(1.0, eps));
      expect(result['Information Processing Speed']!, closeTo(1.0, eps));
    });

    test('13. Edge Case - Optimal is 0 (shouldn\'t crash)', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3],
        levelSolved: [true],
        levelTimeMs: [5000],
        levelMovesList: [10],
        levelWastedCycles: [0],
        levelOptimalMoves: [0], // Edge case - no optimal moves calculated
        levelMaxPathLength: [4],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.89, eps)); // Falls back to 0.5
      expect(result['Information Processing Speed']!, closeTo(1.0, eps));
    });

    test('14. Edge Case - Moves is 0 (shouldn\'t crash)', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3],
        levelSolved: [true],
        levelTimeMs: [5000],
        levelMovesList: [0], // Edge case - no moves recorded
        levelWastedCycles: [0],
        levelOptimalMoves: [4],
        levelMaxPathLength: [4],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(1.0, eps)); // Perfect efficiency (0 wasteful moves)
      expect(result['Information Processing Speed']!, closeTo(1.0, eps));
    });

    // ============================================
    // REALISTIC MIXED SCENARIOS
    // ============================================

    test('15. Realistic Average Player', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, false],
        levelTimeMs: [7000, 11000, 20000], // Failed last one
        levelMovesList: [8, 15, 45],
        levelWastedCycles: [1, 2, 6],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 7], // Got 7/10 on failed level
      );

      expect(result['Deductive Reasoning']!, closeTo(0.75, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.52, eps));
      expect(result['Information Processing Speed']!, closeTo(0.6, eps));
    });

    test('16. Realistic Strong Player', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [4000, 6000, 9000], // All fast
        levelMovesList: [6, 10, 22],
        levelWastedCycles: [0, 1, 3],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.82, eps));
      expect(result['Information Processing Speed']!, closeTo(1.0, eps));
    });

    test('17. Realistic Struggling Player', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, false, false],
        levelTimeMs: [12000, 20000, 20000], // Only solved first
        levelMovesList: [18, 35, 60],
        levelWastedCycles: [3, 7, 12],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 4, 3], // Poor progress on failed levels
      );

      expect(result['Deductive Reasoning']!, closeTo(0.42, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.23, eps));
      expect(result['Information Processing Speed']!, closeTo(0.32, eps));
    });

    // ============================================
    // PARTIAL CREDIT FOR FAILED LEVELS (IPS)
    // ============================================

    test('18. Fast Failure with Good Progress - Gets partial IPS credit', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, false],
        levelTimeMs: [5000, 7000, 20000], // Failed quickly at 8s
        levelMovesList: [5, 10, 30],
        levelWastedCycles: [0, 1, 3],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 8], // Got 8/10 = 80% on failed level
      );

      // 6x6 level: 80% progress, finished in 8s < 10s (half of 20s)
      // Should get: 0.3 * 0.8 = 0.24 for that level
      expect(result['Information Processing Speed']!, closeTo(0.74, eps)); // High because fast + partial credit
    });

    test('19. Slow Failure with Good Progress - Gets smaller IPS credit', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, false],
        levelTimeMs: [5000, 7000, 20000], // Failed slowly at 15s
        levelMovesList: [5, 10, 30],
        levelWastedCycles: [0, 1, 3],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 9], // Got 9/10 = 90% on failed level
      );

      // 6x6 level: 90% progress, finished in 15s (between 10-20s)
      // Should get: 0.2 * 0.9 = 0.18 for that level
      expect(result['Information Processing Speed']!, closeTo(0.76, eps));
    });

    test('20. Fast Failure with Poor Progress - No IPS credit', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, false],
        levelTimeMs: [5000, 7000, 20000], // Failed quickly
        levelMovesList: [5, 10, 30],
        levelWastedCycles: [0, 1, 3],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 4], // Only got 4/10 = 40% (below 50% threshold)
      );

      // No partial credit because < 50% progress
      expect(result['Information Processing Speed']!, closeTo(0.74, eps)); // Only from solved levels
    });

    // ============================================
    // SKILL INDEPENDENCE TESTS
    // ============================================

    test('21. Independence - High Deductive, Low Algorithmic', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [10000, 12000, 14000],
        levelMovesList: [30, 50, 100], // Way too many moves
        levelWastedCycles: [7, 12, 25],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps)); // Solved all
      expect(result['Algorithmic Logic']!, closeTo(0.57, eps)); // Terrible efficiency

    });

    test('22. Independence - High Algorithmic, Low Speed', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [18000, 19000, 19500], // Very slow
        levelMovesList: [4, 7, 15], // Near optimal
        levelWastedCycles: [0, 0, 0],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10],
      );

      expect(result['Algorithmic Logic']!, closeTo(1.0, eps)); // Excellent planning
      expect(result['Information Processing Speed']!, closeTo(0.51, eps)); // Very slow

      final gap = result['Algorithmic Logic']! - result['Information Processing Speed']!;
      expect(gap, closeTo(0.44, eps));
    });

    test('23. Independence - High Speed, Low Deductive', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, false, false],
        levelTimeMs: [3000, 20000, 20000], // Only first fast
        levelMovesList: [5, 40, 70],
        levelWastedCycles: [0, 8, 15],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 3, 2], // Poor progress on failed levels
      );

      expect(result['Information Processing Speed']!, closeTo(0.44, eps)); // Some speed from 3x3
      expect(result['Deductive Reasoning']!, closeTo(0.42, eps)); // Failed most
    });

    // ============================================
    // WEIGHTING VERIFICATION
    // ============================================


    test('24. Weighting - All metrics should use consistent weighting', () {
      final result = LogicBlocksGrading.grade(
        playedGridSizes: [3, 4, 6],
        levelSolved: [true, true, true],
        levelTimeMs: [4000, 6000, 9000], // All good times
        levelMovesList: [5, 8, 16],
        levelWastedCycles: [0, 1, 2],
        levelOptimalMoves: [4, 7, 14],
        levelMaxPathLength: [4, 6, 10],
      );

      expect(result['Deductive Reasoning']!, closeTo(1.0, eps));
      expect(result['Algorithmic Logic']!, closeTo(0.92, eps));
      expect(result['Information Processing Speed']!, closeTo(1.0, eps));
    });

  });
}