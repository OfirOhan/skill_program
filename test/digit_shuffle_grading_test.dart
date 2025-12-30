import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/digit_shuffle_grading.dart';

Map<String, double> runSimulation({
  required List<double> roundAccuracies,
  required List<int> roundTimesMs,
  required List<int> roundTaskTypes,
}) {
  return DigitShuffleGrading.grade(
    roundAccuracies: roundAccuracies,
    roundTimesMs: roundTimesMs,
    roundTaskTypes: roundTaskTypes,
  );
}

void main() {
  group('Digit Shuffle – The Big Three', () {

    // 1. PERFECT PERFORMER
    test('Perfect Performer', () {
      final results = runSimulation(
        roundAccuracies: [1.0, 1.0, 1.0, 1.0, 1.0],
        roundTimesMs: [2000, 2000, 2000, 2000, 2000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(1.0, 0.01));
      expect(results["Working Memory"], closeTo(1.0, 0.01));
      expect(results["Information Processing Speed"], closeTo(1.0, 0.02));
    });

    // 2. ROTE MEMORY SPECIALIST
    test('Rote Memory Specialist', () {
      // Inputs: Strong Recall (1.0), Fails all Manipulation (0.0)
      final results = runSimulation(
        roundAccuracies: [1.0, 0.0, 0.0, 0.0, 1.0],
        roundTimesMs: [3000, 3000, 3000, 3000, 3000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(0.4, 0.03)); // Weighted by rounds 0 & 4
      expect(results["Working Memory"], closeTo(0.0, 0.01));    // Avg(0.0, 0.0, 0.0)
      expect(results["Information Processing Speed"], closeTo(0.38, 0.03)); //!
    });

    // 3. PROCESSING MASTER
    test('Processing Master', () {
      // Inputs: Weaker Recall (0.6, 0.71), Perfect Manipulation (1.0)
      final results = runSimulation(
        roundAccuracies: [0.60, 1.0, 1.0, 1.0, 0.71],
        roundTimesMs: [4000, 2500, 2500, 2500, 4000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(0.82, 0.02));
      expect(results["Working Memory"], closeTo(1.0, 0.01)); // Avg(1.0, 1.0, 1.0)
      expect(results["Information Processing Speed"], closeTo(0.86, 0.03));
    });

    // 4. MIXED SKILL SPECIALIST
    test('Mixed Skill Specialist', () {
      // Round 1 (Sort): 0.60
      // Round 2 (Add):  1.0
      // Round 3 (Sort): 1.0
      // WM = Avg(0.60, 1.0, 1.0) = 0.866...
      final results = runSimulation(
        roundAccuracies: [0.60, 0.60, 1.0, 1.0, 0.71],
        roundTimesMs: [4000, 4000, 3500, 3500, 5000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Working Memory"], closeTo(0.82, 0.02));
      expect(results["Rote Memorization"], closeTo(0.7, 0.02));
      expect(results["Information Processing Speed"], closeTo(0.78, 0.03));
    });

    // 5. PRECISE BUT SLOW PROCESSOR
    test('Precise but Slow Processor', () {
      final results = runSimulation(
        roundAccuracies: [1.0, 1.0, 1.0, 1.0, 1.0],
        roundTimesMs: [12000, 12000, 12000, 12000, 12000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(1.0, 0.01));
      expect(results["Working Memory"], closeTo(1.0, 0.01));
      expect(results["Information Processing Speed"], closeTo(0.67, 0.03)); // Heavily penalized for time !!
    });

    // 6. SPAM CLICKER
    test('Spam Clicker', () {
      final results = runSimulation(
        roundAccuracies: [0.0, 0.0, 0.0, 0.0, 0.0],
        roundTimesMs: [100, 100, 100, 100, 100],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(0.0, 0.01));
      expect(results["Working Memory"], closeTo(0.0, 0.01));
      expect(results["Information Processing Speed"], closeTo(0.0, 0.01)); // Speed is 0 if accuracy is 0
    });

    // 7. TASK-SWITCHING FATIGUE (Simulates failing on switch)
    test('Task-Switching Fatigue', () {
      // Round 1 (Sort): 0.0
      // Round 2 (Add):  1.0
      // Round 3 (Sort): 1.0
      // WM = Avg(0.0, 1.0, 1.0) = 0.666...
      final results = runSimulation(
        roundAccuracies: [1.0, 0.0, 1.0, 1.0, 1.0],
        roundTimesMs: [3000, 3000, 5000, 4000, 3000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(0.82, 0.02));
      expect(results["Working Memory"], closeTo(0.67, 0.02));
      expect(results["Information Processing Speed"], closeTo(0.8, 0.05));
    });

    // 8. PARTIAL CREDIT VALIDATION
    test('Partial Credit Validation', () {
      // Round 1 (Sort): 1.0
      // Round 2 (Add):  0.5
      // Round 3 (Sort): 1.0
      // WM = Avg(1.0, 0.5, 1.0) = 0.833...
      final results = runSimulation(
        roundAccuracies: [0.80, 1.00, 0.50, 1.00, 0.86],
        roundTimesMs: [4000, 4000, 4000, 4000, 4000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(0.73, 0.02)); //!
      expect(results["Working Memory"], closeTo(0.8, 0.02)); //!
      expect(results["Information Processing Speed"], closeTo(0.82, 0.03));
    });

    // 9. SPEED VS ACCURACY TRADEOFF
    test('Speed vs Accuracy Tradeoff', () {
      final fast = runSimulation(
        roundAccuracies: [1.0, 1.0, 1.0, 1.0, 1.0],
        roundTimesMs: [2000, 2000, 2000, 2000, 2000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );
      final slow = runSimulation(
        roundAccuracies: [1.0, 1.0, 1.0, 1.0, 1.0],
        roundTimesMs: [8000, 8000, 8000, 8000, 8000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(fast["Information Processing Speed"], closeTo(1.0, 0.02));
      expect(slow["Information Processing Speed"], closeTo(0.8, 0.03)); //!

      expect(fast["Rote Memorization"], closeTo(slow["Rote Memorization"]!, 0.01));
      expect(fast["Working Memory"], closeTo(slow["Working Memory"]!, 0.01));
    });

    // 10. EARLY FADING
    test('Early Fading', () {
      // Round 1 (Sort): 1.0
      // Round 2 (Add):  1.0
      // Round 3 (Sort): 0.83
      // WM = Avg(1.0, 1.0, 0.83) = 0.943...
      final results = runSimulation(
        roundAccuracies: [1.0, 1.0, 1.0, 0.83, 0.86],
        roundTimesMs: [3000, 3000, 4000, 5000, 6000],
        roundTaskTypes: [0, 1, 2, 1, 0],
      );

      expect(results["Rote Memorization"], closeTo(0.85, 0.02));
      expect(results["Working Memory"], closeTo(0.90, 0.02));
      expect(results["Information Processing Speed"], closeTo(0.87, 0.03));
    });
  });
}

// I want to punish more for getting questions wrong, but still a lil compensation if you get some right. change the calculation of Information Processing Speed (might be enough when i down the rote as well)
