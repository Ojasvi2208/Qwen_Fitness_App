import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════════
/// WP3.1 — Workout Session Engine (pure Dart, zero Flutter deps so it
/// is unit-testable without a binding). A session is the single source
/// of truth for the Active Workout → Workout Complete flow (§34–§37):
/// every completed set is recorded here, and all summary stats
/// (duration, sets, volume, estimated kcal) are DERIVED from records —
/// never hardcoded in widgets.
/// ═══════════════════════════════════════════════════════════════════

enum Difficulty { beginner, intermediate, advanced }

extension DifficultyName on Difficulty {
  String get label => switch (this) {
        Difficulty.beginner => 'Beginner',
        Difficulty.intermediate => 'Intermediate',
        Difficulty.advanced => 'Advanced',
      };

  static Difficulty parse(String? s) => switch (s) {
        'Beginner' => Difficulty.beginner,
        'Advanced' => Difficulty.advanced,
        _ => Difficulty.intermediate,
      };
}

/// Static catalog entry (app data — not persisted per user).
class WorkoutTemplate {
  final String name;
  final int minutes; // planned duration
  final Difficulty level;
  final String category;
  final List<String> equipment;
  const WorkoutTemplate({
    required this.name,
    required this.minutes,
    required this.level,
    required this.category,
    this.equipment = const [],
  });

  /// Planned exercise list for this template. Currently the app ships
  /// one full routine (Upper Body Strength, §34); other templates use
  /// the first N exercises as their plan.
  List<ExercisePlan> get plan => WorkoutTemplates.planFor(this);
}

/// One prescribed exercise inside a template.
class ExercisePlan {
  final String name;
  final int targetSets;
  final int? targetReps; // null = AMRAP (as-many-reps-as-possible)
  final String muscle;
  const ExercisePlan(this.name, this.targetSets, this.targetReps, this.muscle);

  String get setsLabel =>
      targetReps == null ? '$targetSets × AMRAP' : '$targetSets × $targetReps';
}

/// Catalog shared by Train home, library and detail screens.
class WorkoutTemplates {
  const WorkoutTemplates._();

  static const upperBodyPlan = <ExercisePlan>[
    ExercisePlan('Dumbbell Bench Press', 4, 10, 'Chest'),
    ExercisePlan('Shoulder Press', 3, 10, 'Shoulders'),
    ExercisePlan('One-Arm Row', 4, 12, 'Back'),
    ExercisePlan('Lateral Raise', 3, 15, 'Shoulders'),
    ExercisePlan('Biceps Curl', 3, 12, 'Arms'),
    ExercisePlan('Triceps Extension', 3, 12, 'Arms'),
    ExercisePlan('Push-Up Finisher', 2, null, 'Chest'),
    ExercisePlan('Face Pull', 3, 15, 'Shoulders'),
  ];

  static const library = <WorkoutTemplate>[
    WorkoutTemplate(name: 'Upper Body Strength', minutes: 45, level: Difficulty.intermediate, category: 'Strength', equipment: ['Dumbbells', 'Bench']),
    WorkoutTemplate(name: 'Full Body Strength', minutes: 45, level: Difficulty.intermediate, category: 'Strength', equipment: ['Barbell', 'Bench']),
    WorkoutTemplate(name: 'Morning Mobility', minutes: 12, level: Difficulty.beginner, category: 'Mobility', equipment: ['None']),
    WorkoutTemplate(name: 'HIIT Burn', minutes: 20, level: Difficulty.advanced, category: 'HIIT', equipment: ['None']),
    WorkoutTemplate(name: 'Upper Body Push', minutes: 35, level: Difficulty.intermediate, category: 'Strength', equipment: ['Dumbbells']),
    WorkoutTemplate(name: 'Restorative Yoga', minutes: 25, level: Difficulty.beginner, category: 'Yoga', equipment: ['Mat']),
    WorkoutTemplate(name: 'Core Circuit', minutes: 18, level: Difficulty.beginner, category: 'Strength', equipment: ['Mat']),
    WorkoutTemplate(name: 'Tempo Run Intervals', minutes: 32, level: Difficulty.advanced, category: 'Cardio', equipment: ['None']),
  ];

