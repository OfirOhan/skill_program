import 'dart:math';

class DigitShuffleGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<double> roundAccuracies,
    required List<int> roundTimesMs,
    required List<int> roundTaskTypes, // 0=Recall, 1=Sort, 2=Add
  }) {
      final int n = min(roundAccuracies.length, min(roundTimesMs.length, roundTaskTypes.length));
      if (n <= 0) {
        return {
            "Rote Memorization": 0.0,
            "Working Memory": 0.0,
            "Quantitative Reasoning": 0.0,
            "Information Processing Speed": 0.0,
            "Cognitive Flexibility": 0.0,
        };
      }

      double meanOf(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
      double meanInt(List<int> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;

      final double overallAccuracy = clamp01(meanOf(roundAccuracies.take(n).toList()));

      final recallAcc = <double>[];
      final sortAcc = <double>[];
      final addAcc = <double>[];

      for (int i = 0; i < n; i++) {
          final t = roundTaskTypes[i];
          final a = roundAccuracies[i];
          if (t == 0) recallAcc.add(a);
          if (t == 1) sortAcc.add(a);
          if (t == 2) addAcc.add(a);
      }

      final double roteMemorization = clamp01(meanOf(recallAcc));
      final double workingMemory = clamp01(meanOf(sortAcc));
      final double quantitativeReasoning = clamp01(meanOf(addAcc));

      // Processing Speed
      double informationProcessingSpeed = 0.0;
      {
          final times = roundTimesMs.take(n).toList()..sort();
          final int mid = times.length ~/ 2;
          final double medianMs = times.length.isOdd
              ? times[mid].toDouble()
              : ((times[mid - 1] + times[mid]) / 2.0);

          final double rawSpeed = clamp01(1.0 - (medianMs / 15000.0));
          informationProcessingSpeed = clamp01(rawSpeed * overallAccuracy);
      }

      // Cognitive Flexibility
      double cognitiveFlexibility = 0.0;
      if (n >= 2) {
          final switchIdx = <int>[];
          final stayIdx = <int>[];

          for (int i = 1; i < n; i++) {
              final bool isSwitch = roundTaskTypes[i] != roundTaskTypes[i - 1];
              (isSwitch ? switchIdx : stayIdx).add(i);
          }

          if (switchIdx.isNotEmpty && stayIdx.isNotEmpty) {
              final double switchAcc = meanOf(switchIdx.map((i) => roundAccuracies[i]).toList());
              final double stayAcc = meanOf(stayIdx.map((i) => roundAccuracies[i]).toList());

              final double switchTime = meanInt(switchIdx.map((i) => roundTimesMs[i]).toList());
              final double stayTime = meanInt(stayIdx.map((i) => roundTimesMs[i]).toList());

              final double accRatio = (stayAcc <= 0.0) ? 0.0 : clamp01(switchAcc / stayAcc);
              final double timeRatio = (switchTime <= 0.0) ? 0.0 : clamp01(stayTime / switchTime);

              cognitiveFlexibility = clamp01(((accRatio + timeRatio) / 2.0) * overallAccuracy);
          }
      }

      return {
          "Rote Memorization": roteMemorization,
          "Working Memory": workingMemory,
          "Quantitative Reasoning": quantitativeReasoning,
          "Information Processing Speed": informationProcessingSpeed,
          "Cognitive Flexibility": cognitiveFlexibility,
      };
  }
}
