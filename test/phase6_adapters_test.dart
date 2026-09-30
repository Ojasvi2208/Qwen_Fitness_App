import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/monetization.dart';
import 'package:pulse_app/data/platform/admob_provider.dart';
import 'package:pulse_app/data/platform/billing_gateway.dart';
import 'package:pulse_app/data/platform/local_notification_scheduler.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/data/reminders.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Platform adapter tests (§7.3 items 5–7).
/// The plugins themselves need a toolchain this environment lacks, so
/// each adapter is exercised through a hand-written backend fake. What
/// is proven here is the app-side contract: policy is never bypassed,
/// a refused permission degrades rather than throws, and the store's
/// entitlement state still comes from the store.
/// ═══════════════════════════════════════════════════════════════════

class _FakeBillingBackend implements BillingBackend {
  _FakeBillingBackend({this.available = true, this.result, this.past = const []});

  bool available;
  BillingPurchase? result;
  List<BillingPurchase> past;
  final List<String> bought = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BillingPurchase> buyNonConsumable(String productId) async {
    bought.add(productId);
    return result ??
        BillingPurchase(productId: productId, purchased: true,
            transactionDate: DateTime(2026, 3, 1));
  }

  @override
  Future<List<BillingPurchase>> queryPastPurchases() async => past;
}

class _FakeAdBackend implements AdBackend {
  _FakeAdBackend({this.fills = true});
  bool fills;
  int initCount = 0;
  final List<String> loaded = [];

  @override
  Future<void> initialize() async => initCount++;

  @override
  Future<bool> loadBanner(String unitId) async {
    loaded.add(unitId);
    return fills;
  }
}

class _FakeNotificationBackend implements NotificationBackend {
  _FakeNotificationBackend({this.granted = true});
  bool granted;
  int requests = 0;
  int cancels = 0;
  final List<ScheduledNotification> scheduled = [];

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<void> schedule(ScheduledNotification n) async => scheduled.add(n);

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }
}

