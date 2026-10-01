/// ══════════════════════════════════════════════════════════════════
/// §3 — The daily archive: the history seven screens claimed to have
///
/// Weekly Report read "58,420 steps", Streaks read "7-day streak",
/// Insights read "18 of the last 21 days". None of it came from the
/// store, because the store had no history to give: four scalars for
/// today and nothing else. Every one of those figures was typed into
/// the widget tree.
///
/// This is the missing layer. One [DayRecord] per calendar day, rolled
/// over from today's scalars when the date changes, bounded so a
/// local-first snapshot cannot grow without limit. Pure Dart, no
/// Flutter import → unit-testable without a widget pump.
///
/// Wiring it surfaced a second defect: nothing ever reset the scalars,
/// so `stepsToday` accumulated across calendar days forever. The
/// rollover in PulseStore fixes that as a side effect of recording it.
/// ══════════════════════════════════════════════════════════════════

/// Longest history kept in the snapshot (§3). Three months answers every
/// window the screens ask for — 7-day report, 21-day consistency, the
/// month calendars — without unbounded growth on a device.
const int kDayArchiveMaxDays = 92;

/// §5 hydration rule: an `as num?` cast *throws* on a String, so a
/// single corrupt field would abort the load and cost the user their
/// whole history. This is the `is`-guard that cannot.
double _num(Object? value) => value is num ? value.toDouble() : 0;

/// A single calendar day as it actually happened. `date` is an
/// ISO `yyyy-MM-dd` key so records sort lexically and compare exactly,
/// which a DateTime with a stray time component would not.
class DayRecord {
  const DayRecord({
    required this.date,
    this.steps = 0,
    this.waterLiters = 0,
    this.kcal = 0,
    this.protein = 0,
    this.workouts = 0,
    this.logged = false,
  });

  final String date;
  final double steps;
  final double waterLiters;
  final double kcal;
  final double protein;
  final int workouts;

  /// Whether the user actually recorded anything. A rolled-over empty
  /// day is still a real record — it must not flatter a streak.
  final bool logged;

  /// Any movement or completed workout — what the calendars paint a dot
  /// for, as opposed to the `d % 3 == 0` arithmetic they used before.
  bool get wasActive => steps > 0 || workouts > 0;

  Map<String, dynamic> toJson() => {
        'date': date,
        'steps': steps,
        'water': waterLiters,
        'kcal': kcal,
        'protein': protein,
        'workouts': workouts,
        'logged': logged,
      };

  /// Hydration never throws (§5): a corrupt record must not cost the
  /// user the rest of their history, so every field is `is`-guarded and
  /// falls back rather than aborting the load.
  static DayRecord fromJson(Map<String, dynamic> json) => DayRecord(
        date: json['date'] is String ? json['date'] as String : '',
        steps: _num(json['steps']),
        waterLiters: _num(json['water']),
        kcal: _num(json['kcal']),
        protein: _num(json['protein']),
        workouts: _num(json['workouts']).toInt(),
        logged: json['logged'] is bool ? json['logged'] as bool : false,
      );
}

/// The day key every record is filed under. Local date only — a user
/// crossing midnight is on a new day regardless of their timezone.
String pulseDayKey(DateTime when) =>
    '${when.year.toString().padLeft(4, '0')}-'
    '${when.month.toString().padLeft(2, '0')}-'
    '${when.day.toString().padLeft(2, '0')}';

/// The history itself. Ordered oldest-first, one record per date,
/// bounded to [kDayArchiveMaxDays].
class DayArchive {
  final Map<String, DayRecord> _byDate = {};

  /// Oldest first, so a chart can read straight through it.
  List<DayRecord> get days {
    final keys = _byDate.keys.toList()..sort();
    return [for (final k in keys) _byDate[k]!];
  }

  /// Files a day, replacing any record already held for that date —
  /// one calendar day is one record, never two.
  void record(DayRecord entry) {
    _byDate[entry.date] = entry;
    if (_byDate.length > kDayArchiveMaxDays) {
      final keys = _byDate.keys.toList()..sort();
      for (final stale in keys.take(_byDate.length - kDayArchiveMaxDays)) {
        _byDate.remove(stale);
      }
    }
  }

  DayRecord? forDay(DateTime when) => _byDate[pulseDayKey(when)];

  bool wasActiveOn(DateTime when) => forDay(when)?.wasActive ?? false;

  /// The most recent [count] records, oldest first.
  List<DayRecord> lastDays(int count) {
    final all = days;
    return all.length <= count ? all : all.sublist(all.length - count);
  }

  double totalSteps(int window) =>
      lastDays(window).fold(0.0, (sum, d) => sum + d.steps);

  int totalWorkouts(int window) =>
      lastDays(window).fold(0, (sum, d) => sum + d.workouts);

  int loggedInLast(int window) =>
      lastDays(window).where((d) => d.logged).length;

  /// Days in the window that met [goal] — counted against the user's
  /// own protein target, where "5 / 7 protein days" was a constant.
  int proteinDaysMeeting(double goal, int window) =>
      lastDays(window).where((d) => d.logged && d.protein >= goal).length;

  /// Consecutive logged days ending today or yesterday. A streak that
  /// stopped two days ago is honestly reported as zero.
  int streakAsOf(DateTime now) {
    var cursor = DateTime(now.year, now.month, now.day);
    // Today may legitimately not be logged yet, so the streak is allowed
    // to end yesterday without being broken.
    if (!(forDay(cursor)?.logged ?? false)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!(forDay(cursor)?.logged ?? false)) return 0;
    }
    var streak = 0;
    while (forDay(cursor)?.logged ?? false) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Streak against the latest day the archive holds — used where no
  /// clock is to hand, such as a value object read in a test.
  int get currentStreak {
    final all = days;
    if (all.isEmpty) return 0;
    final parts = all.last.date.split('-');
    if (parts.length != 3) return 0;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return 0;
    return streakAsOf(DateTime(year, month, day));
  }

  void clear() => _byDate.clear();

  List<Map<String, dynamic>> toJson() =>
      [for (final d in days) d.toJson()];

  static DayArchive fromJson(Object? json) {
    final archive = DayArchive();
    if (json is! List) return archive;
    for (final row in json) {
      if (row is! Map) continue;
      final entry = DayRecord.fromJson(Map<String, dynamic>.from(row));
      // A record with no date cannot be filed or found again.
      if (entry.date.isNotEmpty) archive.record(entry);
    }
    return archive;
  }
}

/// A single logged drink (§3). The water screen listed five invented
/// timestamped rows, each with a working delete button; these are the
/// real ones, and the day's total is derived from them.
class WaterSip {
  const WaterSip({required this.at, required this.liters});

  final DateTime at;
  final double liters;

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'liters': liters};

  static WaterSip fromJson(Map<String, dynamic> json) => WaterSip(
        at: DateTime.tryParse(json['at'] is String ? json['at'] as String : '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        liters: (json['liters'] as num?)?.toDouble() ?? 0,
      );
}
