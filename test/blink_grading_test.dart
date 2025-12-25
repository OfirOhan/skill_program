import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/blink_grading.dart';

void main() {
  group('Blink Match Grading – Deterministic Tests', () {
    test('Perfect player', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 0,
        hitReactionTimesMs: List.filled(7, 600),
        balancedAccFirstHalf: 1.0,
        balancedAccSecondHalf: 1.0,
      );

      expect(scores["Working Memory"]!, greaterThan(0.9));
      expect(scores["Response Inhibition"]!, equals(1.0));
      expect(scores["Reaction Time (Choice)"]!, greaterThan(0.9));
      expect(scores["Observation / Vigilance"]!, equals(1.0));
    });

    test('Single false alarm', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 1,
        hitReactionTimesMs: List.filled(7, 600),
        balancedAccFirstHalf: 1.0,
        balancedAccSecondHalf: 0.95,
      );

      expect(scores["Response Inhibition"]!, lessThan(1.0));
      expect(scores["Response Inhibition"]!, greaterThan(0.85));
    });

    test('Passive player (no engagement)', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 0,
        falseAlarms: 0,
        hitReactionTimesMs: [],
        balancedAccFirstHalf: 0.5,
        balancedAccSecondHalf: 0.5,
      );

      scores.forEach((_, v) => expect(v, equals(0.0)));
    });

    test('Spammer (presses everything)', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 7,
        falseAlarms: 11,
        hitReactionTimesMs: List.filled(7, 450),
        balancedAccFirstHalf: 0.3,
        balancedAccSecondHalf: 0.3,
      );

      expect(scores["Response Inhibition"]!, equals(0.0));
      expect(scores["Working Memory"]!, equals(0.0));
    });

    test('Fatigue effect only hurts vigilance', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 6,
        falseAlarms: 2,
        hitReactionTimesMs: List.filled(6, 700),
        balancedAccFirstHalf: 0.95,
        balancedAccSecondHalf: 0.6,
      );

      expect(
        scores["Observation / Vigilance"]!,
        lessThan(scores["Working Memory"]!),
      );
    });

    test('Engagement threshold works', () {
      final scores = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 2,
        falseAlarms: 0,
        hitReactionTimesMs: [800, 820],
        balancedAccFirstHalf: 0.8,
        balancedAccSecondHalf: 0.8,
      );

      expect(scores["Working Memory"]!, lessThan(0.5));
    });
  });

  group('Blink Match Grading – Invariants', () {
    test('Increasing FA never increases RI', () {
      final lowFA = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,
        hitReactionTimesMs: List.filled(5, 650),
        balancedAccFirstHalf: 0.9,
        balancedAccSecondHalf: 0.9,
      );

      final highFA = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 5,
        hitReactionTimesMs: List.filled(5, 650),
        balancedAccFirstHalf: 0.9,
        balancedAccSecondHalf: 0.9,
      );

      expect(
        highFA["Response Inhibition"]!,
        lessThanOrEqualTo(lowFA["Response Inhibition"]!),
      );
    });

    test('Better RT never reduces RT score', () {
      final slow = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,
        hitReactionTimesMs: List.filled(5, 1200),
        balancedAccFirstHalf: 0.9,
        balancedAccSecondHalf: 0.9,
      );

      final fast = gradeBlinkFromStats(
        targets: 7,
        distractors: 11,
        hits: 5,
        falseAlarms: 1,
        hitReactionTimesMs: List.filled(5, 600),
        balancedAccFirstHalf: 0.9,
        balancedAccSecondHalf: 0.9,
      );

      expect(
        fast["Reaction Time (Choice)"]!,
        greaterThanOrEqualTo(slow["Reaction Time (Choice)"]!),
      );
    });
  });
}
