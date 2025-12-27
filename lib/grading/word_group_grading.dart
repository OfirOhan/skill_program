
class WordGroupGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required int totalItems,
    required int correctCount,
    required List<int> reactionTimes,
  }) {
    double breadth = totalItems == 0 ? 0.0 : (correctCount / totalItems);
    double avgRt = reactionTimes.isEmpty ? 7000 :
        reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;

    double fluency = (1.0 - ((avgRt - 2000) / 5000)).clamp(0.0, 1.0);

    return {
      "Vocabulary Breadth": double.parse(breadth.toStringAsFixed(2)),
      "Verbal Fluency": double.parse(fluency.toStringAsFixed(2)),
    };
  }
}
