import '../reminders.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Real notification scheduler (§7.3 item 7, brief §58/§64).
/// Implements [ReminderScheduler], so ReminderManager's CRUD keeps
/// driving scheduling exactly as it does with the stub: the book is the
/// source of truth and sync() mirrors it.
///
/// `flutter_local_notifications` sits behind [NotificationBackend] so the
/// mirroring logic — which reminders become which OS notifications, and
/// what happens when permission is refused — is testable without a
/// platform toolchain.
/// ═══════════════════════════════════════════════════════════════════

/// One scheduled OS notification. Ids are derived from the reminder and the
/// weekday so a daily reminder maps to one entry and a custom-day reminder
/// to several, which is what the OS APIs expect.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.reminderId,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    required this.weekday,
  });

  final int id;
  final String reminderId;
  final String title;
  final String body;
  final int hour;
  final int minute;

  /// DateTime.weekday value, or null for a daily repeat.
  final int? weekday;
}

/// The slice of `flutter_local_notifications` this app needs.
abstract class NotificationBackend {
  Future<bool> hasPermission();

  /// Android 13+ POST_NOTIFICATIONS, or the iOS provisional request.
  Future<bool> requestPermission();
  Future<void> schedule(ScheduledNotification n);
  Future<void> cancelAll();
}

class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({required NotificationBackend backend})
      : _backend = backend;

  final NotificationBackend _backend;

  /// What is currently mirrored to the OS, for assertions and for the
  /// "Notifications: N scheduled" line in Settings.
  final List<ScheduledNotification> scheduled = [];

  @override
  Future<bool> hasPermission() => _backend.hasPermission();

  @override
  Future<bool> requestPermission() => _backend.requestPermission();

  @override
  Future<void> sync(List<Reminder> active) async {
    // Refusing notifications is a supported choice, not a failure: the
    // reminders stay in the book and simply do not fire (§58).
    if (!await _backend.hasPermission()) {
      await cancelAll();
      return;
    }
    // Full replace rather than a diff: the book is small and an exact
    // mirror is easier to trust than incremental reconciliation.
    await cancelAll();
    for (final r in active) {
      if (!r.enabled) continue;
      for (final n in _expand(r)) {
        scheduled.add(n);
        await _backend.schedule(n);
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    await _backend.cancelAll();
  }

  /// One reminder becomes one notification when it repeats daily, or one per
  /// selected weekday otherwise. The id packs both so cancelling is exact.
  Iterable<ScheduledNotification> _expand(Reminder r) {
    // Defer to Reminder.firesOn so the repeat semantics live in one place.
    final days = r.repeat == RepeatMode.daily
        ? <int?>[null]
        : <int?>[for (var d = 1; d <= 7; d++) if (r.firesOn(d)) d];
    return days.map((d) => ScheduledNotification(
          id: _idFor(r.id, d),
          reminderId: r.id,
          title: r.title,
          body: r.body,
          hour: r.hour,
          minute: r.minute,
          weekday: d,
        ));
  }

  /// Stable, collision-resistant id from the reminder id and weekday. The
  /// OS wants an int, and the same reminder must map to the same id across
  /// launches so a stale notification can always be cancelled.
  static int _idFor(String reminderId, int? weekday) =>
      (reminderId.hashCode & 0x0FFFFFFF) * 8 + (weekday ?? 0);
}
