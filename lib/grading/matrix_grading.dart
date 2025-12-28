library matrix_grading;

import 'dart:math';

Map<String, double> gradeMatrixFromStats({
  required List<String> itemDescriptions,
  required List<int> itemDifficulties,
  required List<bool> itemResults,
  required List<int> itemTimesMs,
}) {
  double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  double difficultyWeight(int d) {
    final clamped = d.clamp(1, 6);
    return 0.92 + 0.016 * (clamped - 1);
  }

  double humanSpeedFactor(int ms) {
    final t = ms.clamp(2000, 15000).toDouble();
    return 1.0 - (t - 2000) / (15000 - 2000);
  }

  Map<String, double> skillWeightsFor(String desc) {
    switch (desc) {
      case "Rotation":
        return {"Inductive Reasoning": 0.85, "Deductive Reasoning": 0.10, "Quantitative Reasoning": 0.05};
      case "Subtraction":
        return {"Inductive Reasoning": 0.10, "Deductive Reasoning": 0.10, "Quantitative Reasoning": 0.80};
      case "Cyclic Pattern":
        return {"Inductive Reasoning": 0.92, "Deductive Reasoning": 0.05, "Quantitative Reasoning": 0.03};
      case "Sudoku Logic (Unique Row/Col)":
        return {"Inductive Reasoning": 0.15, "Deductive Reasoning": 0.70, "Quantitative Reasoning": 0.15};
      case "Arithmetic":
        return {"Inductive Reasoning": 0.05, "Deductive Reasoning": 0.25, "Quantitative Reasoning": 0.70};
      case "Column XOR":
        return {"Inductive Reasoning": 0.25, "Deductive Reasoning": 0.70, "Quantitative Reasoning": 0.05};
      default:
        return {"Inductive Reasoning": 1/3, "Deductive Reasoning": 1/3, "Quantitative Reasoning": 1/3};
    }
  }

  double adaptiveInductive(double indRaw, double dedRaw, double dedEvidence, double maxDedEvidence) {
    final dedStrength = maxDedEvidence > 0 ? dedEvidence / maxDedEvidence : 0.0;
    if (dedStrength < 0.4) {
      return clamp01(0.95 * indRaw + 0.05 * dedRaw);
    }
    return clamp01(0.85 * indRaw + 0.15 * dedRaw);
  }

  final int n = [
    itemDescriptions.length,
    itemDifficulties.length,
    itemResults.length,
    itemTimesMs.length,
  ].reduce(min);

  if (n <= 0) {
    return {
      "Inductive Reasoning": 0.0,
      "Deductive Reasoning": 0.0,
      "Quantitative Reasoning": 0.0,
      "Information Processing Speed": 0.0,
    };
  }

  // Precompute accuracy
  final accuracy = itemResults.where((r) => r).length / n;

  double indEvidence = 0.0, maxIndEvidence = 0.0;
  double dedEvidence = 0.0, maxDedEvidence = 0.0;
  double quantEvidence = 0.0, maxQuantEvidence = 0.0;
  int correctCount = 0;

  for (int i = 0; i < n; i++) {
    final bool correct = itemResults[i];
    final int difficulty = itemDifficulties[i];
    final String desc = itemDescriptions[i];
    final int timeMs = itemTimesMs[i].clamp(0, 15000);

    // Raw difficulty weight (for max evidence)
    final rawDiffW = difficultyWeight(difficulty);
    // Adjusted weight (for evidence) - penalize guessed hard items
    double adjustedDiffW = rawDiffW;

    // CRITICAL FIX: Penalty applies ONLY to evidence, not max evidence
    if (accuracy < 0.3 && timeMs < 1000 && difficulty >= 4) {
      adjustedDiffW *= 0.1; // Crush evidence from guessed hard items
    }

    if (correct) correctCount++;

    final weights = skillWeightsFor(desc);
    final wInd = weights["Inductive Reasoning"]!;
    final wDed = weights["Deductive Reasoning"]!;
    final wQuant = weights["Quantitative Reasoning"]!;

    double perf = 0.0;
    if (correct) {
      if (timeMs < 500) {
        perf = 0.05; // Extreme spam penalty
      } else if (timeMs < 1500) {
        perf = 0.20; // Severe guessing penalty
      } else {
        final speedBonus = humanSpeedFactor(timeMs);
        perf = 0.85 + 0.15 * speedBonus;
      }
    }

    // Evidence uses ADJUSTED weight
    indEvidence += wInd * perf * adjustedDiffW;
    dedEvidence += wDed * perf * adjustedDiffW;
    quantEvidence += wQuant * perf * adjustedDiffW;

    // Max evidence uses RAW weight (no penalty)
    maxIndEvidence += wInd * 1.0 * rawDiffW;
    maxDedEvidence += wDed * 1.0 * rawDiffW;
    maxQuantEvidence += wQuant * 1.0 * rawDiffW;
  }

  final double indRaw = maxIndEvidence > 0 ? clamp01(indEvidence / maxIndEvidence) : 0.0;
  final double dedRaw = maxDedEvidence > 0 ? clamp01(dedEvidence / maxDedEvidence) : 0.0;
  final double quantRaw = maxQuantEvidence > 0 ? clamp01(quantEvidence / maxQuantEvidence) : 0.0;

  // Bayesian prior for Quantitative
  double quantFinal;
  if (correctCount > 0 && quantEvidence > 0) {
    final prior = 0.85;
    quantFinal = clamp01((prior + quantEvidence) / (prior + maxQuantEvidence));
  } else {
    quantFinal = quantRaw;
  }

  // IPS calculation
  final List<int> rawTimes = List<int>.from(itemTimesMs);
  rawTimes.sort();
  final mid = rawTimes.length ~/ 2;
  final medianMs = rawTimes.length.isOdd
      ? rawTimes[mid].toDouble()
      : (rawTimes[mid - 1] + rawTimes[mid]) / 2.0;

  double baseSpeed;
  if (medianMs < 2000) {
    baseSpeed = 0.80;
  } else if (medianMs <= 4000) {
    baseSpeed = 1.0;
  } else if (medianMs >= 15000) {
    baseSpeed = 0.5;
  } else {
    baseSpeed = 1.0 - ((medianMs - 4000) / 11000.0) * 0.5;
  }

  final double ips = clamp01(baseSpeed * sqrt(accuracy));

  final double inductiveFinal = adaptiveInductive(indRaw, dedRaw, dedEvidence, maxDedEvidence);

  // Final safety net: cap scores for extreme spammers
  if (accuracy < 0.3 && medianMs < 500) {
    return {
      "Inductive Reasoning": min(inductiveFinal, 0.2),
      "Deductive Reasoning": min(dedRaw, 0.25),
      "Quantitative Reasoning": min(quantFinal, 0.2),
      "Information Processing Speed": ips,
    };
  }

  return {
    "Inductive Reasoning": inductiveFinal,
    "Deductive Reasoning": dedRaw,
    "Quantitative Reasoning": quantFinal,
    "Information Processing Speed": ips,
  };
}