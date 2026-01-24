import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/chart_grading.dart';

void main() {
  const double eps = 0.05;

  group('ChartGrading – Realistic Behavioral Scenarios', () {

    // ============================================================
    // 1) PERFECT CHART ANALYST
    //    - All 5 questions correct
    //    - Good speed (under 50% of time limits)
    //    - Should excel at all three skills
    // ============================================================
    test('Perfect chart analyst – everything near 1.0', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, true, true],
        reactionTimes: [6000, 6000, 12000, 14000, 16000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(1.0, eps));
      expect(scores['Pattern Recognition']!, closeTo(1.0, eps));
    });

    // ============================================================
    // 2) VISUAL READER, MATH FAILURE
    //    - Gets Q1 and Q2 correct (simple visual tasks)
    //    - Fails Q3, Q4, Q5 (all math questions)
    //    - Shows pattern recognition but no quantitative reasoning
    // ============================================================
    test('Visual reader, math failure – low quant, decent pattern', () {
      final scores = ChartGrading.grade(
        results: [true, true, false, false, false],
        reactionTimes: [5000, 6000, 20000, 25000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.4, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.52, eps));
    });

    // ============================================================
    // 3) MATH SPECIALIST
    //    - Fails Q1, Q2 (simple visual comparisons)
    //    - Gets Q3, Q4, Q5 correct (all math)
    //    - Strong quantitative, weak on basic patterns
    // ============================================================
    test('Math specialist – high quant, low pattern/visual', () {
      final scores = ChartGrading.grade(
        results: [false, false, true, true, true],
        reactionTimes: [12000, 13000, 18000, 22000, 28000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.72, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.6, eps));
    });

    // ============================================================
    // 4) TOTAL FAILURE
    //    - All 5 questions wrong
    //    - Should score 0 on both skills
    // ============================================================
    test('Total failure – zeros across the board', () {
      final scores = ChartGrading.grade(
        results: [false, false, false, false, false],
        reactionTimes: [10000, 11000, 20000, 25000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.0, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.0, eps));
    });

    // ============================================================
    // 5) PATTERN RECOGNITION MASTER
    //    - Q2 correct with blazing speed (3 seconds)
    //    - Others are mixed but Q2 bonus dominates
    // ============================================================
    test('Pattern master – Q2 blazing fast and correct', () {
      final scores = ChartGrading.grade(
        results: [true, true, false, true, false],
        reactionTimes: [6000, 3000, 20000, 18000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.64, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.74, eps));
    });

    // ============================================================
    // 6) PATTERN BLIND
    //    - Gets everything correct EXCEPT Q2 (pattern identification)
    //    - Pattern score should be notably lower
    // ============================================================
    test('Pattern blind – fails Q2 specifically', () {
      final scores = ChartGrading.grade(
        results: [true, false, true, true, true],
        reactionTimes: [6000, 14000, 12000, 15000, 18000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.88, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.82, eps));
    });

    // ============================================================
    // 7) SLOW BUT ACCURATE
    //    - All correct
    //    - But uses nearly full time on each question
    //    - Should get full quantitative but reduced speed bonuses
    // ============================================================
    test('Slow but accurate – no speed bonuses', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, true, true],
        reactionTimes: [14000, 14000, 24000, 29000, 34000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(1.0, eps));
      expect(scores['Pattern Recognition']!, closeTo(1.0, eps));
    });

    // ============================================================
    // 8) SPEED DEMON
    //    - All correct with blazing speed
    //    - Should max out all skills with bonuses
    // ============================================================
    test('Speed demon – maximum speed bonuses', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, true, true],
        reactionTimes: [2000, 2000, 5000, 6000, 7000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(1.0, eps));
      expect(scores['Pattern Recognition']!, closeTo(1.0, eps));
    });

    // ============================================================
    // 9) VISUAL DIFFICULTY DEGRADATION
    //    - First 3 correct (easier questions)
    //    - Last 2 wrong (hardest visual complexity)
    //    - Visual acuity should reflect difficulty-weighted failure
    // ============================================================
    test('Visual difficulty degradation – fails on harder questions', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, false, false],
        reactionTimes: [5000, 6000, 12000, 28000, 33000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.64, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.68, eps));
    });

    // ============================================================
    // 10) TIMEOUT VICTIM
    //    - First 3 correct with decent speed
    //    - Last 2 wrong at full timeout (gave up)
    // ============================================================
    test('Timeout victim – started strong, gave up', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, false, false],
        reactionTimes: [6000, 7000, 14000, 30000, 35000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.64, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.67, eps));
    });

    // ============================================================
    // 11) ALTERNATING SUCCESS
    //    - Q1 correct, Q2 wrong, Q3 correct, Q4 wrong, Q5 correct
    //    - Shows inconsistency across all skills
    // ============================================================
    test('Alternating success – inconsistent performance', () {
      final scores = ChartGrading.grade(
        results: [true, false, true, false, true],
        reactionTimes: [6000, 10000, 15000, 22000, 25000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.64, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.6, eps));
    });

    // ============================================================
    // 12) LEARNING CURVE
    //    - First 2 wrong (still learning)
    //    - Last 3 correct (figured it out)
    // ============================================================
    test('Learning curve – fails early, succeeds later', () {
      final scores = ChartGrading.grade(
        results: [false, false, true, true, true],
        reactionTimes: [12000, 13000, 15000, 18000, 20000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.72, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.6, eps));
    });

    // ============================================================
    // 13) FATIGUE PATTERN
    //    - First 3 correct (fresh start)
    //    - Last 2 wrong (tired)
    // ============================================================
    test('Fatigue pattern – strong start, weak finish', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, false, false],
        reactionTimes: [5000, 6000, 12000, 28000, 33000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.64, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.68, eps));
    });

    // ============================================================
    // 14) ONLY Q1 CORRECT
    //    - Single success on easiest question
    //    - Everything else wrong
    // ============================================================
    test('Only Q1 correct – minimal competence', () {
      final scores = ChartGrading.grade(
        results: [true, false, false, false, false],
        reactionTimes: [6000, 12000, 20000, 25000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.2, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.2, eps));
    });

    // ============================================================
    // 15) ONLY Q5 CORRECT
    //    - Single success on hardest question (lucky or highly skilled?)
    //    - Visual acuity should benefit from difficulty weight
    // ============================================================
    test('Only Q5 correct – hardest question only', () {
      final scores = ChartGrading.grade(
        results: [false, false, false, false, true],
        reactionTimes: [10000, 11000, 20000, 25000, 20000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.24, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.2, eps));
    });

    // ============================================================
    // 16) RANDOM GUESSING
    //    - 2 out of 5 correct (40% - below chance for 4 options)
    //    - Mixed times
    // ============================================================
    test('Random guessing – 40% accuracy', () {
      final scores = ChartGrading.grade(
        results: [false, true, false, false, true],
        reactionTimes: [8000, 9000, 18000, 22000, 25000],
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.44, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.46, eps));
    });

    // ============================================================
    // EDGE CASES
    // ============================================================

    test('Instant responses – sub-second reaction times', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, true, true],
        reactionTimes: [100, 200, 300, 400, 500],
        isMathQuestion: [false, false, true, true, true],
      );

      // Should handle extreme speed with maximum bonuses
      expect(scores['Quantitative Reasoning']!, closeTo(1.0, eps));
      expect(scores['Pattern Recognition']!, closeTo(1.0, eps));
    });

    test('At time limits – answered just before timeout', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, true, true],
        reactionTimes: [14999, 14999, 24999, 29999, 34999],
        isMathQuestion: [false, false, true, true, true],
      );

      // Correct but no speed bonuses
      expect(scores['Quantitative Reasoning']!, closeTo(1.0, eps));
      expect(scores['Pattern Recognition']!, closeTo(1.0, eps));
    });

    test('Mixed valid and timeout times', () {
      final scores = ChartGrading.grade(
        results: [true, true, true, false, false],
        reactionTimes: [5000, 6000, 12000, 30000, 35000], // Last 2 at exact timeout
        isMathQuestion: [false, false, true, true, true],
      );

      expect(scores['Quantitative Reasoning']!, closeTo(0.64, eps));
      expect(scores['Pattern Recognition']!, closeTo(0.68, eps));
    });
  });

  group('ChartGrading – Skill Isolation Tests', () {

    // ============================================================
    // QUANTITATIVE ISOLATION
    // ============================================================
    test('Math bonus verification – math correct should score higher', () {
      final mathCorrect = ChartGrading.grade(
        results: [false, false, true, true, true],
        reactionTimes: [10000, 11000, 18000, 22000, 26000],
        isMathQuestion: [false, false, true, true, true],
      );

      final nonMathCorrect = ChartGrading.grade(
        results: [true, true, true, false, false],
        reactionTimes: [6000, 7000, 12000, 25000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      // Math questions have bonus, so same number correct should yield higher score
      expect(mathCorrect['Quantitative Reasoning']!,
          greaterThan(nonMathCorrect['Quantitative Reasoning']!));
    });

    // ============================================================
    // PATTERN ISOLATION
    // ============================================================
    test('Q2 bonus verification – Q2 correct should boost pattern score', () {
      final q2Correct = ChartGrading.grade(
        results: [false, true, false, false, false],
        reactionTimes: [10000, 6000, 20000, 25000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      final q1Correct = ChartGrading.grade(
        results: [true, false, false, false, false],
        reactionTimes: [6000, 10000, 20000, 25000, 30000],
        isMathQuestion: [false, false, true, true, true],
      );

      // Q2 has pattern bonus, should score higher than Q1
      expect(q2Correct['Pattern Recognition']!,
          greaterThan(q1Correct['Pattern Recognition']!));
    });

    test('Speed bonus verification – fast Q2 should score even higher', () {
      final fastQ2 = ChartGrading.grade(
        results: [false, true, false, false, false],
        reactionTimes: [10000, 3000, 20000, 25000, 30000], // 3s = 20% of 15s limit
        isMathQuestion: [false, false, true, true, true],
      );

      final slowQ2 = ChartGrading.grade(
        results: [false, true, false, false, false],
        reactionTimes: [10000, 13000, 20000, 25000, 30000], // 13s = near limit
        isMathQuestion: [false, false, true, true, true],
      );

      // Fast correct Q2 should beat slow correct Q2
      expect(fastQ2['Pattern Recognition']!,
          greaterThan(slowQ2['Pattern Recognition']!));
    });
  });
}