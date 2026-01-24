// grading/logic_blocks_grading.dart
import 'dart:math';

class LogicBlocksGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<int> playedGridSizes,
    required List<bool> levelSolved,
    required List<int> levelTimeMs,
    required List<int> levelMovesList,
    required List<int> levelWastedCycles,
    required List<int> levelOptimalMoves,
    required List<int> levelMaxPathLength,
  }) {
    final int n = [
      playedGridSizes.length,
      levelSolved.length,
      levelTimeMs.length,
      levelMovesList.length,
      levelWastedCycles.length,
      levelOptimalMoves.length,
      levelMaxPathLength.length,
    ].reduce(min);

    if (n <= 0) {
      return {
        "Deductive Reasoning": 0.0,
        "Algorithmic Logic": 0.0,
        "Information Processing Speed": 0.0,
      };
    }

    // EQUAL WEIGHTING: Each level counts the same
    // Scores can exceed 1.0 per level to reward excellence
    double sumDeductive = 0.0;
    double sumAlgo = 0.0;
    double sumSpeed = 0.0;

    for (int i = 0; i < n; i++) {
      final int size = playedGridSizes[i];

      final bool solved = levelSolved[i];
      final int timeMs = levelTimeMs[i];
      final int moves = levelMovesList[i];
      final int optimalMoves = levelOptimalMoves[i];
      final int wastedCycles = levelWastedCycles[i];
      final int maxPathLength = levelMaxPathLength[i];

      // ============================================
      // DEDUCTIVE REASONING
      // ============================================
      // Measures: Ability to trace logical connections and find valid paths
      //
      // SOLVED LEVELS: Full credit (1.0)
      // FAILED LEVELS: Harsh penalty, max 0.4
      //   - Linear based on progress

      double deductiveScore = 0.0;

      if (solved) {
        deductiveScore = 1.0;
      } else {
        final int maxPossiblePath = (size * 2) - 2;
        final double pathProgress = maxPossiblePath > 0
            ? (maxPathLength / maxPossiblePath.toDouble()).clamp(0.0, 1.0)
            : 0.0;
        deductiveScore = 0.4 * pathProgress;
      }

      sumDeductive += deductiveScore;

      // ============================================
      // ALGORITHMIC LOGIC
      // ============================================
      // Measures: Systematic planning, efficiency, and avoiding trial-and-error
      //
      // Efficiency based on:
      //   1. Move efficiency (moves vs optimal)
      //   2. Wasted cycles (full 360° rotations) - INCREASED PENALTY
      //
      // SOLVED LEVELS: Base (0.5) + Efficiency bonus (up to 0.5) = 0.5 to 1.0
      //   BONUSES for excellent play:
      //   - Efficiency > 0.9: +0.2 bonus → up to 1.2
      //   - Efficiency > 0.8: +0.1 bonus → up to 1.1
      //
      // FAILED LEVELS: Up to 0.4 based on progress & efficiency

      double algoScore = 0.0;

      if (solved) {
        const double baseCredit = 0.5;

        // Move efficiency
        final double moveEfficiency = optimalMoves > 0
            ? clamp01(optimalMoves / max(moves, 1).toDouble())
            : 0.5;

        // Cycle efficiency - INCREASED penalty (0.5 instead of 0.3-0.4)
        // This compensates for removing backtrack
        final double cycleEfficiency = clamp01(1.0 / (1.0 + wastedCycles * 0.5));

        // Combined efficiency (geometric mean)
        final double efficiency = sqrt(moveEfficiency * cycleEfficiency);

        // Base score: 0.5 to 1.0
        algoScore = baseCredit + (efficiency * 0.5);

        // BONUS: Reward excellent play
        if (efficiency > 0.9) {
          algoScore += 0.2; // Excellent! Can reach 1.2
        } else if (efficiency > 0.8) {
          algoScore += 0.1; // Very good! Can reach 1.1
        }

      } else {
        // FAILED LEVEL
        final int maxPossiblePath = (size * 2) - 2;
        final double pathProgress = maxPossiblePath > 0
            ? (maxPathLength / maxPossiblePath.toDouble()).clamp(0.0, 1.0)
            : 0.0;

        if (pathProgress > 0.3) {
          final double moveEfficiency = optimalMoves > 0
              ? clamp01(optimalMoves / max(moves, 1).toDouble())
              : 0.5;

          final double cycleEfficiency = clamp01(1.0 / (1.0 + wastedCycles * 0.5));

          final double efficiency = sqrt(moveEfficiency * cycleEfficiency);

          double maxCredit;
          if (efficiency > 0.8) {
            maxCredit = 0.4;
          } else if (efficiency > 0.5) {
            maxCredit = 0.3;
          } else {
            maxCredit = 0.2;
          }

          algoScore = maxCredit * pathProgress * efficiency;
        } else {
          algoScore = 0.0;
        }
      }

      sumAlgo += algoScore;

      // ============================================
      // INFORMATION PROCESSING SPEED
      // ============================================
      // Measures: How quickly they can parse, plan, and execute
      //
      // ALWAYS based on deductive reasoning:
      //   IPS = deductiveScore * (0.5 + 0.5 * speedMultiplier)
      //
      // Speed multiplier can exceed 1.0 to reward exceptional speed!
      //   - Blazing fast (≤ half perfect time): 1.5x multiplier
      //   - Perfect time: 1.0x multiplier
      //   - Slow/timeout: down to 0.0x multiplier

      double speedMultiplier = 0.0;

      if (solved) {
        const double maxTimeMs = 20000.0;

        double perfectTimeMs;
        if (size == 3) {
          perfectTimeMs = 5000.0;
        } else if (size == 4) {
          perfectTimeMs = 8000.0;
        } else if (size == 6) {
          perfectTimeMs = 12000.0;
        } else {
          perfectTimeMs = 5000.0 + (size - 3) * 2333.0;
        }

        if (timeMs <= perfectTimeMs * 0.5) {
          // BLAZING FAST
          speedMultiplier = 1.5;
        } else if (timeMs <= perfectTimeMs) {
          // Fast to perfect: Linear from 1.0 to 1.5
          final double ratio = timeMs / (perfectTimeMs * 0.5);
          speedMultiplier = 1.5 - (0.5 * (ratio - 1.0));
        } else if (timeMs >= maxTimeMs) {
          // Timeout
          speedMultiplier = 0.0;
        } else {
          // Between perfect and timeout: Linear from 1.0 to 0.0
          final double range = maxTimeMs - perfectTimeMs;
          final double excess = timeMs - perfectTimeMs;
          speedMultiplier = 1.0 - (excess / range);
        }
      } else {
        // FAILED LEVEL
        final int maxPossiblePath = (size * 2) - 2;
        final double pathProgress = maxPossiblePath > 0
            ? (maxPathLength / maxPossiblePath.toDouble()).clamp(0.0, 1.0)
            : 0.0;

        if (pathProgress > 0.3) {
          const double maxTimeMs = 20000.0;

          if (timeMs < maxTimeMs * 0.5) {
            speedMultiplier = 1.0; // Fast
          } else if (timeMs < maxTimeMs * 0.75) {
            speedMultiplier = 0.66; // Medium
          } else if (timeMs < maxTimeMs) {
            speedMultiplier = 0.33; // Slow
          } else {
            speedMultiplier = 0.0; // Timed out
          }
        } else {
          speedMultiplier = 0.0;
        }
      }

      // IPS Score = deductive * (0.5 baseline + 0.5 * speedMultiplier)
      final double speedScore = deductiveScore * (0.5 + 0.5 * speedMultiplier);

      sumSpeed += speedScore;
    }

    // Average across levels, THEN clamp to [0.0, 1.0]
    final double deductiveReasoning = n > 0 ? clamp01(sumDeductive / n) : 0.0;
    final double algorithmicLogic = n > 0 ? clamp01(sumAlgo / n) : 0.0;
    final double informationProcessingSpeed = n > 0 ? clamp01(sumSpeed / n) : 0.0;

    return {
      "Deductive Reasoning": deductiveReasoning,
      "Algorithmic Logic": algorithmicLogic,
      "Information Processing Speed": informationProcessingSpeed,
    };
  }
}