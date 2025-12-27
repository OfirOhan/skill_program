library matrix_grading;

import 'dart:math';

/// Pure grading logic for Matrix Logic Game
/// Inputs are the items and the user's results.
Map<String, double> gradeMatrixFromStats({
  required List<String> itemDescriptions, // "Rotation", "Arithmetic", etc.
  required List<int> itemDifficulties,    // 1 to 6
  required List<bool> itemResults,        // True if correct
  required List<int> itemTimesMs,         // Time taken per item
}) {
  double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  // Safety check
  final int n = min(itemDescriptions.length, min(itemResults.length, itemTimesMs.length));
  if (n <= 0) {
    return {
      "Inductive Reasoning": 0.0,
      "Deductive Reasoning": 0.0,
      "Quantitative Reasoning": 0.0,
      "Information Processing Speed": 0.0,
    };
  }

  // ---- Metrics Buckets ----
  double totalDiff = 0.0;
  double correctWeighted = 0.0;

  double inductiveSum = 0.0, inductiveMax = 0.0;   // Rotation, Cyclic Pattern
  double deductiveSum = 0.0, deductiveMax = 0.0;   // Sudoku Logic, Column XOR
  double quantSum = 0.0, quantMax = 0.0;           // Subtraction, Arithmetic

  for (int i = 0; i < n; i++) {
    final desc = itemDescriptions[i];
    final w = itemDifficulties[i].toDouble();
    final correct = itemResults[i];

    totalDiff += w;
    if (correct) correctWeighted += w;

    // 1. Inductive: Inferring rules from examples
    if (desc == "Rotation" || desc == "Cyclic Pattern") {
      inductiveMax += w;
      if (correct) inductiveSum += w;
    }

    // 2. Deductive: Applying strict logic constraints
    if (desc == "Sudoku Logic (Unique Row/Col)" || desc == "Column XOR") {
      deductiveMax += w;
      if (correct) deductiveSum += w;
    }

    // 3. Quantitative: Numeric operations
    if (desc == "Subtraction" || desc == "Arithmetic") {
      quantMax += w;
      if (correct) quantSum += w;
    }
  }

  // Weighted Accuracy (Used to gate Speed)
  final double overallWeightedAccuracy =
  totalDiff <= 0.0 ? 0.0 : clamp01(correctWeighted / totalDiff);

  // Category Scores
  final double inductive =
  inductiveMax <= 0.0 ? 0.0 : clamp01(inductiveSum / inductiveMax);

  final double deductive =
  deductiveMax <= 0.0 ? 0.0 : clamp01(deductiveSum / deductiveMax);

  final double quantitative =
  quantMax <= 0.0 ? 0.0 : clamp01(quantSum / quantMax);

  // ---- Information Processing Speed ----
  // Logic: Speed is only valuable if you are correct.
  // We calculate median time, normalize against the 15s limit,
  // and multiply by accuracy so "fast guessing" gets a low score.
  double informationProcessingSpeed = 0.0;

  if (itemTimesMs.isNotEmpty) {
    final times = itemTimesMs.take(n).toList();
    times.sort();
    final int mid = times.length ~/ 2;
    final double medianMs = times.length.isOdd
        ? times[mid].toDouble()
        : ((times[mid - 1] + times[mid]) / 2.0);

    // 15 seconds (15000ms) is the limit per question
    final double rawSpeed = clamp01(1.0 - (medianMs / 15000.0));

    // Gate: Speed * Weighted Accuracy
    informationProcessingSpeed = clamp01(rawSpeed * overallWeightedAccuracy);
  }

  return {
    "Inductive Reasoning": inductive,
    "Deductive Reasoning": deductive,
    "Quantitative Reasoning": quantitative,
    "Information Processing Speed": informationProcessingSpeed,
  };
}