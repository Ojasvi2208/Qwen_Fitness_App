/// ══════════════════════════════════════════════════════════════════
/// WP3.5 — Reminders & notification scheduling (§58, §64)
///
/// Design constraints honored here:
///  * The store persists only Reminder MODELS (time, repeat, enabled).
///    Actual OS scheduling happens behind [ReminderScheduler], an
///    injectable interface — production wires flutter_local_notifications,
///    tests wire _FakeScheduler. No plugin import in the domain layer,
///    so everything below is pure-Dart unit-testable.
///  * Permission-denied degrades gracefully (§87): reminders stay saved
///    and sync once permission is granted; nothing crashes.
///  * Copy is never guilt-inducing (§55).
/// ══════════════════════════════════════════════════════════════════

enum RepeatMode { daily, weekdays, custom }

extension RepeatModeLabel on RepeatMode {
  String get label => switch (this) {
        RepeatMode.daily => 'Every day',
        RepeatMode.weekdays => 'Weekdays',
        RepeatMode.custom => 'Custom days',
      };
}

class Reminder {
  final String id;
  String title; // "Drink Water"
  String body; // "Time for a glass of water."
  int hour; // 0-23
  int minute; // 0-59
  RepeatMode repeat;
  Set<int> days; // DateTime.weekday values used when repeat == custom
  bool enabled;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.repeat = RepeatMode.daily,
    Set<int>? days,
    this.enabled = true,
  }) : days = days ?? {1, 2, 3, 4, 5, 6, 7};

  String get timeLabel {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  bool firesOn(int weekday) => switch (repeat) {
        RepeatMode.daily => true,
        RepeatMode.weekdays => weekday >= 1 && weekday <= 5,
        RepeatMode.custom => days.contains(weekday),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'repeat': repeat.name,
        'days': days.toList()..sort(),
        'enabled': enabled,
      };

  static Reminder? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    final body = j['body'];
    final hour = (j['hour'] as num?)?.toInt();
    final minute = (j['minute'] as num?)?.toInt();
    if (id is! String || title is! String || body is! String ||
        hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null; // malformed row skipped, never corrupts the list
    }
    return Reminder(
      id: id,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
      repeat: RepeatMode.values.firstWhere(
          (r) => r.name == j['repeat'], orElse: () => RepeatMode.daily),
      days: {
        for (final d in (j['days'] is List ? j['days'] as List : const []))
          if (d is num && d.toInt() >= 1 && d.toInt() <= 7) d.toInt()
      },
      enabled: j['enabled'] as bool? ?? true,
    );
  }
}

/// ── Seams ────────────────────────────────────────────────────────────
typedef ReminderSyncer = Future<void> Function(List<Reminder> active);
typedef NotificationPermission = Future<bool> Function();

/// In-memory reminder book with validation + change callback (the store
/// hooks this into autosave/notify exactly like sessions/measurement log).
class ReminderBook {
  ReminderBook({required this.onChanged});

  /// Reassignable so a manager can late-bind its own callback.
  void Function() onChanged;
  final List<Reminder> _items = [];

  List<Reminder> get all => List.unmodifiable(_items);
  List<Reminder> get active => _items.where((r) => r.enabled).toList(growable: false);

  /// Create or update by id. Validates fields; returns false so the UI
  /// can show inline errors (§75) instead of persisting nonsense.
  bool upsert(Reminder r) {
    if (r.title.trim().isEmpty || r.hour < 0 || r.hour > 23 ||
        r.minute < 0 || r.minute > 59 ||
        (r.repeat == RepeatMode.custom && r.days.isEmpty)) {
      return false;
    }
    final i = _items.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      _items[i] = r;
    } else {
      _items.add(r);
    }
    onChanged();
    return true;
  }

  bool setEnabled(String id, bool v) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return false;
    _items[i].enabled = v;
    onChanged();
    return true;
  }

  bool remove(String id) {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    if (_items.length != before) {
      onChanged();
      return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {'items': [for (final r in _items) r.toJson()]};

  void hydrate(Map<String, dynamic>? json) {
    if (json == null) return;
    _items.clear();
    final list = json['items'];
    if (list is! List) return;
    for (final raw in list) {
      final r = Reminder.fromJson(raw);
      if (r != null) _items.add(r);
    }
  }

  void eraseAll() => _items.clear();
}

/// Platform scheduler interface. Production implementation wraps
/// flutter_local_notifications (zonedSchedule per active reminder);
/// tests use a fake that records calls.
abstract class ReminderScheduler {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<void> sync(List<Reminder> active);
  Future<void> cancelAll();
}

/// ── Store-level manager ─────────────────────────────────────────────
class ReminderManager {
  ReminderManager({required this.onChanged, ReminderScheduler? scheduler})
      : _scheduler = scheduler,
        book = ReminderBook(onChanged: () {}) {
    book.onChanged = _syncNow;
  }

  final void Function() onChanged;
  ReminderScheduler? _scheduler;
  final ReminderBook book;

  /// Permission state for UI ("Notifications: allowed / denied").
  bool permissionGranted = false;

  void attachScheduler(ReminderScheduler s) {
    _scheduler = s;
  }

  void _syncNow() {
    onChanged();
    final s = _scheduler;
    if (s == null) return;
    // Fire-and-forget: scheduling failures must never break logging.
    s.hasPermission().then((ok) {
      permissionGranted = ok;
      if (ok) s.sync(book.active);
    }).catchError((_) {});
  }

  bool save(Reminder r) {
    final ok = book.upsert(r);
    if (ok) _syncNow();
    return ok;
  }

  bool toggle(String id, bool enabled) {
    final ok = book.setEnabled(id, enabled);
    if (ok) _syncNow();
    return ok;
  }

  bool delete(String id) {
    final ok = book.remove(id);
    if (ok) _syncNow();
    return ok;
  }

  Future<bool> ensurePermission() async {
    final s = _scheduler;
    if (s == null) return false;
    try {
      permissionGranted = await s.requestPermission();
      if (permissionGranted) await s.sync(book.active);
      onChanged();
      return permissionGranted;
    } catch (_) {
      permissionGranted = false;
      return false;
    }
  }

  Map<String, dynamic> toJson() => book.toJson();
  void hydrate(Map<String, dynamic>? json) => book.hydrate(json);

  void eraseAll() {
    book.eraseAll();
    _scheduler?.cancelAll().catchError((_) {});
    onChanged();
  }
}
