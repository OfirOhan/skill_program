class SkillAggregator {
  /// Aggregates skill scores across games.
  /// - Averages duplicate skills
  /// - Ignores null / missing values
  /// - Returns null if no evidence exists
  static Map<String, double?> aggregate(Map<String, dynamic> gamesData) {
    final Map<String, List<double>> buckets = {};

    for (final entry in gamesData.entries) {
      final result = entry.value;

      if (result is Map<String, dynamic>) {
        for (final skillEntry in result.entries) {
          final skill = skillEntry.key;
          final value = skillEntry.value;

          if (value is num) {
            buckets.putIfAbsent(skill, () => []);
            buckets[skill]!.add(value.toDouble());
          }
        }
      }
    }

    // Compute mean per skill
    final Map<String, double?> finalScores = {};

    for (final entry in buckets.entries) {
      final values = entry.value;
      if (values.isEmpty) {
        finalScores[entry.key] = null;
      } else {
        finalScores[entry.key] =
            values.reduce((a, b) => a + b) / values.length;
      }
    }

    return finalScores;
  }
}