  static WorkoutTemplate byName(String name, {WorkoutTemplate? fallback}) =>
      library.firstWhere((w) => w.name == name,
          orElse: () => fallback ?? library[0]);

  static List<ExercisePlan> planFor(WorkoutTemplate w) =>
      List.unmodifiable(upperBodyPlan.take(w.name == 'Upper Body Strength'
          ? upperBodyPlan.length
          : w.exerciseCount));

  /// Estimated kcal shown on detail cards before a real session exists.
  static int estimateKcal(WorkoutTemplate w) => (w.minutes * 6.2).round();
}

extension _TemplateCount on WorkoutTemplate {
  int get exerciseCount => switch (category) {
        'Mobility' || 'Yoga' => 6,
        'Cardio' => 1,
        'HIIT' => 7,
        _ => name.contains('Push') ? 6 : (name.contains('Core') ? 6 : 9),
      };
}

/// ── Live/completed session record ──────────────────────────────────

/// One performed set. `exerciseIndex` maps into [WorkoutSession.plan].
class SetRecord {
  final int exerciseIndex;
  final int setNumber; // 1-based within that exercise
  final int reps;
  final double weightKg; // 0 for bodyweight moves
  final DateTime completedAt;
  const SetRecord({
    required this.exerciseIndex,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    required this.completedAt,
  });

  double get volumeKg => reps * weightKg;

  Map<String, dynamic> toJson() => {
        'ex': exerciseIndex,
        'set': setNumber,
        'reps': reps,
        'kg': weightKg,
        'at': completedAt.toIso8601String(),
      };

  static SetRecord fromJson(Map<String, dynamic> j) => SetRecord(
        exerciseIndex: (j['ex'] as num).toInt(),
        setNumber: (j['set'] as num).toInt(),
        reps: (j['reps'] as num).toInt(),
        weightKg: (j['kg'] as num).toDouble(),
        completedAt: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
      );
}

enum SessionStatus { active, finished }

/// A workout session bound to a template. All derived stats come from
/// [sets] + timestamps — safe to persist and restore mid-workout.
class WorkoutSession {
  final String id;
  final String templateName;
  final DateTime startedAt;
  final List<SetRecord> sets;
  DateTime? finishedAt;
  int? rating; // 0 too easy · 1 just right · 2 too hard (§37)

  /// WP3.4 — true only for sample-history rows seeded on first launch.
  /// Seeded rows carry fixed wall-clock dates so charts stay populated,
  /// but they must never leak into *today's* derived counters (workouts
  /// completed today, streaks). User-completed sessions are always false.
  final bool seeded;

  WorkoutSession({
    required this.id,
    required this.templateName,
    required this.startedAt,
    List<SetRecord>? sets,
    this.finishedAt,
    this.rating,
    this.seeded = false,
  }) : sets = sets ?? [];

  SessionStatus get status => finishedAt == null ? SessionStatus.active : SessionStatus.finished;

  /// Total elapsed minutes (capped at finish time once complete).
  Duration get elapsed {
    final end = finishedAt ?? DateTime.now();
    final d = end.difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  int get durationMinutes => (elapsed.inSeconds / 60).round().clamp(0, 600);

  int get totalSets => sets.length;

  /// Distinct exercises with ≥1 completed set.
  int get exercisesCompleted => sets.map((s) => s.exerciseIndex).toSet().length;

  double get volumeKg => sets.fold(0.0, (a, s) => a + s.volumeKg);

  /// MET-style estimate: 6.2 kcal/min baseline, ±12% per difficulty
  /// step, scaled by actual-vs-planned duration. Deterministic and
  /// labeled "Estimated" everywhere it is shown.
  int get estimatedKcal {
    final level = WorkoutTemplates.byName(templateName).level;
    final perMin = switch (level) {
      Difficulty.beginner => 5.4,
      Difficulty.intermediate => 6.2,
      Difficulty.advanced => 7.4,
    };
    final est = (elapsed.inSeconds / 60 * perMin).round();
    // Floor at 1 kcal once any set is logged: work was done even if the
    // session was finished in the same tick it started.
    return est.clamp(sets.isEmpty ? 0 : 1, 2000);
  }

  /// Volume formatted like §37: "8,640 kg".
  String get volumeLabel {
    final v = volumeKg.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < v.length; i++) {
      if (i > 0 && (v.length - i) % 3 == 0) buf.write(',');
      buf.write(v[i]);
    }
    return '${buf.toString()} kg';
  }

