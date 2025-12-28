import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/matrix_grading.dart';

void main() {
  // --- 1. SETUP: THE EXACT GAME STRUCTURE ---
  // These match the order and difficulty in your Matrix game.
  final List<String> gameTypes = [
    "Rotation",                        // Round 1 (Inductive-heavy)
    "Subtraction",                     // Round 2 (Quant-heavy)
    "Cyclic Pattern",                  // Round 3 (Inductive-heavy)
    "Sudoku Logic (Unique Row/Col)",   // Round 4 (Deductive-heavy)
    "Arithmetic",                      // Round 5 (Quant + Deductive)
    "Column XOR",                      // Round 6 (Deductive-heavy)
  ];

  final List<int> gameDiffs = [1, 2, 3, 4, 5, 6];

  // --- 2. HELPER FUNCTION ---
  Map<String, double> runSimulation({
    required List<bool> results, // Must be length 6
    required List<int> times,    // Must be length 6 (ms)
  }) {
    assert(results.length == 6);
    assert(times.length == 6);

    return gradeMatrixFromStats(
      itemDescriptions: gameTypes,
      itemDifficulties: gameDiffs,
      itemResults: results,
      itemTimesMs: times,
    );
  }

  group('Matrix Logic – Human Cognitive Profiles', () {
    // ----------------------------------------------------------------
    // PROFILE 1: THE "INTUITIVE GENIUS" VS "THE OVERTHINKER"
    // ----------------------------------------------------------------
    // Two people solve everything correctly.
    // - Intuitive: fast, pattern-based thinking.
    // - Overthinker: slow, methodical, but reaches same conclusions.
    //
    // We expect:
    // - Both have strong reasoning scores (they're clearly smart).
    // - Intuitive has slightly higher reasoning scores.
    // - Intuitive has MUCH higher Information Processing Speed.
    test('Profile: Intuitive Genius vs Overthinker', () {
      final intuitive = runSimulation(
        results: [true, true, true, true, true, true],
        times: [2000, 2000, 2000, 2000, 2000, 2000], // Fast ~2s
      );
      final overthinker = runSimulation(
        results: [true, true, true, true, true, true],
        times: [12000, 12000, 12000, 12000, 12000, 12000], // Slow ~12s
      );

      final iInd = intuitive["Inductive Reasoning"]!;
      final iDed = intuitive["Deductive Reasoning"]!;
      final iQuant = intuitive["Quantitative Reasoning"]!;
      final iSpeed = intuitive["Information Processing Speed"]!;

      final oInd = overthinker["Inductive Reasoning"]!;
      final oDed = overthinker["Deductive Reasoning"]!;
      final oQuant = overthinker["Quantitative Reasoning"]!;
      final oSpeed = overthinker["Information Processing Speed"]!;

      // Both are clearly high in reasoning (smart people).
      expect(iInd, equals(1));
      expect(iDed, equals(1));
      expect(iQuant, equals(1));

      expect(oInd, greaterThan(0.85));
      expect(oDed, greaterThan(0.85));
      expect(oQuant, greaterThan(0.85));

      // Intuitive has *slightly* higher reasoning scores.
      expect(iInd, greaterThan(oInd));
      expect(iDed, greaterThan(oDed));
      expect(iQuant, greaterThan(oQuant));

      // But the big difference is speed: intuitive >> overthinker.
      expect(iSpeed, equals(1));
      expect(oSpeed, greaterThan(0.6));
      expect(
        iSpeed,
        greaterThan(oSpeed * 1.5),
        reason:
        "The intuitive thinker should look much faster overall than the overthinker.",
      );
    });

    // ----------------------------------------------------------------
    // PROFILE 2: THE "VISUAL SAVANT" (High Spatial, Weak Math)
    // ----------------------------------------------------------------
    // This person crushes abstract visual & logical patterns:
    //   Rotation, Cyclic Pattern, Sudoku, XOR
    // But consistently fails purely numeric / arithmetic items:
    //   Subtraction, Arithmetic.
    //
    // What we expect from the scores:
    // - Inductive & Deductive: clearly high.
    // - Quantitative: clearly lower.
    // - The profile shows a specialized spike, not a flat "average".
    test('Profile: The Visual Savant (High Spatial, Weak Math)', () {
      final savant = runSimulation(
        // R1 Rot T, R2 Sub F, R3 Cyc T, R4 Sud T, R5 Arith F, R6 XOR T
        results: [true, false, true, true, false, true],
        times: [4000, 4000, 4000, 4000, 4000, 4000], // Steady moderate speed
      );

      final ind = savant["Inductive Reasoning"]!;
      final ded = savant["Deductive Reasoning"]!;
      final quant = savant["Quantitative Reasoning"]!;
      final speed = savant["Information Processing Speed"]!;

      // Strong pattern/logic abilities.
      expect(ind, greaterThan(0.7),
          reason: "Should show strong inductive pattern recognition.");
      expect(ded, greaterThan(0.65),
          reason: "Should show strong deductive constraint handling.");

      // Quant is clearly weaker.
      expect(quant, lessThan(0.5),
          reason: "Consistent failures on math items should show up here.");

      // And the gap should be noticeable, not tiny.
      expect(ind, greaterThan(quant + 0.2));
      expect(ded, greaterThan(quant + 0.2));

      // Processing speed is fine / moderate, not extreme in either direction.
      expect(speed, greaterThan(0.4));
      expect(speed, lessThan(0.85));
    });

    // ----------------------------------------------------------------
    // PROFILE 3: THE "FATIGUE CRASH" (Starts Strong, Crashes on Hard Items)
    // ----------------------------------------------------------------
    // This person:
    // - Solves early/easy items well (Rounds 1–3).
    // - When difficulty spikes (Rounds 4–6), they time out / get them wrong.
    //
    // We expect:
    // - Clear evidence of some reasoning ability (they're not "0" in anything).
    // - Deductive slightly weaker than Inductive/Quant (hard items are Ded-heavy).
    // - Speed: decent at the start, but overall not top-tier because accuracy drops.
    test('Profile: The Fatigue Crash', () {
      final quitter = runSimulation(
        // Right on 1,2,3. Wrong on 4,5,6.
        results: [true, true, true, false, false, false],
        // Fast start, then 15s timeouts (giving up / panic).
        times: [3000, 3000, 3000, 15000, 15000, 15000],
      );

      final ind = quitter["Inductive Reasoning"]!;
      final ded = quitter["Deductive Reasoning"]!;
      final quant = quitter["Quantitative Reasoning"]!;
      final speed = quitter["Information Processing Speed"]!;

      // They DO show some real reasoning skill.
      expect(ind, greaterThan(0.4));
      expect(quant, greaterThan(0.4));

      // Deductive suffers the most (all Ded-heavy items are at the end).
      expect(ded, lessThan(ind),
          reason: "Deductive should lag behind Inductive here.");
      expect(ded, lessThan(quant),
          reason: "Deductive should also lag behind Quantitative.");

      // Speed should be "OK but not amazing" (fast at first, accuracy 50%).
      expect(speed, lessThan(0.6));
    });

    // ----------------------------------------------------------------
    // PROFILE 4: THE "LUCKY GUESSER" (Random Clicker)
    // ----------------------------------------------------------------
    // This person:
    // - Clicks almost instantly on everything (~100ms).
    // - Gets ONLY the last (hardest) item right, purely by chance.
    //
    // We expect:
    // - Reasoning scores stay low (one lucky hit doesn't make them a genius).
    // - Speed score is limited because it's gated by poor accuracy.
    test('Profile: The Lucky Guesser (Spammer)', () {
      final gambler = runSimulation(
        // Got only the last one right (Diff 6) purely by luck
        results: [false, false, false, false, false, true],
        times: [100, 100, 100, 100, 100, 100], // Spam-clicking
      );

      final ind = gambler["Inductive Reasoning"]!;
      final ded = gambler["Deductive Reasoning"]!;
      final quant = gambler["Quantitative Reasoning"]!;
      final speed = gambler["Information Processing Speed"]!;

      // All reasoning scores should remain low.
      expect(ind, lessThan(0.25));
      expect(ded, lessThan(0.35));
      expect(quant, lessThan(0.25));

      // Even though they are super fast, low accuracy caps the speed score.
      expect(speed, lessThan(0.41),
          reason: "Low accuracy must drag down the processing speed score.");
      expect(speed, greaterThan(0.2),
          reason: "We still acknowledge they respond quickly, even if badly.");
    });

    // ----------------------------------------------------------------
    // PROFILE 5: THE "AVERAGE JOE" (Balanced, mid-level performance)
    // ----------------------------------------------------------------
    // This person:
    // - Solves easy items (1,2,3).
    // - Struggles and fails once things get truly hard (4,5,6).
    // -> Classic "OK but not exceptional" profile.
    //
    // We expect:
    // - All reasoning scores mid-range (not 0, not 1).
    // - Inductive slightly above Deductive.
    // - Quantitative moderate.
    // - Speed moderate (not extreme).
    test('Profile: The Average Joe', () {
      final average = runSimulation(
        // Correct: 1,2,3. Wrong: 4,5,6.
        results: [true, true, true, false, false, false],
        times: [5000, 5000, 6000, 8000, 8000, 8000],
      );

      final ind = average["Inductive Reasoning"]!;
      final ded = average["Deductive Reasoning"]!;
      final quant = average["Quantitative Reasoning"]!;
      final speed = average["Information Processing Speed"]!;

      // Mid-range reasoning across the board.
      expect(ind, greaterThan(0.3));
      expect(ind, lessThan(0.75));

      expect(ded, greaterThan(0.1));
      expect(ded, lessThan(0.6));

      expect(quant, greaterThan(0.3));
      expect(quant, lessThan(0.7));

      // Inductive should be a bit stronger than Deductive.
      expect(ind, greaterThan(ded));

      // Speed: solid but not elite and not terrible.
      expect(speed, greaterThan(0.3));
      expect(speed, lessThan(0.8));
    });
    test('Profile: The Perfect Performer', () {
      final perfect = runSimulation(
        results: [true, true, true, true, true, true],
        times: [2500, 2500, 2500, 2500, 2500, 2500],
      );

      // Reasoning should be near ceiling (fast correct = ~1.0)
      expect(perfect["Inductive Reasoning"], closeTo(1.0, 0.02));
      expect(perfect["Deductive Reasoning"], closeTo(1.0, 0.02));
      expect(perfect["Quantitative Reasoning"], closeTo(1.0, 0.02));

      // Speed should be maximal
      expect(perfect["Information Processing Speed"], closeTo(1.0, 0.03));
    });

    /// PROFILE: The Quantitative Specialist
    /// Excels only on number/counting tasks, struggles with abstract patterns.
    /// Should show high Quant, low Inductive, moderate Deductive.
    test('Profile: The Quantitative Specialist', () {
      // Only Subtraction (Q2) and Arithmetic (Q5) correct
      final quantNerd = runSimulation(
        results: [false, true, false, false, true, false],
        times: [4000, 4000, 4000, 4000, 4000, 4000],
      );

      final ind = quantNerd["Inductive Reasoning"]!;
      final ded = quantNerd["Deductive Reasoning"]!;
      final quant = quantNerd["Quantitative Reasoning"]!;
      final speed = quantNerd["Information Processing Speed"]!;

      // Quant should be clearly highest
      expect(quant, greaterThan(0.65));
      expect(quant, greaterThan(ind + 0.25));
      expect(quant, greaterThan(ded + 0.20));

      // Inductive should be low (missed Rotation + Cyclic + XOR)
      expect(ind, lessThan(0.45));

      // Speed is moderate (50% accuracy, consistent 4s)
      expect(speed, closeTo(0.55, 0.05));
    });

    /// PROFILE: The Abstract Thinker (Low Quant)
    /// Strong on visual/logic puzzles, fails both number-based items.
    /// Should show high Inductive/Deductive, low Quant.
    test('Profile: The Abstract Thinker', () {
      // Misses only Subtraction (Q2) and Arithmetic (Q5)
      final abstract = runSimulation(
        results: [true, false, true, true, false, true],
        times: [3500, 3500, 3500, 3500, 3500, 3500],
      );

      final ind = abstract["Inductive Reasoning"]!;
      final ded = abstract["Deductive Reasoning"]!;
      final quant = abstract["Quantitative Reasoning"]!;
      final speed = abstract["Information Processing Speed"]!;

      // Inductive and Deductive should be strong
      expect(ind, greaterThan(0.799));
      expect(ded, greaterThan(0.8));

      // Quantitative should be low (missed both core quant items)
      expect(quant, lessThan(0.45));
      expect(quant, greaterThan(0.38));

      // Gap should be meaningful
      expect(ind, greaterThan(quant + 0.30));
      expect(ded, greaterThan(quant + 0.25));

      // Speed is high (4/6 correct, fast)
      expect(speed, closeTo(0.80, 0.04));
    });

    /// PROFILE: The Slow and Steady Solver
    /// Gets all correct, but takes 10–12 seconds per item (methodical).
    /// Should show high reasoning, moderate speed.
    test('Profile: The Slow and Steady Solver', () {
      final steady = runSimulation(
        results: [true, true, true, true, true, true],
        times: [11000, 11000, 11000, 11000, 11000, 11000],
      );

      final ind = steady["Inductive Reasoning"]!;
      final ded = steady["Deductive Reasoning"]!;
      final quant = steady["Quantitative Reasoning"]!;
      final speed = steady["Information Processing Speed"]!;

      // Reasoning should still be high (all correct)
      expect(ind, greaterThan(0.89)); // 0.85 floor + mild penalty
      expect(ded, greaterThan(0.89));
      expect(quant, greaterThan(0.89));

      // But speed should reflect deliberation
      expect(speed, closeTo(0.7, 0.04)); // ~0.65 due to 100% accuracy + 11s median
    });

    /// PROFILE: The Random Guesser
    /// 50% accuracy by chance, very fast responses (likely guessing).
    /// Should show low reasoning, moderate-but-misleading speed.
    test('Profile: The Random Guesser', () {
      final guesser = runSimulation(
        results: [true, false, true, false, true, false],
        times: [1000, 1000, 1000, 1000, 1000, 1000], // unnaturally fast
      );

      final ind = guesser["Inductive Reasoning"]!;
      final ded = guesser["Deductive Reasoning"]!;
      final quant = guesser["Quantitative Reasoning"]!;
      final speed = guesser["Information Processing Speed"]!;

      // Reasoning should be low (correct by chance, not skill)
      expect(ind, lessThan(0.55));
      expect(ded, lessThan(0.55));
      expect(quant, lessThan(0.55));

      // Speed might look high, but accuracy gating should suppress it
      // Median = 1000 → baseSpeed=1.0, but accuracy=0.5 → sqrt(0.5)=0.707
      // Plus: effectiveTimes includes 15s for incorrect? No — in this version, IPS uses actual time for correct, 15s for incorrect.
      // But in our current model: incorrect = 15s in effectiveTimes → median = (1000+15000)/2 = 8000 → baseSpeed ≈ 0.85
      // Then: 0.85 * sqrt(0.5) ≈ 0.60
      expect(speed, closeTo(0.60, 0.05));
    });
  });
}
