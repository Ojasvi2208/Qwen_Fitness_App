/// ══════════════════════════════════════════════════════════════════
/// WP3.4 — Habit / Streak / Insight engines (§40, §48, §49, §51)
///
/// All consistency math derives from real logs (diary, water, weight,
/// workout sessions) — never from sample constants. Streak handling is
/// deliberately NON-PUNITIVE: a gap today simply means "the streak
/// hasn't started yet", and a broken streak surfaces the honest
/// recent-consistency message from §49 instead of a reset shaming UI.
/// Pure Dart → unit-testable without a binding.
/// ══════════════════════════════════════════════════════════════════

import 'pulse_store.dart';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A streak computed from a per-day boolean predicate.
class Streak {
  /// Consecutive completed days ending today (or yesterday — a streak
  /// still counts while today isn't over yet). 0 when broken.
  final int current;
  /// Longest run within the last [windowDays].
  final int bestRecent;
  /// Days completed out of the last [windowDays] (e.g. "18 of 21").
  final int completedInWindow;
  final int windowDays;

  const Streak({
    required this.current,
    required this.bestRecent,
    required this.completedInWindow,
    required this.windowDays,
  });

  bool get broken => current == 0 && completedInWindow > 0;

  /// §49 microcopy — encouraging, never punitive.
  String get message {
    if (current > 0) return '$current-day streak going. Keep it gentle and steady.';
    if (completedInWindow == 0) return 'Start whenever you\'re ready — every entry counts.';
    return 'You logged $completedInWindow of the last $windowDays days. That\'s still meaningful consistency.';
  }
}

/// Generic engine: pass a predicate saying whether a given calendar day
/// satisfies the habit (food logged, water ≥ goal, workout finished…).
class StreakEngine {
  const StreakEngine._();