  /// Last performed set for an exercise (the "Previous: 10 × 20 kg" hint).
  SetRecord? lastSetFor(int exerciseIndex) {
    SetRecord? best;
    for (final s in sets) {
      if (s.exerciseIndex == exerciseIndex &&
          (best == null || s.completedAt.isAfter(best.completedAt))) {
        best = s;
      }
    }
    return best;
  }

  int setsDoneFor(int exerciseIndex) =>
      sets.where((s) => s.exerciseIndex == exerciseIndex).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'template': templateName,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'rating': rating,
        if (seeded) 'seeded': true,
        'sets': [for (final s in sets) s.toJson()],
      };

  static WorkoutSession? fromJson(dynamic j) {
    if (j is! Map) return null;
    final m = j.cast<String, dynamic>();
    final start = DateTime.tryParse('${m['startedAt']}');
    final name = m['template'];
    if (start == null || name is! String) return null; // skip malformed rows
    return WorkoutSession(
      id: m['id'] is String ? m['id'] as String : 'restored-$start',
      templateName: name,
      startedAt: start,
      finishedAt: DateTime.tryParse('${m['finishedAt']}'),
      rating: (m['rating'] as num?)?.toInt(),
      seeded: m['seeded'] == true,
      sets: [
        for (final raw in (m['sets'] is List ? m['sets'] as List : const []))
          if (raw is Map) SetRecord.fromJson(raw.cast<String, dynamic>()),
      ],
    );
  }
}

/// ── Session manager: the only way sessions mutate ──────────────────
/// The UI never edits [WorkoutSession] directly; it calls these methods
/// and receives a change callback so the store can persist + notify.
class WorkoutSessionManager {
  WorkoutSessionManager({required this.onChanged});

  /// Invoked after every mutation (persist + notifyListeners upstream).
  final void Function() onChanged;

  /// WP3.4 — when true, the next [onChanged] fires through [_dirtyGuard]
  /// so seed data never triggers an autosave write (keeps first launch
  /// byte-identical to "no user data yet"). Set by PulseStore around
  /// [seedHistory].
  bool _seeding = false;
  bool Function()? dirtyGuard;

  WorkoutSession? _active;
  final List<WorkoutSession> _history = [];

  void _mutated() {
    if (_seeding) return; // seeds must not mark the store dirty
    onChanged();
  }

  WorkoutSession? get activeSession => _active;
  bool get hasActive => _active != null;

  /// Newest-first completed sessions.
  List<WorkoutSession> get history => List.unmodifiable(_history.reversed);

  /// Start (or resume) a session for [templateName]. Starting while a
  /// session is active auto-saves the old one as a partial workout —
  /// nothing is ever silently dropped.
  WorkoutSession start(String templateName, {DateTime? now}) {
    if (_active != null) finish(rating: _active!.rating);
    _active = WorkoutSession(
      id: 'ws-${(now ?? DateTime.now()).microsecondsSinceEpoch}',
      templateName: templateName,
      startedAt: now ?? DateTime.now(),
    );
    _mutated();
    return _active!;
  }

  /// Record a completed set. Guards against nonsense input so bad UI
  /// state can never corrupt persisted history.
  SetRecord logSet({
    required int exerciseIndex,
    required int setNumber,
    required int reps,
    required double weightKg,
    DateTime? now,
  }) {
    final s = _active;
    if (s == null) {
      throw StateError('No active workout session — call start() first.');
    }
    final rec = SetRecord(
      exerciseIndex: exerciseIndex.clamp(0, 99),
      setNumber: setNumber.clamp(1, 30),
      reps: reps.clamp(0, 200),
      weightKg: weightKg < 0 ? 0 : weightKg,
      completedAt: now ?? DateTime.now(),
    );
    s.sets.add(rec);
    _mutated();
    return rec;
  }

