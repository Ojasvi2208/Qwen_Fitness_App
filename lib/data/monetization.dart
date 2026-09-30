import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 4 — MONETIZATION & ADS (local-first, SDK-agnostic)
///
/// Pricing model (market-benchmarked Sept 2026):
///   • Free tier: all core logging forever (food diary, water, steps,
///     workouts, basic progress) + tasteful, non-interruptive ads.
///   • PULSE Pro — $9.99 / month  or  $59.99 / year (≈$4.99/mo, save 50%).
///   • 3-day free trial on first Pro activation. No deceptive countdowns,
///     no paywall interruption of logging flows (§62).
///   • Benchmarks: MyFitnessPal $19.99→$79.99/yr premium, Fitbit Premium
///     $9.99/mo · $79.99/yr, Apple Fitness+ $9.99/mo · $49.99/yr.
///     PULSE undercuts annual price while matching monthly parity.
///
/// Entitlements are computed from a persisted clock-stamped record so
/// trial expiry survives app restarts. Server-side receipt validation
/// (App Store / Play Billing) is a Phase 6 seam — see [PurchaseGateway].
/// ═══════════════════════════════════════════════════════════════════

enum PulsePlan { free, proTrial, proMonthly, proYearly }

extension PulsePlanLabel on PulsePlan {
  String get label => switch (this) {
        PulsePlan.free => 'PULSE Free',
        PulsePlan.proTrial => 'PULSE Pro · Trial',
        PulsePlan.proMonthly => 'PULSE Pro · Monthly',
        PulsePlan.proYearly => 'PULSE Pro · Yearly',
      };
  bool get isPro => this != PulsePlan.free;
}

class PulsePrice {
  final String id; // store product id placeholder
  final String label;
  final double usd;
  final String cadence;
  final String? savingsNote;
  const PulsePrice(this.id, this.label, this.usd, this.cadence, {this.savingsNote});
}

class PulsePricing {
  /// Agreed competitive pricing — single source of truth for every UI.
  static const monthly = PulsePrice('pulse_pro_monthly', 'Monthly', 9.99, 'month');
  static const yearly =
      PulsePrice('pulse_pro_yearly', 'Yearly · save 50%', 59.99, 'year', savingsNote: '≈ \$4.99/month');
  static const trialDays = 3;

  static String money(double v) =>
      '\$${v.toStringAsFixed(2)}';
}

/// Persisted subscription state. All timestamps ISO-8601 local time.
class SubscriptionState {
  PulsePlan plan;
  DateTime? trialStartedAt; // set once per install (trial is one-shot)
  bool trialUsed;
  DateTime? periodStart;    // for paid plans (renewal anchor)
  String? periodCadence;    // 'month' | 'year'

  SubscriptionState({
    this.plan = PulsePlan.free,
    this.trialStartedAt,
    this.trialUsed = false,
    this.periodStart,
    this.periodCadence,
  });

  Map<String, dynamic> toJson() => {
        'plan': plan.name,
        'trialStartedAt': trialStartedAt?.toIso8601String(),
        'trialUsed': trialUsed,
        'periodStart': periodStart?.toIso8601String(),
        'periodCadence': periodCadence,
      };

  static SubscriptionState fromJson(Map<String, dynamic> j) => SubscriptionState(
        plan: PulsePlan.values.firstWhere((p) => p.name == j['plan'], orElse: () => PulsePlan.free),
        trialStartedAt: j['trialStartedAt'] != null ? DateTime.tryParse(j['trialStartedAt'] as String) : null,
        trialUsed: j['trialUsed'] as bool? ?? false,
        periodStart: j['periodStart'] != null ? DateTime.tryParse(j['periodStart'] as String) : null,
        periodCadence: j['periodCadence'] as String?,
      );
}

/// Pure entitlement logic — fully unit-testable with an injected clock.
class Entitlements {
  final SubscriptionState Function() _state;
  final DateTime Function() _now;

