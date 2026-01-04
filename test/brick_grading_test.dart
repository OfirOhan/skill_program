import 'package:flutter_test/flutter_test.dart';
import '../lib/grading/brick_grading.dart';

void main() {
  // We want tight expectations: ±0.05
  const double eps = 0.05;

  // --- Helper for cleaner calls ---
  Future<Map<String, double>> grade({
    required List<String> ideas,
    String? selectedBest,
    int duration = 45,
    int usedTimeMs = 45000,
    int decisionTimeMs = 2000,
  }) async {
    final selectedIndex =
    selectedBest != null ? ideas.indexOf(selectedBest) : -1;

    return BrickGrading.grade(
      ideas: ideas,
      divergentDuration: duration,
      divergentUsedMs: usedTimeMs,
      convergentChosen: selectedIndex != -1,
      selectedOptionIndex: selectedIndex,
      convergentDecisionMs: decisionTimeMs,
      convergentDuration: 10,
    );
  }

  group('BrickGrading – Spec-based behavioral tests', () {
  //   // =========================================================
  //   // 0. BASELINE: NO IDEAS → everything must be exactly 0
  //   // =========================================================
  //   test('No ideas → all scores zero', () async {
  //     final result = await grade(ideas: []);
  //
  //     expect(result['Ideation Fluency'], equals(0.0));
  //     expect(result['Divergent Thinking'], equals(0.0));
  //     expect(result['Planning & Prioritization'], equals(0.0));
  //   });
  //
  //   // =========================================================
  //   // 1. PURE GIBBERISH SPAM
  //   // We expect Gemini to treat these as nonsense (creativity ~ 0.0),
  //   // so no plausible ideas => all scores ~ 0.
  //   // =========================================================
  //   test('Gibberish spam → almost zero everywhere', () async {
  //     final ideas = ["asdfgh", "qwrty", "zxcvb", "plmnb", "qzxsw"];
  //
  //     final result = await grade(ideas: ideas, selectedBest: "asdfgh");
  //
  //     print('Gibberish => $result');
  //
  //     expect(result['Ideation Fluency']!, closeTo(0.0, eps));
  //     expect(result['Divergent Thinking']!, closeTo(0.0, eps));
  //     expect(result['Planning & Prioritization']!, closeTo(0.0, eps));
  //   });

    // =========================================================
    // 2. SINGLE STRONG IDEA – SLOW THINKER
    //
    // Assumption: creativity ≈ 0.9
    // usedTime = full 45s → targetIdeas = 5
    // nValid = 1 → rawFluency ≈ 0.2, engagement ≈ 0.33
    //
    // Expected (from math):
    //   Fluency ≈ 0.48
    //   Divergent ≈ 0.50
    //   Planning ≈ 0.33
    // =========================================================
    test('Single strong idea, slow thinker (quality over quantity)', () async {
      final ideas = [
        "use as a heat sink mounted behind a solar panel",
      ];

      final result = await grade(
        ideas: ideas,
        selectedBest: ideas[0],
        usedTimeMs: 45000, // full time
      );

      print('Single strong (slow) => $result');

      expect(result['Ideation Fluency']!, closeTo(0.48, eps));
      expect(result['Divergent Thinking']!, closeTo(0.50, eps));
      expect(result['Planning & Prioritization']!, closeTo(0.33, eps));
    });

    // =========================================================
    // 3. SINGLE STRONG IDEA – FAST THINKER
    //
    // Same idea, but submitted in ~15s.
    // usedTime = 15s → targetIdeas ≈ 1.67 → rawFluency ≈ 0.6
    // Divergent & Planning unchanged (they don't depend on time).
    //
    // Expected:
    //   Fluency ≈ 0.61
    //   Divergent ≈ 0.50
    //   Planning ≈ 0.33
    //   Fluency_fast > Fluency_slow by at least ~0.1
    // =========================================================
    test('Single strong idea – fast vs slow fluency comparison', () async {
      final ideas = [
        "use as a heat sink mounted behind a solar panel",
      ];

      final slow = await grade(
        ideas: ideas,
        selectedBest: ideas[0],
        usedTimeMs: 45000,
      );
      final fast = await grade(
        ideas: ideas,
        selectedBest: ideas[0],
        usedTimeMs: 15000,
      );

      final slowFlu = slow['Ideation Fluency']!;
      final fastFlu = fast['Ideation Fluency']!;

      print('Single strong (slow) => $slow');
      print('Single strong (fast) => $fast');

      expect(slowFlu, closeTo(0.48, eps));
      expect(fastFlu, closeTo(0.61, eps));
      expect(fastFlu, greaterThan(slowFlu + 0.10));

      // Divergent and Planning should stay essentially the same.
      final diffDiv =
      (slow['Divergent Thinking']! - fast['Divergent Thinking']!).abs();
      final diffPlan = (slow['Planning & Prioritization']! -
          fast['Planning & Prioritization']!)
          .abs();

      expect(diffDiv, lessThan(0.05));
      expect(diffPlan, lessThan(0.05));
    });

    // =========================================================
    // 4. CREATIVE GENIUS vs BORING BUILDER
    //
    // Our mental spec (assuming Gemini roughly follows prompt):
    //  Genius ideas ~ [0.9, 0.8, 0.8, 0.85, 0.75]
    //    => Flu ≈ 0.97, Div ≈ 0.97, Plan ≈ 1.0
    //  Boring ideas ~ all ≈ 0.3
    //    => Flu ≈ 0.77, Div ≈ 0.59, Plan ≈ 1.0
    //
    // Note: Planning is perfect for both because they pick their best idea.
    // =========================================================
    test('Creative Genius vs Boring Builder', () async {
      final geniusIdeas = [
        "crush into red pigment for artists",
        "use as thermal mass behind a sun-facing window",
        "carve into a garden statue base",
        "grind to powder for textured makeup or paint pigment",
        "anchor a small fishing boat in shallow water",
      ];

      final boringIdeas = [
        "build a wall",
        "build a house",
        "doorstop",
        "paperweight",
        "hold a door open",
      ];

      final genius = await grade(
        ideas: geniusIdeas,
        selectedBest: "crush into red pigment for artists",
      );
      final boring = await grade(
        ideas: boringIdeas,
        selectedBest: "build a wall",
      );

      print("Genius => $genius");
      print("Boring => $boring");

      final gFlu = genius['Ideation Fluency']!;
      final gDiv = genius['Divergent Thinking']!;
      final gPlan = genius['Planning & Prioritization']!;

      final bFlu = boring['Ideation Fluency']!;
      final bDiv = boring['Divergent Thinking']!;
      final bPlan = boring['Planning & Prioritization']!;

      // Expected numeric targets
      const gFluExp = 0.97;
      const gDivExp = 0.97;
      const gPlanExp = 1.00;

      const bFluExp = 0.77;
      const bDivExp = 0.59;
      const bPlanExp = 1.00;

      expect(gFlu, closeTo(gFluExp, eps));
      expect(gDiv, closeTo(gDivExp, eps));
      expect(gPlan, closeTo(gPlanExp, eps));

      expect(bFlu, closeTo(bFluExp, eps));
      expect(bDiv, closeTo(bDivExp, eps));
      expect(bPlan, closeTo(bPlanExp, eps));

      // Relational sanity: Genius clearly beats Boring
      expect(gDiv, greaterThan(bDiv + 0.2));
      expect(gFlu, greaterThan(bFlu + 0.15));
    });

    // =========================================================
    // 5. ABOVE-AVERAGE HUMAN: 2 clichés + 1 creative
    //
    // Approx creativity: [0.3, 0.3, 0.7]
    // => Flu ≈ 0.77, Div ≈ 0.78, Plan ≈ 1.0
    //
    // This is the "I’m a bit more creative than average" target.
    // =========================================================
    test('Above-average human: two clichés + one strong creative', () async {
      final ideas = [
        "build a wall",                                // cliché
        "use as a simple doorstop",                    // cliché
        "grind into pigment for handcrafted cosmetics" // creative
      ];

      final result = await grade(
        ideas: ideas,
        selectedBest: "grind into pigment for handcrafted cosmetics",
      );

      print("Above-average => $result");

      expect(result['Ideation Fluency']!, closeTo(0.77, eps));
      expect(result['Divergent Thinking']!, closeTo(0.78, eps));
      expect(result['Planning & Prioritization']!, closeTo(1.0, eps));
    });

    // =========================================================
    // 6. ENGAGEMENT: 2 ideas vs 4 plausible ideas (same style)
    //
    // Approx creativity per idea ≈ 0.5
    // For 2 ideas:  Flu ≈ 0.52, Div ≈ 0.62, Plan ≈ 0.67
    // For 4 ideas:  Flu ≈ 0.77, Div ≈ 0.85, Plan ≈ 1.00
    // =========================================================
    test('Engagement: more plausible ideas => higher scores', () async {
      final twoIdeas = [
        "use as a garden border around flower beds",
        "stack bricks to make a low outdoor bench",
      ];

      final fourIdeas = [
        ...twoIdeas,
        "line the edge of a small pond with bricks",
        "build a short step leading up to a porch",
      ];

      final lowEng = await grade(
        ideas: twoIdeas,
        selectedBest: twoIdeas[0],
      );

      final highEng = await grade(
        ideas: fourIdeas,
        selectedBest: fourIdeas[0],
      );

      print("2-idea engagement => $lowEng");
      print("4-idea engagement => $highEng");

      final lowFlu = lowEng['Ideation Fluency']!;
      final highFlu = highEng['Ideation Fluency']!;
      final lowDiv = lowEng['Divergent Thinking']!;
      final highDiv = highEng['Divergent Thinking']!;
      final lowPlan = lowEng['Planning & Prioritization']!;
      final highPlan = highEng['Planning & Prioritization']!;

      // Numeric expectations
      expect(lowFlu, closeTo(0.52, eps));
      expect(lowDiv, closeTo(0.62, eps));
      expect(lowPlan, closeTo(0.67, eps));

      expect(highFlu, closeTo(0.77, eps));
      expect(highDiv, closeTo(0.85, eps));
      expect(highPlan, closeTo(1.00, eps));

      // And relationally, 4 ideas should clearly beat 2
      expect(highFlu, greaterThan(lowFlu + 0.10));
      expect(highDiv, greaterThan(lowDiv + 0.10));
      expect(highPlan, greaterThan(lowPlan - eps)); // at least not worse
    });

    // =========================================================
    // 7. GOOD PLANNER vs BAD PLANNER – same ideas
    //
    // Approx creativity: [0.3 (doorstop), 0.9 (cosmic dust art)]
    //
    // Good picks the strong idea:
    //   Plan ≈ 0.67
    // Bad picks the boring idea:
    //   Plan ≈ 0.22
    //
    // Fluency & Divergent should be identical (same idea set).
    // =========================================================
    test('Good planner vs bad planner', () async {
      final ideas = [
        "doorstop",                                     // cliché
        "ground into cosmic dust art for installations" // very creative
      ];

      final good = await grade(
        ideas: ideas,
        selectedBest: ideas[1],
      );

      final bad = await grade(
        ideas: ideas,
        selectedBest: ideas[0],
      );

      print("Good planner => $good");
      print("Bad planner  => $bad");

      final goodPlan = good['Planning & Prioritization']!;
      final badPlan = bad['Planning & Prioritization']!;

      // Numeric targets
      expect(goodPlan, closeTo(0.67, eps));
      expect(badPlan, closeTo(0.22, eps));
      expect(goodPlan, greaterThan(badPlan + 0.10));

      // Divergent & Fluency should be almost identical
      final diffFlu =
      (good['Ideation Fluency']! - bad['Ideation Fluency']!).abs();
      final diffDiv =
      (good['Divergent Thinking']! - bad['Divergent Thinking']!).abs();

      expect(diffFlu, lessThan(0.05));
      expect(diffDiv, lessThan(0.05));
    });

    // =========================================================
    // 8. DISTINCT strong ideas vs DUPLICATED strong idea
    //
    // Distinct (3 clusters, all high):
    //   creativity ~ [0.9, 0.8, 0.8]
    //   => Flu ≈ 0.83, Div ≈ 0.97
    //
    // Duplicated (same idea 3x; one conceptual cluster):
    //   effectively clusterScores ≈ [0.9]
    //   => Flu ≈ 0.83, Div ≈ 0.84
    //
    // We expect: same Fluency, but Divergent significantly lower
    // when the user just repeats the same idea.
    // =========================================================
    test('Distinct concepts > duplicated concept for Divergent Thinking',
            () async {
          final distinctIdeas = [
            "crush into red pigment for artists",
            "use as thermal mass behind a wood stove",
            "anchor a small fishing boat in shallow water",
          ];

          final duplicatedIdeas = [
            "crush into red pigment for artists",
            "crush into red pigment for artists",
            "crush into red pigment for artists",
          ];

          final distinct = await grade(
            ideas: distinctIdeas,
            selectedBest: distinctIdeas[0],
          );

          final dup = await grade(
            ideas: duplicatedIdeas,
            selectedBest: duplicatedIdeas[0],
          );

          print("Distinct concepts => $distinct");
          print("Duplicated concept => $dup");

          final dFlu = distinct['Ideation Fluency']!;
          final dDiv = distinct['Divergent Thinking']!;
          final uFlu = dup['Ideation Fluency']!;
          final uDiv = dup['Divergent Thinking']!;

          // Numeric targets
          expect(dFlu, closeTo(0.83, eps));
          expect(uFlu, closeTo(0.83, eps));

          expect(dDiv, closeTo(0.97, eps));
          expect(uDiv, closeTo(0.84, eps));

          // Distinct must clearly beat duplicated by at least 0.1 in Divergent
          expect(dDiv, greaterThan(uDiv + 0.10));
        });

    // =========================================================
    // 9. TYPO ROBUSTNESS – “buld a wall” vs “build a wall”
    //
    // We expect Gemini canonicalization to treat small spelling errors
    // almost identically, so the *scores* should be very close.
    // =========================================================
    test('Minor spelling mistakes should not kill the scores', () async {
      final cleanIdeas = [
        "build a wall",
        "use as a doorstop",
        "grind into pigment for paint",
      ];

      final typoIdeas = [
        "buld a wall", // typo
        "use as a doorstop",
        "grind into pigment for paint",
      ];

      final clean = await grade(
        ideas: cleanIdeas,
        selectedBest: "grind into pigment for paint",
      );

      final typo = await grade(
        ideas: typoIdeas,
        selectedBest: "grind into pigment for paint",
      );

      print("Clean ideas => $clean");
      print("Typo ideas  => $typo");

      // All three scores should be very close between clean vs typo.
      for (final key in [
        "Ideation Fluency",
        "Divergent Thinking",
        "Planning & Prioritization",
      ]) {
        final diff = (clean[key]! - typo[key]!).abs();
        expect(diff, lessThan(0.05),
            reason: "$key differs too much between clean and typo");
      }
    });
  });
}