void main() {
  group('Phase 6 billing gateway (§63)', () {
    test('a successful purchase reports true and records the platform date',
        () async {
      final backend = _FakeBillingBackend();
      final gateway = InAppPurchaseGateway(backend: backend);
      expect(await gateway.purchase(PulsePricing.yearly), isTrue);
      expect(backend.bought, ['pulse_pro_yearly']);
      expect(gateway.lastPurchaseDate, DateTime(2026, 3, 1),
          reason: 'platform time is preferred over the local clock');
    });

    test('an unavailable store fails softly rather than throwing', () async {
      final gateway = InAppPurchaseGateway(
          backend: _FakeBillingBackend(available: false));
      expect(await gateway.purchase(PulsePricing.monthly), isFalse);
      expect(await gateway.restorePurchases(), isFalse);
    });

    test('a declined purchase leaves no recorded date', () async {
      final gateway = InAppPurchaseGateway(
          backend: _FakeBillingBackend(
              result: const BillingPurchase(
                  productId: 'pulse_pro_yearly',
                  purchased: false,
                  error: 'user cancelled')));
      expect(await gateway.purchase(PulsePricing.yearly), isFalse);
      expect(gateway.lastPurchaseDate, isNull);
    });

    test('restore picks the most recent live purchase', () async {
      final gateway = InAppPurchaseGateway(
          backend: _FakeBillingBackend(past: [
        BillingPurchase(
            productId: 'pulse_pro_monthly',
            purchased: true,
            transactionDate: DateTime(2026, 1, 1)),
        BillingPurchase(
            productId: 'pulse_pro_yearly',
            purchased: true,
            transactionDate: DateTime(2026, 5, 1)),
      ]));
      expect(await gateway.restorePurchases(), isTrue);
      expect(gateway.lastPurchaseDate, DateTime(2026, 5, 1));
    });

    test('restore with nothing to restore is false, not an error', () async {
      final gateway =
          InAppPurchaseGateway(backend: _FakeBillingBackend(past: const []));
      expect(await gateway.restorePurchases(), isFalse);
    });

    test('product ids map back to the prices this build sells', () {
      expect(InAppPurchaseGateway.priceFor('pulse_pro_monthly'),
          PulsePricing.monthly);
      expect(InAppPurchaseGateway.priceFor('pulse_pro_yearly'),
          PulsePricing.yearly);
      expect(InAppPurchaseGateway.priceFor('pulse_pro_lifetime'), isNull);
    });

    test('the store still owns entitlement state after a purchase', () async {
      final store = PulseStore();
      final gateway =
          InAppPurchaseGateway(backend: _FakeBillingBackend());
      expect(store.premium, isFalse);
      await store.purchasePro(PulsePricing.yearly, gateway: gateway);
      expect(store.premium, isTrue, reason: 'the seam is injectable');
      expect(store.plan, PulsePlan.proYearly);
    });
  });

  group('Phase 6 ads provider (§61)', () {
    test('test inventory is the default so a build cannot bill by accident',
        () {
      expect(AdUnitIds.test.isTestInventory, isTrue);
      expect(AdUnitIds.fromEnvironment().isTestInventory, isTrue,
          reason: 'no --dart-define in a test run');
    });

    test('initialize marks the provider ready', () async {
      final backend = _FakeAdBackend();
      final provider = AdMobProvider(backend: backend);
      expect(provider.isReady, isFalse);
      await provider.initialize();
      expect(provider.isReady, isTrue);
      expect(backend.initCount, 1);
    });

    test('a disallowed slot is refused without reaching the network',
        () async {
      final backend = _FakeAdBackend();
      final provider = AdMobProvider(backend: backend);
      await provider.initialize();
      // Not in AdPolicy.allowedSlots, so the adapter must not load it.
      final blocked = AdSlot.values
          .firstWhere((s) => !AdPolicy.allowedSlots.contains(s), orElse: () => AdSlot.homeFooter);
      if (!AdPolicy.allowedSlots.contains(blocked)) {
        expect(await provider.requestBanner(blocked), isFalse);
        expect(backend.loaded, isEmpty,
            reason: 'policy is enforced before any request');
      }
    });

    test('an allowed slot loads once ready', () async {
      final backend = _FakeAdBackend();
      final provider = AdMobProvider(backend: backend);
      await provider.initialize();
      expect(await provider.requestBanner(AdSlot.homeFooter), isTrue);
      expect(backend.loaded, [AdUnitIds.kTestBanner]);
    });

    test('nothing loads before initialize', () async {
      final backend = _FakeAdBackend();
      final provider = AdMobProvider(backend: backend);
      expect(await provider.requestBanner(AdSlot.homeFooter), isFalse);
      expect(backend.loaded, isEmpty);
    });

    test('no fill is recorded rather than surfaced as an error', () async {
      final provider = AdMobProvider(backend: _FakeAdBackend(fills: false));
      await provider.initialize();
      expect(await provider.requestBanner(AdSlot.homeFooter), isFalse);
      expect(provider.unfilled, contains(AdSlot.homeFooter));
    });

    test('the slot label stays literal for transparency', () async {
      final provider = AdMobProvider(backend: _FakeAdBackend());
      expect(provider.descriptorFor(AdSlot.homeFooter).label, 'Advertisement');
    });
  });

  group('Phase 6 notification scheduler (§58/§64)', () {
    Reminder water({RepeatMode repeat = RepeatMode.daily, Set<int>? days}) =>
        Reminder(
            id: 'r1',
            title: 'Drink Water',
            body: 'Time for a glass.',
            hour: 10,
            minute: 30,
            repeat: repeat,
            days: days ?? {});

    test('a daily reminder becomes one scheduled notification', () async {
      final backend = _FakeNotificationBackend();
      final scheduler = LocalNotificationScheduler(backend: backend);
      await scheduler.sync([water()]);
      expect(backend.scheduled, hasLength(1));
      expect(backend.scheduled.single.weekday, isNull);
      expect(backend.scheduled.single.hour, 10);
      expect(backend.scheduled.single.minute, 30);
    });

    test('a weekdays reminder becomes five', () async {
      final backend = _FakeNotificationBackend();
      final scheduler = LocalNotificationScheduler(backend: backend);
      await scheduler.sync([water(repeat: RepeatMode.weekdays)]);
      expect(backend.scheduled, hasLength(5));
      expect(backend.scheduled.map((n) => n.weekday), [1, 2, 3, 4, 5]);
    });

    test('a custom reminder follows its selected days', () async {
      final backend = _FakeNotificationBackend();
      final scheduler = LocalNotificationScheduler(backend: backend);
      await scheduler.sync([water(repeat: RepeatMode.custom, days: {2, 6})]);
      expect(backend.scheduled.map((n) => n.weekday), [2, 6]);
    });

    test('a disabled reminder schedules nothing', () async {
      final backend = _FakeNotificationBackend();
      final scheduler = LocalNotificationScheduler(backend: backend);
      final r = water()..enabled = false;
      await scheduler.sync([r]);
      expect(backend.scheduled, isEmpty);
    });

    test('refused permission cancels instead of throwing', () async {
      final backend = _FakeNotificationBackend(granted: false);
      final scheduler = LocalNotificationScheduler(backend: backend);
      await scheduler.sync([water()]);
      expect(backend.scheduled, isEmpty);
      expect(backend.cancels, greaterThan(0),
          reason: 'a refusal is a supported choice, not a failure (§58)');
      expect(scheduler.scheduled, isEmpty);
    });

    test('sync mirrors the book exactly rather than accumulating', () async {
      final backend = _FakeNotificationBackend();
      final scheduler = LocalNotificationScheduler(backend: backend);
      await scheduler.sync([water(repeat: RepeatMode.weekdays)]);
      expect(backend.scheduled, hasLength(5));
      await scheduler.sync([water()]);
      expect(backend.scheduled, hasLength(1),
          reason: 'the previous five must not linger');
    });

    test('ids are stable across runs so a stale entry can be cancelled',
        () async {
      final a = _FakeNotificationBackend();
      final b = _FakeNotificationBackend();
      await LocalNotificationScheduler(backend: a).sync([water()]);
      await LocalNotificationScheduler(backend: b).sync([water()]);
      expect(a.scheduled.single.id, b.scheduled.single.id);
    });

    test('permission requests pass through to the platform', () async {
      final backend = _FakeNotificationBackend(granted: false);
      final scheduler = LocalNotificationScheduler(backend: backend);
      expect(await scheduler.requestPermission(), isFalse);
      expect(backend.requests, 1);
    });

    test('the manager drives the scheduler through its own CRUD', () async {
      final backend = _FakeNotificationBackend();
      final scheduler = LocalNotificationScheduler(backend: backend);
      final store = PulseStore();
      store.reminders.attachScheduler(scheduler);
      store.reminders.save(water());
      await Future<void>.delayed(Duration.zero);
      expect(backend.scheduled, isNotEmpty,
          reason: 'saving a reminder mirrors it to the OS');
    });
  });
}
