class DerivedSkillEngine {
  static double clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  /// Computes derived skills from aggregated direct skills.
  /// Returns only derived skills (does NOT override direct ones).
  static Map<String, double?> derive(Map<String, double?> skills) {
    final Map<String, double?> derived = {};

    // -------------------------------
    // 🧠 Systems Thinking
    // -------------------------------
    // Emerges from planning + flexibility + constraint handling + pressure control
    derived["Systems Thinking"] = _composite(
      skills,
      [
        "Planning & Prioritization",
        "Constraint Management",
        "Cognitive Flexibility",
        "Decision Under Pressure",
      ],
      minEvidence: 3,
    );

    // -------------------------------
    // 🎨 Error Detection
    // -------------------------------
    // Emerges from accuracy control + inhibition + post-error recovery
    derived["Error Detection"] = _composite(
      skills,
      [
        "Response Inhibition",
        "Cognitive Flexibility",
        "Information Processing Speed",
      ],
      minEvidence: 2,
    );

    // -------------------------------
    // 🗣️ Sequencing / Narrative Logic (formal sequencing)
    // -------------------------------
    // Stepwise reasoning & ordered transformations
    derived["Sequencing / Narrative Logic"] = _composite(
      skills,
      [
        "Deductive Reasoning",
        "Inductive Reasoning",
        "Working Memory",
      ],
      minEvidence: 2,
    );

    // -------------------------------
    // ❤️ Conflict Resolution (abstract / executive)
    // -------------------------------
    // Resolving competing demands under pressure (NOT interpersonal)
    derived["Conflict Resolution"] = _composite(
      skills,
      [
        "Response Inhibition",
        "Decision Under Pressure",
        "Cognitive Flexibility",
      ],
      minEvidence: 2,
    );

    return derived;
  }

  /// Helper: averages available skills if enough evidence exists.
  static double? _composite(
      Map<String, double?> skills,
      List<String> required,
      {int minEvidence = 2}
      ) {
    final values = <double>[];

    for (final key in required) {
      final v = skills[key];
      if (v != null) values.add(v);
    }

    if (values.length < minEvidence) return null;

    final avg = values.reduce((a, b) => a + b) / values.length;
    return clamp01(avg);
  }
}
