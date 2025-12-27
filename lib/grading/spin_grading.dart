
class SpinGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<bool> results,
    required List<int> reactionTimes,
    required List<int> limits, // for speed normalization if needed, but original used 1-rt/limit logic inside loop
  }) {
    // Determine n based on available data
    // Original: n = [levels.length, _trialCorrect.length, _trialRtMs.length, _trialLimitMs.length].reduce(min)
    // Here we assume lists are already sync'd or we take min length
    int n = results.length;
    if (reactionTimes.length < n) n = reactionTimes.length;
    if (limits.length < n) n = limits.length;

    if (n == 0) {
      return {
        "Mental Rotation": 0.0,
        "Pattern Recognition": 0.0,
        "Information Processing Speed": 0.0,
      };
    }

    // 1) Accuracy (smoothed)
    int correct = 0;
    for (int i = 0; i < n; i++) {
        if (results[i]) correct++;
    }

    // Beta(1,1) posterior mean: (correct + 1) / (n + 2)
    final double smoothedAccuracy = (correct + 1) / (n + 2);

    // 2) Speed (normalized, median)
    final List<double> rawSpeeds = [];
    for (int i = 0; i < n; i++) {
        final int limit = limits[i];
        final int rt = reactionTimes[i].clamp(0, limit);
        rawSpeeds.add(clamp01(1.0 - (rt / limit)));
    }

    rawSpeeds.sort();
    double medianRawSpeed = 0.0;
    if (rawSpeeds.isNotEmpty) {
        final int mid = rawSpeeds.length ~/ 2;
        medianRawSpeed = rawSpeeds.length.isOdd
            ? rawSpeeds[mid]
            : (rawSpeeds[mid - 1] + rawSpeeds[mid]) / 2.0;
    }

    final double earnedSpeed = clamp01(medianRawSpeed * smoothedAccuracy);

    // 3) Skill mapping
    final double patternRecognition = clamp01(smoothedAccuracy);
    final double mentalRotation = clamp01(0.75 * smoothedAccuracy + 0.25 * earnedSpeed);

    return {
      "Mental Rotation": mentalRotation,
      "Pattern Recognition": patternRecognition,
      "Information Processing Speed": earnedSpeed,
    };
  }
}
