
class SplitTapGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
      required int leftTargets,
      required int leftDistractors,
      required int leftHitsT,
      required int leftCorrectRejections,
      required List<bool> leftTrialCorrect,
      required List<bool> leftTrialPostSwitch,
      required int postSwitchTrials,
      required int postSwitchCorrect,
      required int mathHits,
      required int mathWrongs,
      required List<int> mathRTs,
  }) {
      final int leftTotalTrials = leftTargets + leftDistractors;
      if (leftTotalTrials <= 0) {
          return {
            "Response Inhibition": 0.0,
            "Cognitive Flexibility": 0.0,
            "Observation / Vigilance": 0.0,
            "Instruction Adherence": 0.0,
            "Quantitative Reasoning": 0.0,
            "Reaction Time (Choice)": 0.0,
          };
      }

      final double hitRate = leftTargets == 0 ? 0.0 : clamp01(leftHitsT / leftTargets);
      final double specificity = leftDistractors == 0 ? 0.0 : clamp01(leftCorrectRejections / leftDistractors);
      final double leftBalancedAccuracy = (hitRate + specificity) / 2.0;

      final double inhibEvidence = clamp01(leftDistractors / 8.0);
      final double responseInhibition = clamp01(specificity * inhibEvidence);

      double observationVigilance = 0.0;
      if (leftTrialCorrect.length >= 10) {
          final int n = leftTrialCorrect.length;
          final int split = n ~/ 2;
          int c1 = 0, c2 = 0;
          for (int i = 0; i < n; i++) {
              if (i < split) { if (leftTrialCorrect[i]) c1++; }
              else { if (leftTrialCorrect[i]) c2++; }
          }
          final double acc1 = clamp01(c1 / (split == 0 ? 1 : split));
          final double acc2 = clamp01(c2 / ((n - split) == 0 ? 1 : (n - split)));
          final double stability = clamp01(1.0 - (acc1 - acc2).abs());
          observationVigilance = clamp01(stability * leftBalancedAccuracy);
      }

      double cognitiveFlexibility = 0.0;
      {
          int baseN = 0, baseC = 0;
          int swN = 0, swC = 0;
          for (int i = 0; i < leftTrialCorrect.length; i++) {
              if (leftTrialPostSwitch[i]) { swN++; if (leftTrialCorrect[i]) swC++; }
              else { baseN++; if (leftTrialCorrect[i]) baseC++; }
          }
          if (swN >= 2 && baseN >= 8) {
              final double baseAcc = clamp01(baseC / baseN);
              final double swAcc = clamp01(swC / swN);
              final double cost = clamp01((baseAcc - swAcc) < 0 ? 0.0 : (baseAcc - swAcc));
              cognitiveFlexibility = clamp01((1.0 - cost) * baseAcc);
          }
      }

      double instructionAdherence = 0.0;
      if (postSwitchTrials >= 3) {
          final double adherenceRate = clamp01(postSwitchCorrect / postSwitchTrials);
          final double evidenceGate = clamp01(postSwitchTrials / 5.0);
          instructionAdherence = clamp01(adherenceRate * evidenceGate);
      }

      final int mathTotal = mathHits + mathWrongs;
      final double mathAccRaw = mathTotal == 0 ? 0.0 : clamp01(mathHits / mathTotal);
      final double mathEvidence = clamp01(mathTotal / 3.0);
      final double quantitativeReasoning = clamp01(mathAccRaw * mathEvidence);

      double reactionTimeChoice = 0.0;
      if (mathRTs.length >= 5 && mathAccRaw > 0.0) {
          final times = List<int>.from(mathRTs)..sort();
          final int mid = times.length ~/ 2;
          final double medianMs = times.length.isOdd
              ? times[mid].toDouble()
              : ((times[mid - 1] + times[mid]) / 2.0);
          const double bestMs = 600.0;
          const double worstMs = 4500.0;
          final double raw = clamp01(1.0 - ((medianMs - bestMs) / (worstMs - bestMs)));
          reactionTimeChoice = clamp01(raw * quantitativeReasoning);
      }

      return {
          "Response Inhibition": responseInhibition,
          "Cognitive Flexibility": cognitiveFlexibility,
          "Instruction Adherence": instructionAdherence,
          "Observation / Vigilance": observationVigilance,
          "Quantitative Reasoning": quantitativeReasoning,
          "Reaction Time (Choice)": reactionTimeChoice,
      };
  }
}
