
class SignalDecodeGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int rtSimpleTotal,
    required int rtSimpleHits,
    required List<int> rtSimpleRTs,
    required int spatialTotal,
    required int spatialCorrect,
    required List<int> spatialRTs,
    required int emotionTotal,
    required int emotionCorrect,
    required List<int> emotionRTs,
    required int memoryTotal,
    required int memoryCorrect,
    required List<int> memoryRTs,
    required int balanceTotal,
    required int balanceCorrect,
    required List<int> balanceRTs,
  }) {
      double calc(int cor, int tot, List<int> rts, double best, double worst) {
          if (tot == 0) return 0.0;
          double acc = cor / tot;
          if (rts.isEmpty) return acc;
          final sorted = List<int>.from(rts)..sort();
          double med = sorted[sorted.length ~/ 2].toDouble();
          double sp = (1.0 - (med - best)/(worst - best)).clamp(0.0, 1.0);
          return (acc * 0.8 + sp * 0.2).clamp(0.0, 1.0);
      }

      double rtScore = 0.0;
      if (rtSimpleTotal > 0 && rtSimpleRTs.isNotEmpty) {
          final sorted = List<int>.from(rtSimpleRTs)..sort();
          double med = sorted[sorted.length ~/ 2].toDouble();
          double sp = (1.0 - (med - 350)/1050).clamp(0.0, 1.0);
          double acc = rtSimpleHits / rtSimpleTotal;
          rtScore = sp * acc;
      }

      return {
          "Reaction Time (Simple)": double.parse(rtScore.toStringAsFixed(2)),
          "Spatial Awareness": double.parse(calc(spatialCorrect, spatialTotal, spatialRTs, 600, 7000).toStringAsFixed(2)),
          "Emotion Recognition": double.parse(calc(emotionCorrect, emotionTotal, emotionRTs, 600, 7000).toStringAsFixed(2)),
          "Associative Memory": double.parse(calc(memoryCorrect, memoryTotal, memoryRTs, 800, 7000).toStringAsFixed(2)),
          "Aesthetic Balance": double.parse(calc(balanceCorrect, balanceTotal, balanceRTs, 700, 7000).toStringAsFixed(2)),
      };
  }
}
