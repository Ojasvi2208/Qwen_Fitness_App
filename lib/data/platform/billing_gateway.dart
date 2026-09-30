import '../monetization.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Real billing adapter (§7.3 item 5, brief §62/§63).
/// Implements the existing [PurchaseGateway] seam so nothing upstream
/// changes: the store still calls purchase()/restorePurchases() and
/// still owns entitlement state.
///
/// The `in_app_purchase` plugin is reached through [BillingBackend]
/// rather than directly, for two reasons: the plugin needs a platform
/// toolchain that CI and unit tests do not have, and the store-side
/// logic is worth testing without one. Production wires
/// [InAppPurchaseBackend]; tests pass a fake.
/// ═══════════════════════════════════════════════════════════════════

/// One purchase as the platform reports it. Deliberately not the
/// plugin's type — this file is the only place that knows about it.
class BillingPurchase {
  const BillingPurchase({
    required this.productId,
    required this.purchased,
    this.transactionDate,
    this.error,
  });

  final String productId;
  final bool purchased;

  /// Platform-supplied purchase time. §63 known limitation: trial expiry
  /// derived from the local clock can be manipulated, so when the platform
  /// reports a date it is preferred over DateTime.now().
  final DateTime? transactionDate;
  final String? error;

  bool get succeeded => purchased && error == null;
}

/// The narrow slice of `in_app_purchase` this app needs.
abstract class BillingBackend {
  Future<bool> isAvailable();
  Future<BillingPurchase> buyNonConsumable(String productId);
  Future<List<BillingPurchase>> queryPastPurchases();
}

/// Store-facing gateway. Keeps [StubPurchaseGateway]'s contract exactly.
class InAppPurchaseGateway implements PurchaseGateway {
  InAppPurchaseGateway({required BillingBackend backend}) : _backend = backend;

  final BillingBackend _backend;

  /// Platform-reported date of the most recent successful purchase, for the
  /// store to prefer over the local clock when settling trial expiry (§63).
  DateTime? lastPurchaseDate;

  @override
  Future<bool> purchase(PulsePrice price) async {
    // An unavailable store is a normal condition, not an error: the user
    // keeps every local feature and simply cannot upgrade right now.
    if (!await _backend.isAvailable()) return false;
    final result = await _backend.buyNonConsumable(price.id);
    if (!result.succeeded) return false;
    lastPurchaseDate = result.transactionDate;
    return true;
  }

  @override
  Future<bool> restorePurchases() async {
    if (!await _backend.isAvailable()) return false;
    final past = await _backend.queryPastPurchases();
    final live = past.where((p) => p.succeeded).toList();
    if (live.isEmpty) return false;
    // Most recent wins: a yearly bought after a monthly is the live plan.
    live.sort((a, b) => (b.transactionDate ?? DateTime(0))
        .compareTo(a.transactionDate ?? DateTime(0)));
    lastPurchaseDate = live.first.transactionDate;
    return true;
  }

  /// Maps a platform product id back to the price it represents, so a
  /// restore can reinstate the right plan. Returns null for ids this build
  /// does not sell.
  static PulsePrice? priceFor(String productId) => switch (productId) {
        'pulse_pro_monthly' => PulsePricing.monthly,
        'pulse_pro_yearly' => PulsePricing.yearly,
        _ => null,
      };
}