  /// Undo the most recent set (pairs with the §76 undo snackbar).
  SetRecord? undoLastSet() {
    final s = _active;
    if (s == null || s.sets.isEmpty) return null;
    final removed = s.sets.removeLast();
    _mutated();
    return removed;
  }

  /// End the session (full completion OR early exit — same path, the
  /// partial save semantics live here, matching the "End & Save" copy).
  WorkoutSession? finish({int? rating, DateTime? now}) {
    final s = _active;
    if (s == null) return null;
    s.finishedAt = now ?? DateTime.now();
    if (s.finishedAt!.isBefore(s.startedAt)) s.finishedAt = s.startedAt;
    if (rating != null) s.rating = rating.clamp(0, 2);
    _history.add(s);
    _active = null;
    _mutated();
    return s;
  }

  /// Discard the active session entirely (used by explicit "Discard",
  /// never by navigation accidents).
  void discardActive() {
    if (_active == null) return;
    _active = null;
    _mutated();
  }

  /// Attach/update a difficulty rating on a saved session by id.
  void rate(String sessionId, int rating) {
    for (final s in _history) {
      if (s.id == sessionId) {
        s.rating = rating.clamp(0, 2);
        _mutated();
        return;
      }
    }
    if (_active?.id == sessionId) {
      _active!.rating = rating.clamp(0, 2);
      _mutated();
    }
  }

  /// WP3.4 — import pre-existing workout history (for example from a
  /// migration or a connected health source). Imported rows are flagged
  /// [seeded] so they never inflate *today's* counters or streaks, and are
  /// only applied when the user has no real data. Unused on a fresh install:
  /// history comes from sessions the user actually completes.
  void seedHistory(List<WorkoutSession> sessions) {
    if (_history.isNotEmpty || _active != null) return; // never clobber real data
    _history.addAll(sessions);
    _mutated();
  }

  /// Completed (non-seeded) sessions on the given calendar day.
  List<WorkoutSession> completedOn(DateTime day) => _history
      .where((s) =>
          !s.seeded &&
          s.finishedAt != null &&
          s.finishedAt!.year == day.year &&
          s.finishedAt!.month == day.month &&
          s.finishedAt!.day == day.day)
      .toList(growable: false);

  /// All finished sessions whose finish date falls inside
  /// `[end.subtract(Duration(days: days - 1)), end]` inclusive — used by
  /// the weekly report and consistency insights.
  List<WorkoutSession> finishedWithinDays(int days, {DateTime? end}) {
    final e = end ?? DateTime.now();
    final endDay = DateTime(e.year, e.month, e.day);
    final startDay = endDay.subtract(Duration(days: days - 1));
    return _history.where((s) {
      if (s.finishedAt == null) return false;
      final d = DateTime(s.finishedAt!.year, s.finishedAt!.month, s.finishedAt!.day);
      return !d.isBefore(startDay) && !d.isAfter(endDay);
    }).toList(growable: false);
  }

  /// Count of non-seeded completed sessions (the honest number behind
  /// "You've completed N workouts" milestones).
  int get realCompletedCount => _history.where((s) => !s.seeded && s.finishedAt != null).length;

  /// Count including seeded samples (achievement display only).
  int get totalCompletedCount => _history.where((s) => s.finishedAt != null).length;

  // ── Snapshot (de)serialization for PulseStore persistence ────────

  Map<String, dynamic> toJson() => {
        'active': _active?.toJson(),
        'history': [for (final s in _history) s.toJson()],
      };

  void hydrate(Map<String, dynamic>? json) {
    _active = null;
    _history.clear();
    if (json == null) return;
    _active = WorkoutSession.fromJson(json['active']);
    final h = json['history'];
    if (h is List) {
      for (final raw in h) {
        final s = WorkoutSession.fromJson(raw);
        if (s != null) _history.add(s);
      }
    }
  }

  String encode() => jsonEncode(toJson());
}
