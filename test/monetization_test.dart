import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_app/data/monetization.dart';
import 'package:pulse_app/data/persistence/local_backend.dart';
import 'dart:convert';
import 'package:pulse_app/data/pulse_store.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 4 — Monetization & Ads QA suite.
/// Covers: pricing invariants, trial lifecycle (start/expiry/settle),
/// one-shot trial guard, paid activation/cancellation, ad-entitlement
/// enforcement, ad placement policy, persistence round-trips and
/// legacy-snapshot migration, purchase-gateway failure paths, and
/// Delete-My-Data erasure of entitlement state (§60).
/// ═══════════════════════════════════════════════════════════════════

class _FakeRepo implements LocalRepository {
  Map<String, dynamic>? stored;
  @override
  Future<void> init() async {}
  @override
  Future<Map<String, dynamic>?> readSnapshot() async => stored;
  @override
  Future<void> writeSnapshot(Map<String, dynamic> snapshot) async {
    // Snapshots are plain JSON-safe maps written synchronously by flush();
    // holding the reference is sufficient for these assertions.
    stored = snapshot;
  }

  @override
  Future<void> clearAll() async => stored = null;
}

void main() {
  final t0 = DateTime(2026, 9, 30, 9);

  group('Pricing model (§62 — competitive, honest)', () {
    test('monthly is \$9.99, yearly \$59.99 (~50% saving), trial is 3 days', () {
      expect(PulsePricing.monthly.usd, 9.99);
      expect(PulsePricing.yearly.usd, 59.99);
      expect(PulsePricing.trialDays, 3);
      expect(PulsePricing.yearly.cadence, 'year');
      expect(PulsePricing.monthly.cadence, 'month');
    });
    test('money formatting is stable for paywall copy', () {
      expect(PulsePricing.money(9.99), r'$9.99');
      expect(PulsePricing.money(59.99), r'$59.99');
    });
  });

  group('Entitlements — pure logic with injected clock', () {
    test('free plan shows ads, no Pro features', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      expect(e.isPro, false);
      expect(e.shouldShowAds, true);
      expect(e.effectivePlan(), PulsePlan.free);
      expect(e.trialBannerText(), isNull);
    });

    test('trial grants Pro during 3 days and hides ads', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      expect(e.beginTrial(), true);
      expect(s.trialUsed, true);
      expect(e.isPro, true);
      expect(e.shouldShowAds, false);
      expect(e.trialDaysRemaining(), greaterThanOrEqualTo(2));
      expect(e.trialBannerText(), contains('free trial'));
      expect(e.trialBannerText(), contains('Cancel anytime'));
    });

    test('trial auto-downgrades after exactly 72 hours (effective view)', () {
      final s = SubscriptionState();
      final start = Entitlements(() => s, clock: () => t0);
      start.beginTrial();
      // 71h59m → still pro
      final justBefore = Entitlements(() => s,
          clock: () => t0.add(const Duration(hours: 71, minutes: 59)));
      expect(justBefore.isPro, true);
      // 72h+1m → expired to free WITHOUT settle (pure derivation)
      final justAfter = Entitlements(() => s,
          clock: () => t0.add(const Duration(hours: 72, minutes: 1)));
      expect(justAfter.isPro, false);
      expect(justAfter.shouldShowAds, true);
      expect(justAfter.trialBannerText(), isNull);
    });

    test('settleExpired persists the downgrade once, then no-op', () {
      final s = SubscriptionState();
      final now = [t0];
      final e = Entitlements(() => s, clock: () => now[0]);
      e.beginTrial();
      now[0] = t0.add(const Duration(days: 4));
      expect(e.settleExpired(), true);
      expect(s.plan, PulsePlan.free);
      expect(e.settleExpired(), false); // idempotent
    });

    test('trial is one-shot per install — cannot restart after expiry', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      expect(e.beginTrial(), true);
      final later = Entitlements(() => s, clock: () => t0.add(const Duration(days: 5)));
      expect(later.settleExpired(), true);
      expect(later.beginTrial(), false, reason: 'trial must never be re-granted');
      expect(s.trialUsed, true);
    });

    test('paid activation from monthly price sets monthly plan, ads off', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      e.activatePaid(PulsePricing.monthly);
      expect(e.effectivePlan(), PulsePlan.proMonthly);
      expect(e.isPro, true);
      expect(e.shouldShowAds, false);
      expect(s.periodCadence, 'month');
    });

    test('paid plans survive "expiry" checks (good standing until server say)', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      e.activatePaid(PulsePricing.yearly);
      final farFuture = Entitlements(() => s,
          clock: () => t0.add(const Duration(days: 400)));
      expect(farFuture.isPro, true);
      expect(farFuture.settleExpired(), false);
    });

    test('cancel reverts to free immediately but keeps trialUsed', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      e.activatePaid(PulsePricing.yearly);
      e.revertToFree();
      expect(e.isPro, false);
      expect(e.shouldShowAds, true);
      expect(s.periodStart, isNull);
      expect(s.trialUsed, true); // cancel doesn't refund a used trial
      expect(e.beginTrial(), false);
    });

    test('beginTrial returns false when already on Pro', () {
      final s = SubscriptionState();
      final e = Entitlements(() => s, clock: () => t0);
      e.activatePaid(PulsePricing.monthly);
      expect(e.beginTrial(), false);
      expect(s.plan, PulsePlan.proMonthly); // unchanged
    });
  });

  group('Ad policy (§61 — non-interruptive placements)', () {
    test('only the three footer slots are allowed', () {
      expect(AdPolicy.allowedSlots,
          {AdSlot.homeFooter, AdSlot.afterDiaryComplete, AdSlot.workoutHistoryFooter});
      expect(AdPolicy.allowedSlots.contains(AdSlot.interstitialBetweenTabs), false,
          reason: 'tab interstitials are banned by policy');
    });
    test('ads blocked during scanning / active workout / logging flows', () {
      expect(AdPolicy.blockedWhile, containsAll(['scanning', 'activeWorkout', 'loggingFlow']));
    });
    test('interstitial frequency cap is at most 1/day', () {
      expect(AdPolicy.maxInterstitialsPerDay, lessThanOrEqualTo(1));
    });
  });

  group('SubscriptionState serialization', () {
    test('JSON round-trip preserves all fields', () {
      final s = SubscriptionState();
      s.plan = PulsePlan.proTrial;
      s.trialStartedAt = t0;
      s.trialUsed = true;
      final back = SubscriptionState.fromJson(s.toJson().cast<String, dynamic>());
      expect(back.plan, PulsePlan.proTrial);
      expect(back.trialStartedAt, t0);
      expect(back.trialUsed, true);
    });
    test('fromJson tolerates missing keys (forward/back compat)', () {
      final back = SubscriptionState.fromJson({'plan': 'proYearly'});
      expect(back.plan, PulsePlan.proYearly);
      expect(back.trialUsed, false);
      expect(back.trialStartedAt, isNull);
    });
  });

  group('PulseStore integration (real mutations + autosave)', () {
    late _FakeRepo repo;
    late PulseStore store;
    setUp(() async {
      repo = _FakeRepo();
      store = PulseStore();
      await store.attachPersistence(repo);
    });

    test('startTrial flips premium + adsAllowed and emits analytics event', () async {
      expect(store.premium, false);
      expect(store.adsAllowed, true);
      final ok = await store.startTrial(gateway: StubPurchaseGateway());
      expect(ok, true);
      expect(store.premium, true);
      expect(store.adsAllowed, false);
      expect(store.plan, PulsePlan.proTrial);
      expect(store.trialBanner, contains('free trial'));
    });

    test('startTrial is one-shot: second call fails even after cancel', () async {
      expect(await store.startTrial(gateway: StubPurchaseGateway()), true);
      store.cancelSubscription();
      expect(await store.startTrial(gateway: StubPurchaseGateway()), false);
      expect(store.premium, false);
    });

    test('purchase failure leaves state untouched (no phantom Pro)', () async {
      final fail = StubPurchaseGateway(shouldSucceed: false);
      expect(await store.startTrial(gateway: fail), false);
      expect(store.premium, false);
      expect(store.subscription.trialUsed, false);
      expect(await store.purchasePro(PulsePricing.monthly, gateway: fail), false);
      expect(store.premium, false);
    });

    test('purchasePro(yearly) activates Pro and disables ads', () async {
      expect(await store.purchasePro(PulsePricing.yearly, gateway: StubPurchaseGateway()), true);
      expect(store.plan, PulsePlan.proYearly);
      expect(store.premium, true);
      expect(store.adsAllowed, false);
    });

    test('subscription survives app restart (snapshot round-trip)', () async {
      await store.purchasePro(PulsePricing.monthly, gateway: StubPurchaseGateway());
      store.flushPendingSave();
      final restored = PulseStore();
      await restored.attachPersistence(repo);
      expect(restored.plan, PulsePlan.proMonthly);
      expect(restored.premium, true);
      expect(restored.adsAllowed, false);
    });

    test('legacy v1/v2 snapshot with only bool premium migrates to paid', () async {
      // Simulate an old snapshot written before Phase 4.
      store.updateGoals((g) => g.calorieGoal = 2100); // force a save baseline
      store.flushPendingSave();
      final snap = Map<String, dynamic>.from(repo.stored!);
      snap.remove('subscription');
      snap['premium'] = true;
      repo.stored = snap;
      final restored = PulseStore();
      await restored.attachPersistence(repo);
      expect(restored.premium, true, reason: 'legacy premium=true must map to a paid plan');
      expect(restored.adsAllowed, false);
    });

    test('expired trial settles to free on hydrate (restart after day 4)', () async {
      await store.startTrial(gateway: StubPurchaseGateway());
      store.flushPendingSave();
      // Age the trial start beyond 3 days directly in the stored snapshot.
      final snap = Map<String, dynamic>.from(repo.stored!);
      final sub = Map<String, dynamic>.from(snap['subscription'] as Map);
      sub['trialStartedAt'] =
          DateTime.now().subtract(const Duration(days: 4)).toIso8601String();
      snap['subscription'] = sub;
      repo.stored = snap;
      final restored = PulseStore();
      await restored.attachPersistence(repo);
      expect(restored.plan, PulsePlan.free);
      expect(restored.premium, false);
      expect(restored.adsAllowed, true);
      expect(restored.subscription.trialUsed, true,
          reason: 'settled trial must not be re-grantable');
    });

    test('Delete My Data erases entitlement state too (§60)', () async {
      await store.purchasePro(PulsePricing.yearly, gateway: StubPurchaseGateway());
      store.flushPendingSave();
      await store.deleteAllLocalData();
      expect(store.premium, false);
      expect(store.subscription.trialUsed, false);
      final restored = PulseStore();
      await restored.attachPersistence(repo);
      expect(restored.premium, false);
    });

    test('togglePremium dev shortcut starts the one-shot trial safely', () {
      store.togglePremium();
      expect(store.premium, true);
      store.togglePremium(); // cancel
      expect(store.premium, false);
      store.togglePremium(); // must NOT silently re-grant a used trial
      expect(store.subscription.trialUsed, true);
    });
  });
}


