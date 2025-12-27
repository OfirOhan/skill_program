
class BeatBuddyGrading {
  static Map<String, double> grade({
    required List<double> pitchErrorsCents,
    required int rhythmCorrect,
    required int rhythmTotal,
  }) {
    final double avgCents = pitchErrorsCents.isEmpty
        ? 500.0 
        : pitchErrorsCents.reduce((a, b) => a + b) / pitchErrorsCents.length;
    
    final double pitchScore = (1.0 - (avgCents / 300.0)).clamp(0.0, 1.0);

    final double rhythmScore = (rhythmTotal == 0) ? 0.0 : (rhythmCorrect / rhythmTotal).clamp(0.0, 1.0);

    return {
      "Auditory Pitch/Tone": double.parse(pitchScore.toStringAsFixed(2)),
      "Auditory Rhythm": double.parse(rhythmScore.toStringAsFixed(2)),
    };
  }
}
