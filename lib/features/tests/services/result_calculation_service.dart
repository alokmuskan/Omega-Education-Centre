/// Centralized service for Test Result Calculations, Grading Policy, Pass/Fail Rules,
/// and Competition Ranking.
class ResultCalculationService {
  ResultCalculationService._();

  /// Computes percentage: (totalObtained / totalMax) × 100
  static double computePercentage({
    required double totalObtained,
    required double totalMax,
  }) {
    if (totalMax <= 0) return 0.0;
    final pct = (totalObtained / totalMax) * 100.0;
    return (pct * 100).roundToDouble() / 100.0;
  }

  /// Centralized Grading Policy:
  /// 90% – 100% -> A+
  /// 80% – 89.99% -> A
  /// 70% – 79.99% -> B+
  /// 60% – 69.99% -> B
  /// 50% – 59.99% -> C
  /// 40% – 49.99% -> D
  /// Below 40% -> F
  static String computeGrade(double percentage) {
    if (percentage >= 90.0) return 'A+';
    if (percentage >= 80.0) return 'A';
    if (percentage >= 70.0) return 'B+';
    if (percentage >= 60.0) return 'B';
    if (percentage >= 50.0) return 'C';
    if (percentage >= 40.0) return 'D';
    return 'F';
  }

  /// Subject level pass check: marksObtained >= passMarks
  static bool isSubjectPassed({
    required double marksObtained,
    required double passMarks,
  }) {
    return marksObtained >= passMarks;
  }

  /// Overall status: 'Pass' | 'Fail' | 'Incomplete'
  static String computeOverallStatus({
    required List<bool> subjectPassResults,
    required int totalSubjectsConfigured,
  }) {
    if (totalSubjectsConfigured <= 0) return 'Incomplete';
    if (subjectPassResults.length < totalSubjectsConfigured) return 'Incomplete';
    if (subjectPassResults.every((passed) => passed)) return 'Pass';
    return 'Fail';
  }

  /// Assigns Standard Competition Ranks (1, 1, 3 ranking rule) to a list of student results.
  ///
  /// Complete results with identical percentages receive the same rank,
  /// and the subsequent rank skips accordingly. Incomplete results receive rank = 0 (unranked).
  static Map<int, int> computeCompetitionRanks({
    required Map<int, double> studentIdToPercentage,
    required Map<int, bool> studentIdToIsComplete,
  }) {
    final rankMap = <int, int>{};

    // Filter only complete results
    final completeEntries = studentIdToPercentage.entries
        .where((e) => studentIdToIsComplete[e.key] ?? false)
        .toList();

    // Sort descending by percentage
    completeEntries.sort((a, b) => b.value.compareTo(a.value));

    int currentRank = 1;
    for (int i = 0; i < completeEntries.length; i++) {
      final entry = completeEntries[i];
      if (i > 0 && entry.value == completeEntries[i - 1].value) {
        // Tie with previous student -> get same rank
        rankMap[entry.key] = rankMap[completeEntries[i - 1].key]!;
      } else {
        currentRank = i + 1; // Standard competition rank (1, 1, 3)
        rankMap[entry.key] = currentRank;
      }
    }

    // Set 0 for incomplete students
    for (final id in studentIdToPercentage.keys) {
      if (!rankMap.containsKey(id)) {
        rankMap[id] = 0;
      }
    }

    return rankMap;
  }
}
