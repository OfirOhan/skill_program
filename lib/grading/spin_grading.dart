// grading/spin_grading.dart
import 'dart:math';

class SpinGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<bool> results,
    required List<int> reactionTimes,
    required List<int> limits,
  }) {
    int n = [results.length, reactionTimes.length, limits.length].reduce(min);

    if (n == 0) {
      return {
        "Mental Rotation": 0.0,
        "Spatial Awareness": 0.0,
        "Information Processing Speed": 0.0,
      };
    }

    double sumMentalRotation = 0.0;
    double sumSpatialAwareness = 0.0;

    // store per-trial IPS for later aggregation
    final List<double> ipsScores = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      final bool correct = results[i];
      final int timeMs = reactionTimes[i];
      final int limitMs = limits[i];

      // ============================================
      // MENTAL ROTATION
      // ============================================
      double mentalRotationScore = correct ? 1.0 : 0.0;
      sumMentalRotation += mentalRotationScore;

      // ============================================
      // SPATIAL AWARENESS
      // ============================================
      double spatialScore = correct ? 1.0 : 0.0;
      sumSpatialAwareness += spatialScore;

      // ============================================
      // INFORMATION PROCESSING SPEED (per trial)
      // ============================================
      double ipsScore = 0.0;

      if (correct) {
        const int perfectTimeMs = 5000; // 5 seconds = perfect speed

        if (timeMs <= perfectTimeMs) {
          ipsScore = 1.0;
        } else {
          final int rangeMs = limitMs - perfectTimeMs;
          if (rangeMs <= 0) {
            // Safety: if limit <= perfectTimeMs, just treat as base 0.5
            ipsScore = 0.5;
          } else {
            final int excessMs = timeMs - perfectTimeMs;
            final double ratio = excessMs / rangeMs;
            ipsScore = 1.0 - (0.5 * ratio);
          }
        }
      } else {
        ipsScore = 0.0;
      }

      ipsScores[i] = ipsScore;
    }

    // Averages for Mental Rotation and Spatial Awareness
    final double mentalRotation = n > 0 ? clamp01(sumMentalRotation / n) : 0.0;
    final double spatialAwareness = n > 0 ? clamp01(sumSpatialAwareness / n) : 0.0;

    // ============================================
    // INFORMATION PROCESSING SPEED (sorted + weighted)
    // ============================================
    //
    // Game: 4 rounds
    // - Compute IPS per round
    // - Sort IPS scores
    // - Apply weights by *sorted position*:
    //   index 0 -> 1x
    //   index 1 -> 2x
    //   index 2 -> 2x
    //   index 3 -> 1x
    //
    // So the two middle values (positions 2 and 3 after sort in 1-based terms)
    // dominate, but extremes still have some impact.

    double informationProcessingSpeed = 0.0;

    if (n > 0) {
      // Work on a sorted copy
      final List<double> sortedIps = List<double>.from(ipsScores)..sort();

      if (n == 4) {
        const List<double> weights = [1.0, 2.0, 2.0, 1.0];
        double weightedSum = 0.0;
        double totalWeight = 0.0;

        for (int i = 0; i < 4; i++) {
          weightedSum += sortedIps[i] * weights[i];
          totalWeight += weights[i];
        }

        informationProcessingSpeed =
        totalWeight > 0 ? clamp01(weightedSum / totalWeight) : 0.0;
      } else if (n == 1) {
        // degenerate case: just take the single value
        informationProcessingSpeed = clamp01(sortedIps[0]);
      } else {
        // Fallback for n != 1 and n != 4: simple median
        final int mid = n ~/ 2;
        if (n.isOdd) {
          informationProcessingSpeed = clamp01(sortedIps[mid]);
        } else {
          informationProcessingSpeed =
              clamp01((sortedIps[mid - 1] + sortedIps[mid]) / 2.0);
        }
      }
    }

    return {
      "Mental Rotation": mentalRotation,
      "Spatial Awareness": spatialAwareness,
      "Information Processing Speed": informationProcessingSpeed,
    };
  }
}
