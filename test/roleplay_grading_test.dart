import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/roleplay_grading.dart';

void main() {
  group('Roleplay Grading Tests', () {
    test('No Cues', () {
      final scores = RoleplayGrading.grade(
        totalCues: 0,
        results: [],
        reactionTimes: [],
        isSubtext: [],
      );
      expect(scores["Pragmatics"], equals(0.0));
    });

    test('Perfect Pragmatics', () {
      final scores = RoleplayGrading.grade(
        totalCues: 2,
        results: [true, true],
        reactionTimes: [1000, 1000],
        isSubtext: [true, true],
      );
      expect(scores["Pragmatics"], equals(1.0));
      // No non-subtext cues, so social context defaults to accuracy (1.0)
      expect(scores["Social Context Awareness"], equals(1.0));
    });

    test('Mixed Performance', () {
      final scores = RoleplayGrading.grade(
        totalCues: 2,
        results: [true, false],
        reactionTimes: [2000, 2000],
        isSubtext: [true, false],
      );
      // Subtext cue (0) is true -> 1.0 pragmatics
      // Non-subtext cue (1) is false -> 0.0 social context
      expect(scores["Pragmatics"], equals(1.0));
      expect(scores["Social Context Awareness"], equals(0.0));
    });
  });
}