  Entitlements(this._state, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  /// Effective plan after applying trial-expiry rules. Never mutates —
  /// the store calls [settleExpired] to persist transitions.
  PulsePlan effectivePlan() {
    final s = _state();
    switch (s.plan) {
      case PulsePlan.free:
        return PulsePlan.free;
      case PulsePlan.proTrial:
        final start = s.trialStartedAt;
        if (start == null) return PulsePlan.free;
        final end = start.add(const Duration(days: PulsePricing.trialDays));
        if (_now().isBefore(end)) return PulsePlan.proTrial;
        return PulsePlan.free; // expired → downgrade (persisted by settle)
      case PulsePlan.proMonthly:
      case PulsePlan.proYearly:
        // Local-first: assume in good standing until server validation
        // (Phase 6 receipt check) says otherwise.
        return s.plan;
    }
  }

  bool get isPro => effectivePlan().isPro;

  /// Ads show only when the user is NOT on any Pro plan (§61/§62).
  bool get shouldShowAds => !isPro;

  /// Whole days left in trial, clamped at 0. Honest, no fake urgency.
  int trialDaysRemaining() {
    final s = _state();
    if (s.plan != PulsePlan.proTrial || s.trialStartedAt == null) return 0;
    final end = s.trialStartedAt!.add(const Duration(days: PulsePricing.trialDays));
    final diff = end.difference(_now()).inDays;
    return diff < 0 ? 0 : diff + (_now().difference(s.trialStartedAt!).inSeconds % 86400 > 0 ? 0 : 0);
  }

  /// Human-readable trial banner copy (§85 — real microcopy, no lorem).
  String? trialBannerText() {
    final s = _state();
    if (s.plan != PulsePlan.proTrial) return null;
    final end = s.trialStartedAt!.add(const Duration(days: PulsePricing.trialDays));
    final hoursLeft = end.difference(_now()).inHours;
    if (hoursLeft <= 0) return null;
    if (hoursLeft >= 24) {
      final d = (hoursLeft / 24).ceil();
      return '$d day${d == 1 ? '' : 's'} left in your free trial · Cancel anytime';
    }
    return 'Less than a day left in your free trial · Cancel anytime';
  }

  /// Begin a one-shot 3-day trial. Returns false if already used/paid.
  bool beginTrial() {
    final s = _state();
    if (s.trialUsed || s.plan.isPro) return false;
    s.plan = PulsePlan.proTrial;
    s.trialStartedAt = _now();
    s.trialUsed = true;
    return true;
  }

  /// Activate a paid plan (after gateway success).
  void activatePaid(PulsePrice price) {
    final s = _state();
    s.plan = price.cadence == 'year' ? PulsePlan.proYearly : PulsePlan.proMonthly;
    s.periodStart = _now();
    s.periodCadence = price.cadence;
    s.trialUsed = true;
  }

  /// Revert to free immediately (cancel-at-end-of-period is handled by
  /// the store platforms; this models "keep my data, drop Pro now").
  void revertToFree() {
    final s = _state();
    s.plan = PulsePlan.free;
    s.periodStart = null;
    s.periodCadence = null;
  }

  /// Persist transitions (e.g., trial expiry → free). Returns true if changed.
  bool settleExpired() {
    final s = _state();
    final eff = effectivePlan();
    if (eff != s.plan && s.plan == PulsePlan.proTrial) {
      s.plan = PulsePlan.free;
      return true;
    }
    return false;
  }
}

// ── Ad framework seams ───────────────────────────────────────────────
// Deliberately SDK-free: a real build wires Google Mobile Ads (AdMob)
// or AppLovine behind [AdProvider]. Until then the placeholder slot is
// honest ("Advertisement") and never mimics app content.

enum AdSlot { homeFooter, afterDiaryComplete, workoutHistoryFooter, interstitialBetweenTabs }

/// Policy per design brief §61/§62: NEVER interrupt food/water/workout
/// logging, never place ads inside camera/scanner surfaces, frequency
/// cap interstitials. Ads exist only as a visible trade-off of free.
class AdPolicy {
  static const allowedSlots = {AdSlot.homeFooter, AdSlot.afterDiaryComplete, AdSlot.workoutHistoryFooter};
  static const blockedWhile = ['scanning', 'activeWorkout', 'loggingFlow'];
  static const maxInterstitialsPerDay = 1;
}

abstract class AdProvider {
  Future<void> initialize();
  WidgetSlotDescriptor descriptorFor(AdSlot slot);
}

class WidgetSlotDescriptor {
  final AdSlot slot;
  final String label; // always literal 'Advertisement' for transparency
  const WidgetSlotDescriptor(this.slot, this.label);
}

/// Offline/no-fill safe default: renders nothing but keeps layout stable.
class PlaceholderAdProvider implements AdProvider {
  @override
  Future<void> initialize() async {}
  @override
  WidgetSlotDescriptor descriptorFor(AdSlot slot) => const WidgetSlotDescriptor(AdSlot.homeFooter, 'Advertisement');
}

// ── Purchase gateway seam (Phase 6 wires real billing) ───────────────
abstract class PurchaseGateway {
  /// Returns true on successful purchase/trail start confirmation.
  Future<bool> purchase(PulsePrice price);
  Future<bool> restorePurchases();
}

/// Local stub used in dev + tests: succeeds immediately.
class StubPurchaseGateway implements PurchaseGateway {
  bool shouldSucceed;
  StubPurchaseGateway({this.shouldSucceed = true});
  @override
  Future<bool> purchase(PulsePrice price) async => shouldSucceed;
  @override
  Future<bool> restorePurchases() async => shouldSucceed;
}

String encodeSubscription(SubscriptionState s) => jsonEncode(s.toJson());
SubscriptionState decodeSubscription(String raw) =>
    SubscriptionState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
