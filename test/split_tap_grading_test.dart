import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/split_tap_grading.dart';

void main() {
  group('Split Tap Grading Tests', () {
    test('No Activity', () {
      final scores = SplitTapGrading.grade(
        leftTargets: 0, leftDistractors: 0, leftHitsT: 0, leftCorrectRejections: 0,
        leftTrialCorrect: [], leftTrialPostSwitch: [],
        postSwitchTrials: 0, postSwitchCorrect: 0,
        mathHits: 0, mathWrongs: 0, mathRTs: [],
      );
      expect(scores["Response Inhibition"], equals(0.0));
    });

    test('Perfect Inhibition', () {
      // 8 distractors, 8 correct rejections -> specificity 1.0
      final scores = SplitTapGrading.grade(
        leftTargets: 0, leftDistractors: 8, leftHitsT: 0, leftCorrectRejections: 8,
        leftTrialCorrect: List.filled(8, true),
        leftTrialPostSwitch: List.filled(8, false),
        postSwitchTrials: 0, postSwitchCorrect: 0,
        mathHits: 0, mathWrongs: 0, mathRTs: [],
      );
      // inhibEvidence = 8/8 = 1.0. Specificity = 1.0. Result = 1.0
      expect(scores["Response Inhibition"], equals(1.0));
    });

    test('Fail Math', () {
      final scores = SplitTapGrading.grade(
        leftTargets: 8, leftDistractors: 8, leftHitsT: 8, leftCorrectRejections: 8,
        leftTrialCorrect: List.filled(16, true),
        leftTrialPostSwitch: List.filled(16, false),
        postSwitchTrials: 0, postSwitchCorrect: 0,
        mathHits: 0, mathWrongs: 5, mathRTs: [5000],
      );
      expect(scores["Quantitative Reasoning"], equals(0.0));
      // RT depends on reasoning > 0
      expect(scores["Reaction Time (Choice)"], equals(0.0));
    });
  });
}
