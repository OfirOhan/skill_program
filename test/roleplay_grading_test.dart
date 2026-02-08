import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/roleplay_grading.dart';

void main() {
  group('RoleplayGrading', () {
    const eps = 0.05;
    const int totalCues = 8;
    const int timeoutMs = 25000;

    // -------------------------------------------------------------------------
    // Game setup: 8 fixed cues as in lib/roleplay_game.dart
    // Word counting rule: simple whitespace-based tokenization.
    // -------------------------------------------------------------------------

    const List<int> contextWordCounts = [
      13, // 1: "A close friend messages you after you answered them many hours late."
      13, // 2: "You show a new outfit to a friend who pauses before saying this."
      17, // 3: "You ask a friend if they're okay with you joining plans they made with others."
      14, // 4: "You ask your manager whether to take a risky shortcut on an important project."
      13, // 5: "After you help with a tricky task, a coworker smiles and says this."
      16, // 6: "After you change a plan they cared about, your colleague looks tense and avoids eye contact."
      15, // 7: "In a team meeting, you challenge your manager's idea. They cut you off and say this."
      15, // 8: "You show a first draft to your supervisor. Peers just got strong praise on their work."
    ];

    const List<int> quoteWordCounts = [
      4, // "Thanks for finally replying."
      4, // "That's… an interesting choice."
      7, // "I mean… if you really want to."
      6, // "Do what you think is best."
      5, // "We should grab coffee sometime."
      6, // "I'm totally fine with it. 😊"
      4, // "Let's talk after this."
      5, // "For now, this will do."
    ];

    // Sum of all options' words per cue (3 options each)
    const List<int> optionsWordCounts = [
      35, // cue 1: 12 + 9 + 14
      35, // cue 2: 13 + 9 + 13
      41, // cue 3: 15 + 13 + 13
      42, // cue 4: 13 + 12 + 17
      32, // cue 5: 13 + 11 + 8
      35, // cue 6: 13 + 14 + 8
      48, // cue 7: 16 + 15 + 17
      46, // cue 8: 15 + 14 + 17
    ];

    // Pragmatics = cues 1–4, Social Context = cues 5–8
    const List<bool> isPragmatic = [
      true, true, true, true,  // 1–4
      false, false, false, false,
    ];

    const List<bool> isSocialContext = [
      false, false, false, false,
      true, true, true, true,   // 5–8
    ];

    Map<String, double> callGrade({
      required List<bool> results,
      required List<int> reactionTimes,
    }) {
      assert(results.length == totalCues);
      assert(reactionTimes.length == totalCues);

      return RoleplayGrading.grade(
        totalCues: totalCues,
        results: results,
        reactionTimes: reactionTimes,
        isPragmatic: isPragmatic,
        isSocialContext: isSocialContext,
        contextWordCounts: contextWordCounts,
        quoteWordCounts: quoteWordCounts,
        optionsWordCounts: optionsWordCounts,
      );
    }

    // =========================================================================
    // BEHAVIORAL PERSONAS (REALISTIC 8-ROUND RUNS)
    // =========================================================================

    group('Behavioral Personas', () {
      test('1. Elite reader – all correct, consistently fast', () {
        // Type: very strong social/pragmatic reader.
        // Behavior: answers all 8 correctly, in ~7–10 seconds each.
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          7000, 7500, 8000, 8500, 9000, 9000, 9500, 10000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Full accuracy in both clusters.
        expect(out['Pragmatics']!, closeTo(1.0, eps));
        expect(out['Social Context Awareness']!, closeTo(1.0, eps));

        // Numerically: ≈ 1.0. This person is both fast and correct.
        expect(out['Reading Comprehension Speed']!, closeTo(1.0, eps),
            reason:
            'Elite, fast, accurate reader should land at the top of the comprehension speed scale. Got ${out['Reading Comprehension Speed']}');
      });

      test('2. Average careful reader – all correct, moderate times', () {
        // Type: solid but not ultra-fast.
        // Behavior: all correct, ~11–15 seconds per item.
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          11000, 12000, 13000, 14000, 13500, 13000, 14500, 15000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(1.0, eps));
        expect(out['Social Context Awareness']!, closeTo(1.0, eps));

        // Numerically ~1.0. Still very strong, very close to elite.
        expect(out['Reading Comprehension Speed']!, closeTo(1.0, eps),
            reason:
            'Average careful reader: high speed score. Got ${out['Reading Comprehension Speed']}');
      });

      test('3. Slow but careful – all correct, near the time limit', () {
        // Type: very cautious / slow processor, still gets things right.
        // Behavior: all correct, often close to 25 seconds.
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          20000, 21000, 22000, 23000, 21000, 20000, 22000, 24000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(1.0, eps));
        expect(out['Social Context Awareness']!, closeTo(1.0, eps));

        // Numerically ~0.63. Accurate but very slow should be mid-range on speed scale.
        expect(out['Reading Comprehension Speed']!, closeTo(0.63, eps),
            reason:
            'Consistently slow but accurate should give mid-range reading speed. Got ${out['Reading Comprehension Speed']}');
      });

      test('4. Fast guesser – quick decisions, mixed accuracy', () {
        // Type: fast, somewhat impulsive, not deeply processing.
        // Accuracy: 3/8 correct, more right on social than pragmatic.
        final results = <bool>[
          false, false, true, false,   // pragmatic: 1/4 correct
          true, false, false, true,    // social: 2/4 correct
        ];
        // Behavior: 6.5–9 seconds, usually answering well within time.
        final reactionTimes = <int>[
          6500, 7000, 7500, 8000, 7000, 8000, 8500, 9000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.25, eps),
            reason: '1/4 pragmatic cues correct. Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.5, eps),
            reason: '2/4 social cues correct. Got ${out['Social Context Awareness']}');

        // Numerically ~0.40. Fast but often wrong: speed dimension says "quick processing,
        // but interpretation is weak".
        expect(out['Reading Comprehension Speed']!, closeTo(0.55, eps),
            reason:
            'Fast but low accuracy: speed should be mid-low, not zero and not high. Got ${out['Reading Comprehension Speed']}');
      });

      test('5. Slow and inaccurate – long thinking, still misreads cues', () {
        // Type: struggles with this domain; slow and often wrong.
        // Accuracy: 2/8 correct total.
        final results = <bool>[
          false, true,  false, false,  // prag: 1/4
          true,  false, false, false,  // social: 1/4
        ];
        // Behavior: frequently near max time.
        final reactionTimes = <int>[
          18000, 20000, 21000, 23000, 20000, 21000, 22000, 24000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.25, eps),
            reason: '1/4 pragmatic correct. Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.25, eps),
            reason: '1/4 social correct. Got ${out['Social Context Awareness']}');

        // Numerically ≈ 0.11. Slow + inaccurate should land very low on the speed dimension.
        expect(out['Reading Comprehension Speed']!, closeTo(0.19, eps),
            reason:
            'Long times + mostly wrong → reading speed should be very low. Got ${out['Reading Comprehension Speed']}');
      });

      test('6. Pragmatics-strong, Social-weak – good verbal decoding, poor context', () {
        // Type: understands wording / subtext well, struggles with social dynamics.
        // Pragmatics: 3/4 correct, Social: 1/4 correct.
        final results = <bool>[
          true, true, true, false,   // pragmatic
          true, false, false, false, // social
        ];
        // Behavior: moderate times, within 10–15s range.
        final reactionTimes = <int>[
          10000, 11000, 12000, 13000, 12000, 13000, 14000, 15000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.75, eps),
            reason: '3/4 pragmatic cues correct. Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.25, eps),
            reason: '1/4 social cues correct. Got ${out['Social Context Awareness']}');

        // Numerically ≈ 0.70.
        expect(out['Reading Comprehension Speed']!, closeTo(0.70, eps),
            reason:
            'Moderate times + decent accuracy overall → mid-high speed around ~0.70. Got ${out['Reading Comprehension Speed']}');
      });

      test('7. Social-strong, Pragmatics-weak – good context sense, weaker linguistic decoding', () {
        // Type: reads situations well, but misreads phrasing subtleties.
        // Pragmatics: 1/4, Social: 3/4.
        final results = <bool>[
          false, false, true,  false,  // pragmatic
          true,  true,  true,  false,  // social
        ];
        final reactionTimes = <int>[
          12000, 13000, 12000, 14000, 11000, 12000, 13000, 14000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.25, eps),
            reason: 'Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.75, eps),
            reason: 'Got ${out['Social Context Awareness']}');

        // Same timing profile as previous; accuracy pattern flipped by cluster.
        // Numerically ≈ 0.70 again.
        expect(out['Reading Comprehension Speed']!, closeTo(0.70, eps),
            reason:
            'Speed should track overall behavior, not which cluster is strong. Got ${out['Reading Comprehension Speed']}');
      });

      test('8. Randomish mixed performance – about half right, mixed speeds', () {
        // Type: inconsistent, sometimes nails it, sometimes off.
        // Accuracy: 4/8 correct, 2 prag + 2 social, ~50%.
        final results = <bool>[
          true,  false, true,  false,  // prag: 2/4
          false, true,  false, true,   // social: 2/4
        ];
        final reactionTimes = <int>[
          9000, 16000, 12000, 18000, 14000, 10000, 19000, 15000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.5, eps),
            reason: 'Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.5, eps),
            reason: 'Got ${out['Social Context Awareness']}');

        // Numerically ≈ 0.65. Mixed timing + mixed accuracy → mid-range speed.
        expect(out['Reading Comprehension Speed']!, closeTo(0.65, eps),
            reason:
            'Around half right with varied times → central-ish reading speed. Got ${out['Reading Comprehension Speed']}');
      });
    });

    // =========================================================================
    // SPEED vs TIME SENSITIVITY – SAME PERSONA, DIFFERENT TIMING
    // =========================================================================

    group('Speed sensitivity with fixed accuracy pattern', () {
      test('9. Same mixed accuracy – fast vs slow response patterns', () {
        // Accuracy pattern: same as the random-ish persona above.
        final results = <bool>[
          true,  false, true,  false,
          false, true,  false, true,
        ];

        // Fast pattern: ~6–9s per cue.
        final fastTimes = <int>[
          6000, 6500, 7000, 7500, 8000, 8500, 9000, 9500,
        ];

        // Slow pattern: ~19–24s per cue.
        final slowTimes = <int>[
          19000, 20000, 21000, 22000, 21000, 20000, 22000, 23000,
        ];

        final fast = callGrade(results: results, reactionTimes: fastTimes);
        final slow = callGrade(results: results, reactionTimes: slowTimes);

        // Accuracy metrics must be identical.
        expect(fast['Pragmatics']!, closeTo(slow['Pragmatics']!, eps),
            reason: 'Fast: ${fast['Pragmatics']}, Slow: ${slow['Pragmatics']}');
        expect(
          fast['Social Context Awareness']!,
          closeTo(slow['Social Context Awareness']!, eps),
          reason: 'Accuracy-based skills must not depend on RTs. Fast: ${fast['Social Context Awareness']}, Slow: ${slow['Social Context Awareness']}',
        );

        // But speed must be higher in the fast pattern.
        expect(fast['Reading Comprehension Speed']!, greaterThan(slow['Reading Comprehension Speed']!),
            reason:
            'Same correctness profile: faster responses must yield higher reading speed. Fast: ${fast['Reading Comprehension Speed']}, Slow: ${slow['Reading Comprehension Speed']}');
      });

      test('10. Fully correct play – elite vs slow cautious', () {
        final allCorrect = List<bool>.filled(totalCues, true);

        // Elite fast (from persona 1).
        final fastTimes = <int>[
          7000, 7500, 8000, 8500, 9000, 9000, 9500, 10000,
        ];

        // Slow cautious (using near-timeout times).
        final slowTimes = <int>[
          20000, 21000, 22000, 23000, 21000, 20000, 22000, 24000,
        ];

        final fast = callGrade(results: allCorrect, reactionTimes: fastTimes);
        final slow = callGrade(results: allCorrect, reactionTimes: slowTimes);

        expect(fast['Pragmatics']!, closeTo(1.0, eps),
            reason: 'Got ${fast['Pragmatics']}');
        expect(fast['Social Context Awareness']!, closeTo(1.0, eps),
            reason: 'Got ${fast['Social Context Awareness']}');
        expect(slow['Pragmatics']!, closeTo(1.0, eps),
            reason: 'Got ${slow['Pragmatics']}');
        expect(slow['Social Context Awareness']!, closeTo(1.0, eps),
            reason: 'Accuracy skills must be identical for both. Got ${slow['Social Context Awareness']}');

        expect(fast['Reading Comprehension Speed']!, greaterThan(slow['Reading Comprehension Speed']!),
            reason:
            'Both are accurate, but elite-fast should clearly outrank slow-cautious on speed. Fast: ${fast['Reading Comprehension Speed']}, Slow: ${slow['Reading Comprehension Speed']}');
      });
    });

    // =========================================================================
    // SCORE BOUNDS & BASIC SANITY (STILL REALISTIC DATA)
    // =========================================================================

    group('Score bounds and basic sanity', () {
      test('11. All outputs stay in [0,1] for extreme but possible behavior', () {
        // Behavior: mix of very fast, very slow, correct and wrong.
        final results = <bool>[
          true,  false, true,  false,
          true,  false, true,  false,
        ];
        final reactionTimes = <int>[
          1500,              // extremely fast
          25000,             // timeout
          5000,              // fast
          22000,             // very slow
          12000,             // mid
          24000,             // near timeout
          9000,              // mid-fast
          20000,             // slow
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        out.forEach((skill, score) {
          expect(score, inInclusiveRange(0.0, 1.0),
              reason: '$skill should always stay clamped in [0,1] for any valid game run. Got $score');
        });
      });

      test('12. Ordering of personas matches intuition (elite > avg > slow; fast guesser > slow inaccurate)', () {
        // Reuse personas:
        final eliteResults = List<bool>.filled(totalCues, true);
        final eliteTimes = <int>[
          7000, 7500, 8000, 8500, 9000, 9000, 9500, 10000,
        ];

        final avgResults = List<bool>.filled(totalCues, true);
        final avgTimes = <int>[
          11000, 12000, 13000, 14000, 13500, 13000, 14500, 15000,
        ];

        final slowResults = List<bool>.filled(totalCues, true);
        final slowTimes = <int>[
          20000, 21000, 22000, 23000, 21000, 20000, 22000, 24000,
        ];

        final fastGuessResults = <bool>[
          false, false, true, false,
          true,  false, false, true,
        ];
        final fastGuessTimes = <int>[
          6500, 7000, 7500, 8000, 7000, 8000, 8500, 9000,
        ];

        final slowInaccResults = <bool>[
          false, true,  false, false,
          true,  false, false, false,
        ];
        final slowInaccTimes = <int>[
          18000, 20000, 21000, 23000, 20000, 21000, 22000, 24000,
        ];

        final elite = callGrade(results: eliteResults, reactionTimes: eliteTimes);
        final avg = callGrade(results: avgResults, reactionTimes: avgTimes);
        final slower = callGrade(results: slowResults, reactionTimes: slowTimes);
        final fastGuess = callGrade(results: fastGuessResults, reactionTimes: fastGuessTimes);
        final slowInacc = callGrade(results: slowInaccResults, reactionTimes: slowInaccTimes);

        final eliteSpeed = elite['Reading Comprehension Speed']!;
        final avgSpeed = avg['Reading Comprehension Speed']!;
        final slowSpeed = slower['Reading Comprehension Speed']!;
        final fastGuessSpeed = fastGuess['Reading Comprehension Speed']!;
        final slowInaccSpeed = slowInacc['Reading Comprehension Speed']!;

        expect(eliteSpeed, greaterThan(avgSpeed),
            reason: 'Elite should beat average on speed. Elite: $eliteSpeed, Avg: $avgSpeed');
        expect(avgSpeed, greaterThan(slowSpeed),
            reason: 'Average should beat slow on speed. Avg: $avgSpeed, Slow: $slowSpeed');
        expect(fastGuessSpeed, greaterThan(slowInaccSpeed),
            reason: 'Fast guesser should beat slow inaccurate in speed dimension. Fast: $fastGuessSpeed, Slow: $slowInaccSpeed');
      });
    });

    // =========================================================================
    // COMPREHENSIVE READING COMPREHENSION SPEED TESTS
    // =========================================================================

    group('Reading Comprehension Speed - Detailed Coverage', () {

      test('13. All correct at exact expected times → perfect 1.0 score', () {
        // Answer each question in exactly the expected time
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          12300, 12300, 14540, 13880, 12080, 13300, 14520, 14440,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Reading Comprehension Speed']!, closeTo(1.0, eps),
            reason:
            'All correct at expected times should give 1.0. Got ${out['Reading Comprehension Speed']}');
      });

      test('14. All correct at 1.5× expected → should give ~0.5 score', () {
        // Answer at 1.5× expected time (r=1.5, baseSpeed = 2.0-1.5 = 0.5)
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          18450, 18450, 21810, 20820, 18120, 19950, 21780, 21660,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Reading Comprehension Speed']!, closeTo(0.70, eps),
            reason:
            'All correct at 1.5× expected should give ~0.70. Got ${out['Reading Comprehension Speed']}');
      });

      test('15. All correct at timeout (25s) → very low scores for most rounds', () {
        // Answer at timeout for all rounds
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = List<int>.filled(totalCues, 25000);

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Rounds 1, 2, 5 can reach 0.0 at timeout
        // Other rounds get scores between 0.12-0.28
        // Median should be low
        expect(out['Reading Comprehension Speed']!, lessThan(0.5),
            reason:
            'All correct at timeout should give low speed score. Got ${out['Reading Comprehension Speed']}');
      });

      test('16. Fast but all wrong → low score due to 0.4 penalty', () {
        // Very fast times (5-8s) but all incorrect
        final results = List<bool>.filled(totalCues, false);
        final reactionTimes = <int>[
          5000, 5500, 6000, 6500, 7000, 7500, 8000, 8500,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // baseSpeed would be 1.0 (very fast), but × 0.4 correctness factor
        expect(out['Reading Comprehension Speed']!, closeTo(0.4, eps),
            reason:
            'Fast but all wrong should give ~0.4 due to correctness penalty. Got ${out['Reading Comprehension Speed']}');
      });

      test('17. Slow and all wrong → near zero score', () {
        // Very slow times (22-24s) and all incorrect
        final results = List<bool>.filled(totalCues, false);
        final reactionTimes = <int>[
          22000, 23000, 24000, 25000, 23000, 22000, 24000, 25000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Low baseSpeed × 0.4 correctness factor = very low
        expect(out['Reading Comprehension Speed']!, lessThan(0.15),
            reason:
            'Slow and all wrong should give very low score. Got ${out['Reading Comprehension Speed']}');
      });

      test('18. Mixed: half fast+correct, half slow+wrong', () {
        // First 4: fast and correct
        // Last 4: slow and wrong
        final results = <bool>[
          true, true, true, true,
          false, false, false, false,
        ];
        final reactionTimes = <int>[
          8000, 8000, 9000, 9000,  // fast, correct
          22000, 23000, 24000, 25000,  // slow, wrong
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Median of [1.0, 1.0, 1.0, 1.0, ~0.0, ~0.0, ~0.0, ~0.0]
        // Should be around 0.5
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.3, 0.7),
            reason:
            'Mixed fast-correct and slow-wrong should give mid-range. Got ${out['Reading Comprehension Speed']}');
      });

      test('19. One outlier slow round, rest fast → median robust to outlier', () {
        // 7 fast correct rounds, 1 timeout
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          8000, 8500, 9000, 9500, 10000, 10500, 11000, 25000,  // last one timeout
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Median should ignore the outlier, stay high
        expect(out['Reading Comprehension Speed']!, greaterThan(0.85),
            reason:
            'One outlier should not tank median-based speed. Got ${out['Reading Comprehension Speed']}');
      });

      test('20. Consistent moderate speed (all at expected) → exactly 1.0', () {
        // All rounds at their expected times
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          12300, 12300, 14540, 13880, 12080, 13300, 14520, 14440,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Reading Comprehension Speed']!, closeTo(1.0, eps),
            reason:
            'Consistent at-expected performance should give 1.0. Got ${out['Reading Comprehension Speed']}');
      });

      test('21. Gradient from fast to slow, all correct', () {
        // Gradually increasing times from fast to very slow
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          7000,   // very fast
          9000,   // fast
          11000,  // moderate
          13000,  // at expected
          16000,  // slow
          19000,  // slower
          22000,  // very slow
          25000,  // timeout
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Center-average of 4 middle values gives high score
        expect(out['Reading Comprehension Speed']!, closeTo(0.89, eps),
            reason:
            'Gradient with center-average should give high score. Got ${out['Reading Comprehension Speed']}');
      });

      test('22. All wrong at expected times → 0.4 across the board', () {
        // Perfect timing but all incorrect
        final results = List<bool>.filled(totalCues, false);
        final reactionTimes = <int>[
          12300, 12300, 14540, 13880, 12080, 13300, 14520, 14440,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Reading Comprehension Speed']!, closeTo(0.4, eps),
            reason:
            'All wrong at expected times: baseSpeed=1.0 × 0.4 = 0.4. Got ${out['Reading Comprehension Speed']}');
      });

      test('23. Extremely fast (under 5s) all correct → capped at 1.0', () {
        // Unrealistically fast but still correct
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          3000, 3500, 4000, 4500, 3000, 3500, 4000, 4500,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // baseSpeed should still cap at 1.0 even when rt << expected
        expect(out['Reading Comprehension Speed']!, closeTo(1.0, eps),
            reason:
            'Extremely fast correct should still cap at 1.0. Got ${out['Reading Comprehension Speed']}');
      });

      test('24. Mixed correctness at same speed → correctness affects score', () {
        // Same reaction times, different correctness
        final correctResults = List<bool>.filled(totalCues, true);
        final wrongResults = List<bool>.filled(totalCues, false);
        final reactionTimes = <int>[
          12000, 12000, 14000, 14000, 12000, 13000, 14000, 14000,
        ];

        final correct = callGrade(results: correctResults, reactionTimes: reactionTimes);
        final wrong = callGrade(results: wrongResults, reactionTimes: reactionTimes);

        // Correct should be ~2.5× higher than wrong (1.0 vs 0.4)
        expect(correct['Reading Comprehension Speed']!,
            greaterThan(wrong['Reading Comprehension Speed']! * 2.0),
            reason:
            'Same times, all correct should be much higher than all wrong. Correct: ${correct['Reading Comprehension Speed']}, Wrong: ${wrong['Reading Comprehension Speed']}');
      });

      test('25. Verify median behavior: 4 high, 4 low scores', () {
        // 4 rounds with score 1.0, 4 rounds with score 0.0
        final results = <bool>[
          true, true, true, true,
          true, true, true, true,
        ];
        final reactionTimes = <int>[
          8000, 8000, 9000, 9000,     // fast: score ~1.0
          25000, 25000, 25000, 25000, // timeout: score 0.0-0.28
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        // Center-average of 4 middle values should be high
        expect(out['Reading Comprehension Speed']!, closeTo(0.78, eps),
            reason:
            'Center-average of split scores should be high. Got ${out['Reading Comprehension Speed']}');
      });

      // =========================================================================
      // REALISTIC ARBITRARY SCENARIOS
      // =========================================================================

      test('26. Typical good player – mostly correct, some hesitation on hard ones', () {
        // Gets easier ones quickly, takes time on harder ones
        final results = <bool>[
          true,  true,  true,  false,  // prag: 3/4
          true,  true,  false, true,   // social: 3/4
        ];
        final reactionTimes = <int>[
          9000,  10000, 13000, 17000,  // pragmatic
          11000, 12000, 19000, 15000,  // social
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.75, eps),
            reason: 'Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.75, eps),
            reason: 'Got ${out['Social Context Awareness']}');
        expect(out['Reading Comprehension Speed']!, greaterThan(0.75),
            reason:
            'Good accuracy with reasonable times should score well. Got ${out['Reading Comprehension Speed']}');
      });

      test('27. Inconsistent performer – alternating fast/slow, right/wrong', () {
        // Unpredictable pattern simulating distraction or fatigue
        final results = <bool>[
          true,  false, true,  false,
          false, true,  true,  false,
        ];
        final reactionTimes = <int>[
          8000,  20000, 10000, 22000,
          18000, 11000, 9000,  24000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.4, 0.7),
            reason:
            'Inconsistent pattern should give mid-range. Got ${out['Reading Comprehension Speed']}');
      });

      test('28. Strong start, weak finish – fatigue pattern', () {
        // First 4 fast and correct, last 4 slow and wrong (fatigue/giving up)
        final results = <bool>[
          true,  true,  true,  true,
          false, false, true,  false,
        ];
        final reactionTimes = <int>[
          8000,  9000,  10000, 11000,
          21000, 23000, 19000, 24000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(1.0, eps),
            reason: 'All pragmatic correct. Got ${out['Pragmatics']}');
        expect(out['Social Context Awareness']!, closeTo(0.25, eps),
            reason: 'Only 1/4 social correct. Got ${out['Social Context Awareness']}');
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.5, 0.8),
            reason:
            'Mixed performance should reflect in median. Got ${out['Reading Comprehension Speed']}');
      });

      test('29. Near-perfect but cautious – all correct, mostly at expected time', () {
        // 100% accuracy, times cluster around expected with slight variation
        final results = List<bool>.filled(totalCues, true);
        final reactionTimes = <int>[
          13000, 12500, 15000, 14000,
          12500, 13500, 14800, 14200,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(1.0, eps));
        expect(out['Social Context Awareness']!, closeTo(1.0, eps));
        expect(out['Reading Comprehension Speed']!, greaterThan(0.9),
            reason:
            'All correct near expected times should be very high. Got ${out['Reading Comprehension Speed']}');
      });

      test('30. Struggling reader – low accuracy, varied times showing confusion', () {
        // Gets 2/8 correct, times all over the place
        final results = <bool>[
          false, true,  false, false,
          false, false, true,  false,
        ];
        final reactionTimes = <int>[
          16000, 11000, 23000, 18000,
          20000, 24000, 14000, 22000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.25, eps));
        expect(out['Social Context Awareness']!, closeTo(0.25, eps));
        expect(out['Reading Comprehension Speed']!, lessThan(0.4),
            reason:
            'Low accuracy with slow times should score low. Got ${out['Reading Comprehension Speed']}');
      });

      test('31. Rushed player – very fast across the board but makes mistakes', () {
        // Answers quickly (6-9s) but gets about half wrong
        final results = <bool>[
          true,  false, true,  true,
          false, true,  false, true,
        ];
        final reactionTimes = <int>[
          6000, 6500, 7000, 7500,
          8000, 8500, 9000, 9500,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.75, eps));
        expect(out['Social Context Awareness']!, closeTo(0.5, eps));
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.65, 0.85),
            reason:
            'Fast with decent accuracy should be good but not perfect. Got ${out['Reading Comprehension Speed']}');
      });

      test('32. Overthinking pattern – takes too long, but gets most right', () {
        // High accuracy (6/8) but consistently slow (18-23s)
        final results = <bool>[
          true,  true,  false, true,
          true,  true,  true,  false,
        ];
        final reactionTimes = <int>[
          18000, 19000, 23000, 20000,
          19000, 21000, 22000, 23000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.75, eps));
        expect(out['Social Context Awareness']!, closeTo(0.75, eps));
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.5, 0.7),
            reason:
            'Good accuracy but slow should give lower-mid speed. Got ${out['Reading Comprehension Speed']}');
      });

      test('33. Lucky guesser – fast random guessing with some hits', () {
        // Very fast (5-7s) with 3/8 correct by chance
        final results = <bool>[
          false, true,  false, false,
          true,  false, true,  false,
        ];
        final reactionTimes = <int>[
          5000, 5500, 6000, 6500,
          5000, 5500, 6000, 6500,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.25, eps));
        expect(out['Social Context Awareness']!, closeTo(0.5, eps));
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.45, 0.65),
            reason:
            'Very fast but low accuracy shows quick but poor processing. Got ${out['Reading Comprehension Speed']}');
      });

      test('34. Steady average performer – consistent moderate times, mostly correct', () {
        // Gets 6/8 correct with consistent 13-16s times
        final results = <bool>[
          true,  true,  false, true,
          true,  false, true,  true,
        ];
        final reactionTimes = <int>[
          13000, 14000, 15000, 14000,
          13000, 16000, 15000, 14000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.75, eps));
        expect(out['Social Context Awareness']!, closeTo(0.75, eps));
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.8, 0.96),
            reason:
            'Consistent good performance should score high. Got ${out['Reading Comprehension Speed']}');
      });

      test('35. Mixed bag – realistic scattered performance', () {
        // 5/8 correct with times ranging from fast to slow
        final results = <bool>[
          true,  false, true,  true,
          false, true,  false, true,
        ];
        final reactionTimes = <int>[
          9000,  21000, 12000, 15000,
          18000, 10000, 24000, 13000,
        ];

        final out = callGrade(results: results, reactionTimes: reactionTimes);

        expect(out['Pragmatics']!, closeTo(0.75, eps));
        expect(out['Social Context Awareness']!, closeTo(0.5, eps));
        expect(out['Reading Comprehension Speed']!, inInclusiveRange(0.55, 0.8),
            reason:
            'Mixed realistic performance should give mid-high range. Got ${out['Reading Comprehension Speed']}');
      });
    });
  });
}