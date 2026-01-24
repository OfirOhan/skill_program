// grading/chart_grading.dart
import 'dart:math';

class ChartGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<bool> results,           // [true, false, true] - correctness
    required List<int> reactionTimes,      // [5000, 12000, 8000] - time in ms
    required List<bool> isMathQuestion,    // [false, true, true] - requires calculation?
  }) {
    final int n = [
      results.length,
      reactionTimes.length,
      isMathQuestion.length,
    ].reduce(min);

    if (n <= 0) {
      return {
        "Quantitative Reasoning": 0.0,
        "Pattern Recognition": 0.0,
      };
    }

    double sumQuantitative = 0.0;
    double sumPattern = 0.0;

    // Time limits per question [15s, 15s, 25s, 30s, 35s]
    final List<int> timeLimits = [15000, 15000, 25000, 30000, 35000];

    for (int i = 0; i < n; i++) {
      final bool correct = results[i];
      final int timeMs = reactionTimes[i];
      final bool requiresMath = isMathQuestion[i];
      final int limitMs = i < timeLimits.length ? timeLimits[i] : 35000;

      // ============================================
      // QUANTITATIVE REASONING
      // ============================================
      // Measures: Ability to interpret charts and perform calculations
      //
      // CORRECT ANSWERS: Full credit (1.0)
      //   Math questions get BONUS for accuracy:
      //   - Math question correct: +0.2 bonus → up to 1.2
      //
      // INCORRECT ANSWERS: 0.0 (no partial credit for wrong interpretation)

      double quantitativeScore = 0.0;

      if (correct) {
        quantitativeScore = 1.0;

        // BONUS: Math questions are harder, reward accuracy
        if (requiresMath) {
          quantitativeScore += 0.2; // Can reach 1.2
        }
      } else {
        // Wrong answer = 0 (can't partially interpret a chart correctly)
        quantitativeScore = 0.0;
      }

      sumQuantitative += quantitativeScore;

      // ============================================
      // PATTERN RECOGNITION
      // ============================================
      // Measures: Identifying trends, comparing structures, recognizing visual relationships
      //
      // All questions test pattern recognition:
      // Q1: Comparing bar heights to find minimum
      // Q2: Identifying growth patterns across time series (CORE PATTERN TASK)
      // Q3-5: Recognizing relationships between data points
      //
      // CORRECT: Full credit (1.0)
      // Q2 gets BONUS (+0.3) as it's explicit trend identification
      // Fast correct answers get speed bonus (up to +0.2)
      //
      // INCORRECT: 0.0 (failed to recognize the pattern)

      double patternScore = 0.0;

      if (correct) {
        patternScore = 1.0;

        // BONUS: Q2 is explicit pattern/trend identification
        if (i == 1) {
          patternScore += 0.3; // Question 2 (index 1) - growth pattern
        }

        // Speed bonus: Recognizing patterns quickly shows strong skill
        final double perfectTimeMs = limitMs * 0.5; // 50% of time limit
        if (timeMs <= perfectTimeMs) {
          final double speedBonus = 0.2 * (1.0 - (timeMs / perfectTimeMs));
          patternScore += speedBonus;
        }
      } else {
        // Wrong answer = pattern not recognized
        patternScore = 0.0;
      }

      sumPattern += patternScore;
    }

    // Average across questions, then clamp
    final double quantitativeReasoning = n > 0 ? clamp01(sumQuantitative / n) : 0.0;
    final double patternRecognition = n > 0 ? clamp01(sumPattern / n) : 0.0;

    return {
      "Quantitative Reasoning": quantitativeReasoning,
      "Pattern Recognition": patternRecognition,
    };
  }
}