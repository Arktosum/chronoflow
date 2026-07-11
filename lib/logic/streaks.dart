/// Flexible, forgiving streaks: "never miss twice".
///
/// Walking back from today, a single missed day dents the flame but the
/// streak survives — only two consecutive missed days break it.
class StreakInfo {
  /// Number of check-in days in the current living streak.
  final int streakDays;

  /// True when yesterday was missed and today is still unchecked —
  /// the flame is dim and one more miss kills it.
  final bool isDimmed;

  final bool checkedToday;

  const StreakInfo({
    required this.streakDays,
    required this.isDimmed,
    required this.checkedToday,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Check-ins per calendar day.
Map<DateTime, int> countByDay(List<DateTime> checkIns) {
  final counts = <DateTime, int>{};
  for (final c in checkIns) {
    final day = _dateOnly(c);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

/// Days that met the habit's daily target ("eat well 3×" needs 3 check-ins
/// before the day counts toward the streak).
List<DateTime> qualifyingDays(List<DateTime> checkIns, int dailyTarget) {
  return countByDay(checkIns)
      .entries
      .where((e) => e.value >= dailyTarget)
      .map((e) => e.key)
      .toList();
}

/// [checkInDays] may contain duplicates and any order.
StreakInfo computeStreak(List<DateTime> checkInDays, DateTime now) {
  final days = checkInDays.map(_dateOnly).toSet().toList()
    ..sort((a, b) => b.compareTo(a)); // newest first
  final today = _dateOnly(now);

  if (days.isEmpty) {
    return const StreakInfo(streakDays: 0, isDimmed: false, checkedToday: false);
  }

  final checkedToday = days.first == today;
  final gapToLatest = today.difference(days.first).inDays;

  // Two or more full missed days since the last check-in: streak is dead.
  if (gapToLatest >= 2) {
    return StreakInfo(streakDays: 0, isDimmed: false, checkedToday: false);
  }

  var streak = 1;
  for (var i = 0; i < days.length - 1; i++) {
    final gap = days[i].difference(days[i + 1]).inDays;
    if (gap <= 2) {
      // gap of 1 = consecutive, gap of 2 = one missed day (forgiven)
      streak++;
    } else {
      break;
    }
  }

  return StreakInfo(
    streakDays: streak,
    isDimmed: gapToLatest == 1, // yesterday missed, today not yet checked
    checkedToday: checkedToday,
  );
}
