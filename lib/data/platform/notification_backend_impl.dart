import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notification_scheduler.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Concrete [NotificationBackend] over
/// `flutter_local_notifications` (§7.3 item 7, brief §58/§64).
/// A translation layer only: which reminders become which notifications
/// is decided by [LocalNotificationScheduler], so that logic stays
/// testable without the plugin.
/// ═══════════════════════════════════════════════════════════════════

class FlutterLocalNotificationsBackend implements NotificationBackend {
  FlutterLocalNotificationsBackend({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Channel the reminders are posted to. A single channel keeps the
  /// user's system-level control simple: one switch silences reminders.
  static const _channel = AndroidNotificationDetails(
    'pulse_reminders',
    'Reminders',
    channelDescription: 'Water, meal and workout reminders you have set.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Loads the timezone database and initialises the plugin. Scheduling is
  /// zone-aware, so a reminder set for 10:30 stays at 10:30 after travel.
  Future<void> ensureInitialized() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
        settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Permission is requested explicitly through requestPermission()
        // rather than on first launch, so the ask has context (§58).
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  @override
  Future<bool> hasPermission() async {
    await ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    // iOS exposes no "already granted?" query, so a request is the only way
    // to learn the answer; it is a no-op once decided.
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    await ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Android 13+ POST_NOTIFICATIONS runtime permission.
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule(ScheduledNotification n) async {
    await ensureInitialized();
    await _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: _nextOccurrence(n.hour, n.minute, n.weekday),
      notificationDetails: const NotificationDetails(
          android: _channel, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // A daily reminder repeats on time alone; a weekday one must also
      // match the day.
      matchDateTimeComponents: n.weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> cancelAll() async {
    await ensureInitialized();
    await _plugin.cancelAll();
  }

  /// The next wall-clock moment matching the reminder. Scheduling in the
  /// past fires immediately, so a time already gone today rolls forward.
  static tz.TZDateTime _nextOccurrence(int hour, int minute, int? weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    if (weekday != null) {
      while (next.weekday != weekday) {
        next = next.add(const Duration(days: 1));
      }
    }
    return next;
  }
}
