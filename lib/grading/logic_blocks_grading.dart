import 'dart:math';

class LogicBlocksGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<int> playedGridSizes,
    required List<bool> levelSolved,
    required List<int> levelTimeMs,
    required List<int> levelMovesList,
    required List<int> levelWastedCycles,
  }) {
      final int n = [
          playedGridSizes.length,
          levelSolved.length,
          levelTimeMs.length,
          levelMovesList.length,
          levelWastedCycles.length,
      ].reduce(min);

      if (n <= 0) {
          return {
            "Deductive Reasoning": 0.0,
            "Algorithmic Logic": 0.0,
            "Information Processing Speed": 0.0,
          };
      }

      double totalW = 0.0;
      double solvedW = 0.0;

      for (int i = 0; i < n; i++) {
          final int size = playedGridSizes[i];
          final double w = (size * size).toDouble();
          totalW += w;
          if (levelSolved[i]) solvedW += w;
      }

      final double completion = totalW <= 0 ? 0.0 : clamp01(solvedW / totalW);
      final double deductiveReasoning = completion;

      double algoSum = 0.0;
      for (int i = 0; i < n; i++) {
          final int size = playedGridSizes[i];
          final int tiles = size * size;
          final int mv = levelMovesList[i];
          final int cycles = levelWastedCycles[i];

          final double movesPerTile = tiles == 0 ? 999.0 : (mv / tiles);
          final double movesScore = 1.0 / (1.0 + movesPerTile);
          final double cyclesScore = 1.0 / (1.0 + cycles.toDouble());

          final double perLevelAlgo = levelSolved[i] ? sqrt(movesScore * cyclesScore) : 0.0;
          algoSum += perLevelAlgo;
      }

      final double algorithmicLogic = clamp01(algoSum / n);

      double informationProcessingSpeed = 0.0;
      {
          final times = levelTimeMs.take(n).toList()..sort();
          final int mid = times.length ~/ 2;
          final double medianMs = times.length.isOdd
              ? times[mid].toDouble()
              : ((times[mid - 1] + times[mid]) / 2.0);

          const double limitMs = 15000.0;
          final double rawSpeed = clamp01(1.0 - (medianMs / limitMs));
          informationProcessingSpeed = clamp01(rawSpeed * completion);
      }

      return {
          "Deductive Reasoning": deductiveReasoning,
          "Algorithmic Logic": algorithmicLogic,
          "Information Processing Speed": informationProcessingSpeed,
      };
  }
}
