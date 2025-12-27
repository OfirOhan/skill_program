import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/signal_decode_grading.dart';

void main() {
  group('Signal Decode Grading Tests', () {
    test('Zero Activity', () {
      final scores = SignalDecodeGrading.grade(
        rtSimpleTotal: 0, rtSimpleHits: 0, rtSimpleRTs: [],
        spatialTotal: 0, spatialCorrect: 0, spatialRTs: [],
        emotionTotal: 0, emotionCorrect: 0, emotionRTs: [],
        memoryTotal: 0, memoryCorrect: 0, memoryRTs: [],
        balanceTotal: 0, balanceCorrect: 0, balanceRTs: [],
      );
      expect(scores["Reaction Time (Simple)"], equals(0.0));
    });

    test('Perfect Scores', () {
      final scores = SignalDecodeGrading.grade(
        rtSimpleTotal: 5, rtSimpleHits: 5, rtSimpleRTs: [350, 350, 350, 350, 350],
        spatialTotal: 5, spatialCorrect: 5, spatialRTs: [600, 600, 600, 600, 600],
        emotionTotal: 5, emotionCorrect: 5, emotionRTs: [600, 600, 600, 600, 600],
        memoryTotal: 5, memoryCorrect: 5, memoryRTs: [800, 800, 800, 800, 800],
        balanceTotal: 5, balanceCorrect: 5, balanceRTs: [700, 700, 700, 700, 700],
      );
      expect(scores["Reaction Time (Simple)"], closeTo(1.0, 0.01));
      expect(scores["Spatial Awareness"], closeTo(1.0, 0.01));
    });

    test('Slow Reaction', () {
      final scores = SignalDecodeGrading.grade(
        rtSimpleTotal: 5, rtSimpleHits: 5, rtSimpleRTs: [1400, 1400, 1400, 1400, 1400], // 350+1050 = 1400 is limit for perfect
        spatialTotal: 0, spatialCorrect: 0, spatialRTs: [],
        emotionTotal: 0, emotionCorrect: 0, emotionRTs: [],
        memoryTotal: 0, memoryCorrect: 0, memoryRTs: [],
        balanceTotal: 0, balanceCorrect: 0, balanceRTs: [],
      );
      // 1400ms is the worst case (1.0 - (1400-350)/1050 = 0)
      expect(scores["Reaction Time (Simple)"], equals(0.0));
    });
  });
}
