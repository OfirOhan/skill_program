import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/beat_buddy_grading.dart';

void main() {
  group('Beat Buddy Grading Tests', () {
    test('Perfect Score', () {
      final scores = BeatBuddyGrading.grade(
        pitchErrorsCents: [0.0, 0.0, 0.0],
        rhythmCorrect: 10,
        rhythmTotal: 10,
      );
      expect(scores["Auditory Pitch/Tone"], equals(1.0));
      expect(scores["Auditory Rhythm"], equals(1.0));
    });

    test('Zero Score', () {
      final scores = BeatBuddyGrading.grade(
        pitchErrorsCents: [500.0, 500.0], // Max error
        rhythmCorrect: 0,
        rhythmTotal: 10,
      );
      expect(scores["Auditory Pitch/Tone"], equals(0.0));
      expect(scores["Auditory Rhythm"], equals(0.0));
    });

    test('Partial Score', () {
      final scores = BeatBuddyGrading.grade(
        pitchErrorsCents: [150.0], // Half of 300
        rhythmCorrect: 5,
        rhythmTotal: 10,
      );
      expect(scores["Auditory Pitch/Tone"], closeTo(0.5, 0.01));
      expect(scores["Auditory Rhythm"], equals(0.5));
    });
  });
}
