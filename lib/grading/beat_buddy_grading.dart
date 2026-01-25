// grading/beat_buddy_grading.dart

class BeatBuddyGrading {
  /// Grades the Beat Buddy game performance across two auditory skills.
  /// 
  /// Returns scores for:
  /// - "Auditory Pitch/Tone": Ability to match and discriminate pitch frequencies
  /// - "Auditory Rhythm": Ability to detect timing differences in rhythmic patterns
  static Map<String, double> grade({
    required List<double> pitchErrorsCents,
    required int rhythmCorrect,
    required int rhythmTotal,
  }) {
    return {
      "Auditory Pitch/Tone": _gradePitch(pitchErrorsCents),
      "Auditory Rhythm": _gradeRhythm(rhythmCorrect, rhythmTotal),
    };
  }

  /// Grades pitch matching ability based on average error in cents.
  /// 
  /// Pitch discrimination thresholds (research-based):
  /// - Expert musicians: ~5-10 cents
  /// - Good pitch perception: ~20-30 cents
  /// - Average adults: ~50-100 cents
  /// - Poor pitch perception: >150 cents
  /// 
  /// Scoring curve:
  /// - 0-25 cents avg error: 0.95-1.00 (excellent)
  /// - 25-50 cents: 0.80-0.95 (good)
  /// - 50-100 cents: 0.50-0.80 (average)
  /// - 100-200 cents: 0.20-0.50 (below average)
  /// - >200 cents: 0.00-0.20 (poor)
  static double _gradePitch(List<double> pitchErrorsCents) {
    if (pitchErrorsCents.isEmpty) {
      return 0.0; // No attempts made
    }

    final double avgCents = pitchErrorsCents.reduce((a, b) => a + b) / pitchErrorsCents.length;

    // Smooth sigmoid-like curve that maps cents error to score
    // - Excellent performance (0-25 cents): maps to 0.95-1.00
    // - Good performance (25-50 cents): maps to 0.80-0.95
    // - Average performance (50-100 cents): maps to 0.50-0.80
    // - Below average (100-200 cents): maps to 0.20-0.50
    // - Poor (>200 cents): maps to 0.00-0.20

    double score;
    if (avgCents <= 25.0) {
      // Excellent range: linear interpolation from 1.0 to 0.95
      score = 1.0 - (avgCents / 25.0) * 0.05;
    } else if (avgCents <= 50.0) {
      // Good range: linear interpolation from 0.95 to 0.80
      score = 0.95 - ((avgCents - 25.0) / 25.0) * 0.15;
    } else if (avgCents <= 100.0) {
      // Average range: linear interpolation from 0.80 to 0.50
      score = 0.80 - ((avgCents - 50.0) / 50.0) * 0.30;
    } else if (avgCents <= 200.0) {
      // Below average range: linear interpolation from 0.50 to 0.20
      score = 0.50 - ((avgCents - 100.0) / 100.0) * 0.30;
    } else {
      // Poor range: exponential decay from 0.20 to 0.0
      // At 300 cents (semitone), score approaches 0
      score = 0.20 * (1.0 - ((avgCents - 200.0) / 100.0).clamp(0.0, 1.0));
    }

    return double.parse(score.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Grades rhythm discrimination ability based on accuracy.
  /// 
  /// This is a simpler metric since rhythm discrimination is more binary
  /// (you either detect the difference or you don't). The difficulty scaling
  /// in the game (from 300ms differences down to 60ms) naturally creates
  /// a distribution of performance.
  /// 
  /// Scoring:
  /// - Direct proportion of correct answers
  /// - 5/5 correct: 1.00 (perfect discrimination)
  /// - 4/5 correct: 0.80 (good, might have missed hardest trial)
  /// - 3/5 correct: 0.60 (average, struggled with harder trials)
  /// - 2/5 correct: 0.40 (below average, random guessing territory)
  /// - 1/5 correct: 0.20 (poor)
  /// - 0/5 correct: 0.00 (no discrimination ability shown)
  static double _gradeRhythm(int rhythmCorrect, int rhythmTotal) {
    if (rhythmTotal == 0) {
      return 0.0; // No trials completed
    }

    final double rawScore = rhythmCorrect / rhythmTotal;

    return double.parse(rawScore.clamp(0.0, 1.0).toStringAsFixed(2));
  }
}