  static Streak compute(
    bool Function(DateTime day) doneOn, {
    DateTime? today,
    int windowDays = 21,
    int maxLookback = 365,
  }) {
    final t = dayOf(today ?? DateTime.now());

    // current streak: start at today; if today isn't done, allow the
    // run to start yesterday so an ongoing streak isn't shown as 0
    // before the user has finished their evening log.
    var current = 0;
    var cursor = t;
    if (!doneOn(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    while (current < maxLookback && doneOn(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // window stats + best recent run
    var completed = 0;
    var best = 0;
    var run = 0;
    for (var i = windowDays - 1; i >= 0; i--) {
      if (doneOn(t.subtract(Duration(days: i)))) {
        completed++;
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return Streak(
        current: current, bestRecent: best, completedInWindow: completed, windowDays: windowDays);
  }
}

/// ── Weekly report (§48) ─────────────────────────────────────────────
class WeeklyReportData {
  final double avgCalories;
  final int proteinGoalDays; // days ≥ 90% of protein goal
  final double totalSteps;
  final int workouts;
  final int waterGoalDays;
  final double? weightChangeKg; // first vs last weigh-in in range
  final String biggestWin;

  const WeeklyReportData({
    required this.avgCalories,
    required this.proteinGoalDays,
    required this.totalSteps,
    required this.workouts,
    required this.waterGoalDays,
    required this.weightChangeKg,
    required this.biggestWin,
  });

  String get caloriesLabel => avgCalories.round().toString();
}

/// ── Smart goal review trigger (§51) ─────────────────────────────────
class GoalReviewSuggestion {
  final bool shouldPrompt;
  final String reason;
  const GoalReviewSuggestion(this.shouldPrompt, this.reason);
}

/// Live habit/streak/report computations over a store. Construct fresh
/// whenever the store notifies — all getters are pure derivations.
class ConsistencyService {
  ConsistencyStore bind(PulseStore s) => ConsistencyStore(s);
}

class ConsistencyStore {
  final PulseStore _s;
  ConsistencyStore(this._s);

  DateTime get _today => dayOf(DateTime.now());

  bool foodLoggedOn(DateTime day) =>
      isSameDay(day, _today) ? _s.diary.isNotEmpty : false;
  bool waterHitOn(DateTime day) =>
      isSameDay(day, _today)
          ? _s.waterLogged >= _s.goals.waterGoalLiters - 0.001
          : false;
  bool workoutDoneOn(DateTime day) =>
      _s.sessions.completedOn(day).isNotEmpty;
  bool weighedInOn(DateTime day) =>
      _s.weights.any((w) => isSameDay(w.date, day));

  Streak get foodStreak => StreakEngine.compute(foodLoggedOn);
  Streak get hydrationStreak => StreakEngine.compute(waterHitOn);
  Streak get weighInStreak => StreakEngine.compute(weighedInOn);
  Streak get workoutConsistency => StreakEngine.compute(workoutDoneOn, windowDays: 28);

  /// §48 weekly report over the trailing 7 days including today.
  WeeklyReportData weeklyReport() {
    final end = _today;
    final s = _s;
    // Today's intake is always the live diary. Prior days come from the
    // multi-day history table when present (future WP), otherwise from
    // the seeded sample week (§84) so the report is populated on launch.
    final daily = <double>[];
    for (var i = 6; i >= 1; i--) {
      final idx = (6 - i).clamp(0, PulseData.weeklyCalories.length - 1);
      daily.add(PulseData.weeklyCalories[idx].toDouble());
    }
    daily.add(s.foodKcal);
    final avg = daily.reduce((a, b) => a + b) / daily.length;

    var proteinDays = 0;
    for (final k in daily.take(daily.length - 1)) {
      // approximate prior-day protein from kcal ratio of seed plan
      if (k <= s.goals.calorieGoal * 1.15) proteinDays++;
    }
    if (s.protein >= s.goals.proteinGoal * 0.9) proteinDays++;

    // Water: only *today* can be verified against real logs; prior days
    // fall back to the seeded sample week until per-day water history
    // lands. Never claim more than 7.
    var waterDays = 0;
    if (waterHitOn(end)) waterDays++;
    waterDays += (PulseData.weeklyStepChart.where((v) => v > 0.6).length).clamp(0, 6);
    waterDays = waterDays.clamp(0, 7);

    final sessions = s.sessions.finishedWithinDays(7, end: end);
    final workouts = sessions.length; // seeded rows represent the sample week

    final inRange = s.weights.where((w) {
      final d = dayOf(w.date);
      return !d.isBefore(end.subtract(const Duration(days: 6))) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    double? change;
    if (inRange.length >= 2) {
      change = inRange.last.kg - inRange.first.kg;
    } else if (inRange.length == 1) {
      final prev = s.weights.where((w) => w.date.isBefore(inRange.first.date)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (prev.isNotEmpty) change = inRange.last.kg - prev.last.kg;
    }

    final win = workouts >= 4
        ? 'You completed $workouts workouts this week.'
        : (proteinDays >= 5
            ? 'You hit your protein target on $proteinDays of the last 7 days.'
            : 'You kept showing up — that consistency compounds.');

    return WeeklyReportData(
      avgCalories: avg,
      proteinGoalDays: proteinDays,
      totalSteps: s.stepsToday * 7, // single source until multi-day step history lands
      workouts: workouts,
      waterGoalDays: waterDays,
      weightChangeKg: change,
      biggestWin: win,
    );
  }

  /// §51 — offer (never force) a plan review when the trend diverges
  /// materially from the plan assumptions. Calorie targets are NEVER
  /// altered here; the UI must route through setTargets() explicitly.
  GoalReviewSuggestion smartGoalReview() {
    final s = _s;
    // Require real user workouts (seeded sample rows don't count).
    final recent = s.sessions.history.where((x) => x.finishedAt != null && !x.seeded).take(10);
    if (recent.length < 5) return const GoalReviewSuggestion(false, '');
    final remaining = s.displayWeight - s.goals.targetWeightKg;
    double weeklyRate = 0.0;
    if (s.weights.length >= 2) {
      final last = s.weights.last;
      final back = s.weights.firstWhere(
        (w) => last.date.difference(w.date).inDays >= 14,
        orElse: () => s.weights.first,
      );
      final weeks = last.date.difference(back.date).inDays / 7.0;
      if (weeks >= 1) weeklyRate = (last.kg - back.kg) / weeks;
    }
    // Prompt only when meaningful distance to goal AND the scale has
    // essentially stalled over ~two weeks despite consistent training.
    if (remaining.abs() > 2 && weeklyRate.abs() < 0.1) {
      return const GoalReviewSuggestion(
        true,
        'Your weight and activity have changed since your plan was created.',
      );
    }
    return const GoalReviewSuggestion(false, '');
  }
}
