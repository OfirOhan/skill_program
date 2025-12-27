import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/plan_push_grading.dart';

void main() {
  group('Plan Push Grading Tests', () {
    test('No Days Played', () {
      final scores = PlanPushGrading.grade(
        earnedValues: [],
        optimalValues: [],
        submitRTs: [],
        overtimeErrors: 0,
        underTimeErrors: 0,
      );
      expect(scores["Planning & Prioritization"], equals(0.0));
    });

    test('Perfect Planning', () {
      final scores = PlanPushGrading.grade(
        earnedValues: [100, 100],
        optimalValues: [100, 100],
        submitRTs: [5000, 5000],
        overtimeErrors: 0,
        underTimeErrors: 0,
      );
      expect(scores["Planning & Prioritization"], equals(1.0));
      expect(scores["Constraint Management"], equals(1.0));
    });

    test('Poor Risk Management', () {
      final scores = PlanPushGrading.grade(
        earnedValues: [50, 50],
        optimalValues: [100, 100],
        submitRTs: [5000, 5000],
        overtimeErrors: 2, // Every day overtime
        underTimeErrors: 0,
      );
      expect(scores["Risk Management"], equals(0.0));
    });
  });
}
