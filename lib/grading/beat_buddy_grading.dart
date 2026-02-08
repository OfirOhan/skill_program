// grading/beat_buddy_grading.dart

class BeatBuddyGrading {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  static Map<String, double> grade({
    required List<double> pitchErrorsCents,
    required int rhythmCorrect,
    required int rhythmTotal,
  }) {
    if (pitchErrorsCents.isEmpty) {
      // print('[Beat Buddy Grading] No pitch data - returning zeros');
      return {
        "Auditory Pitch/Tone": 0.0,
        "Auditory Rhythm": 0.0,
      };
    }

    // === PITCH PROCESSING ===
    // print('\n[Beat Buddy Grading] Pitch Round Details:');
    for (int i = 0; i < pitchErrorsCents.length; i++) {
      // print('  Round ${i + 1}: ${pitchErrorsCents[i].toStringAsFixed(2)} cents deviation');
    }

    final double avgCents = pitchErrorsCents.reduce((a, b) => a + b) / pitchErrorsCents.length;
    // print('  Average: ${avgCents.toStringAsFixed(2)} cents');

    final double pitchScore = _calculatePitchScore(avgCents);

    // === RHYTHM PROCESSING ===
    // print('\n[Beat Buddy Grading] Rhythm Performance:');
    // print('  Correct: $rhythmCorrect / $rhythmTotal');

    final double rhythmScore = (rhythmTotal == 0) ? 0.0 : (rhythmCorrect / rhythmTotal);

    // === SKILL MEASUREMENTS ===

    // AUDITORY PITCH/TONE (0.0 - 1.0)
    // Ability to match and discriminate pitch frequencies
    // Calibrated so 70 cents avg error = 0.50 (average adult performance)
    final double auditoryPitchTone = pitchScore;

    // AUDITORY RHYTHM (0.0 - 1.0)
    // Ability to detect timing differences in rhythmic patterns
    // Direct proportion of correct pattern discriminations
    final double auditoryRhythm = rhythmScore;

    // print('\n[Beat Buddy Grading] Final Skill Scores:');
    // print('  Auditory Pitch/Tone: ${double.parse(auditoryPitchTone.toStringAsFixed(2))}');
    // print('  Auditory Rhythm: ${double.parse(auditoryRhythm.toStringAsFixed(2))}');
    // print('');

    return {
      "Auditory Pitch/Tone": double.parse(auditoryPitchTone.toStringAsFixed(2)),
      "Auditory Rhythm": double.parse(auditoryRhythm.toStringAsFixed(2)),
    };
  }

  // === PITCH SCORING HELPER ===
  /// Converts average pitch error (cents) to normalized score
  ///
  /// REFERENCE: Slider spans 200-800 Hz = ~2400 cents total range
  ///
  /// Pitch discrimination thresholds (research-based):
  /// - Expert musicians: ~5-10 cents (JND threshold)
  /// - Good pitch perception: ~20-40 cents
  /// - Average adults: ~60-80 cents ← THIS MAPS TO 0.5 SCORE
  /// - Below average: ~120-180 cents
  /// - Tone-deaf/poor: >200 cents (>2 semitones off)
  ///
  /// Scoring curve (calibrated so average adult = 0.5):
  /// - 0-15 cents: 0.90-1.00 (expert musician level)
  /// - 15-40 cents: 0.70-0.90 (good, above average)
  /// - 40-100 cents: 0.30-0.70 (average range, CENTER at ~70 cents = 0.5)
  /// - 100-180 cents: 0.10-0.30 (below average)
  /// - >180 cents: 0.00-0.10 (tone-deaf range)
  static double _calculatePitchScore(double avgCents) {
    // Curve calibrated so that 70 cents ≈ 0.5 (average adult performance)
    double score;

    if (avgCents <= 15.0) {
      // Expert range: 0-15 cents → 1.0 to 0.90
      score = 1.0 - (avgCents / 15.0) * 0.10;
    } else if (avgCents <= 40.0) {
      // Good range: 15-40 cents → 0.90 to 0.70
      score = 0.90 - ((avgCents - 15.0) / 25.0) * 0.20;
    } else if (avgCents <= 100.0) {
      // Average range: 40-100 cents → 0.70 to 0.30
      // At 70 cents (middle of average range) → 0.50
      score = 0.70 - ((avgCents - 40.0) / 60.0) * 0.40;
    } else if (avgCents <= 180.0) {
      // Below average: 100-180 cents → 0.30 to 0.10
      score = 0.30 - ((avgCents - 100.0) / 80.0) * 0.20;
    } else {
      // Poor/tone-deaf: 180+ cents → 0.10 to 0.00
      // Decays to 0 by 300 cents (3 semitones)
      double decay = ((avgCents - 180.0) / 120.0).clamp(0.0, 1.0);
      score = 0.10 * (1.0 - decay);
    }

    return clamp01(score);
  }
}