import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_gateway.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Concrete [BillingBackend] over `in_app_purchase` (§7.3
/// item 5). A thin translation only: every rule about what a purchase
/// means lives in [InAppPurchaseGateway] and the store, which is what
/// keeps those testable without a store connection.
/// ═══════════════════════════════════════════════════════════════════

class InAppPurchaseBackend implements BillingBackend {
  InAppPurchaseBackend({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {
      // A stream error means the platform gave up on the connection; any
      // request still waiting resolves as "not purchased" rather than hanging.
      _settleAll(const []);
    });
  }

  final InAppPurchase _iap;
  late final StreamSubscription<List<PurchaseDetails>> _sub;

  /// Requests awaiting a stream callback, keyed by product id. The plugin
  /// reports the *outcome* asynchronously — buyNonConsumable only says the
  /// request was sent — so a purchase is not complete when that returns.
  final Map<String, Completer<BillingPurchase>> _pending = {};

  /// How long to wait for the platform before reporting failure. Without it
  /// a dismissed sheet that emits nothing would leave the UI waiting forever.
  static const _timeout = Duration(minutes: 3);

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<BillingPurchase> buyNonConsumable(String productId) async {
    final response = await _iap.queryProductDetails({productId});
    final details =
        response.productDetails.where((p) => p.id == productId).firstOrNull;
    if (details == null) {
      // The id is not configured in the store console, which is a setup
      // problem rather than a user-facing failure.
      return BillingPurchase(
          productId: productId,
          purchased: false,
          error: 'product not found in store');
    }

    final completer = Completer<BillingPurchase>();
    _pending[productId] = completer;
    final sent = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details));
    if (!sent) {
      _pending.remove(productId);
      return BillingPurchase(
          productId: productId, purchased: false, error: 'request rejected');
    }
    return completer.future.timeout(_timeout, onTimeout: () {
      _pending.remove(productId);
      return BillingPurchase(
          productId: productId, purchased: false, error: 'timed out');
    });
  }

  @override
  Future<List<BillingPurchase>> queryPastPurchases() async {
    final restored = <BillingPurchase>[];
    final sub = _iap.purchaseStream.listen((updates) {
      for (final p in updates) {
        if (p.status == PurchaseStatus.restored) restored.add(_map(p));
      }
    });
    await _iap.restorePurchases();
    // The platform replays past purchases onto the same stream, so give it a
    // moment to drain before reporting what came back.
    await Future<void>.delayed(const Duration(seconds: 2));
    await sub.cancel();
    return restored;
  }

  void _onPurchases(List<PurchaseDetails> updates) {
    for (final p in updates) {
      // Pending is an interim state; the outcome arrives in a later event.
      if (p.status == PurchaseStatus.pending) continue;
      // Every terminal purchase must be completed or the platform will keep
      // redelivering it on each launch.
      if (p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
      _pending.remove(p.productID)?.complete(_map(p));
    }
  }

  void _settleAll(List<PurchaseDetails> _) {
    for (final entry in _pending.entries) {
      entry.value.complete(BillingPurchase(
          productId: entry.key, purchased: false, error: 'connection lost'));
    }
    _pending.clear();
  }

  BillingPurchase _map(PurchaseDetails p) => BillingPurchase(
        productId: p.productID,
        purchased: p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored,
        // Platform-supplied epoch milliseconds, preferred over the local
        // clock when settling trial expiry (§63).
        transactionDate: _parseDate(p.transactionDate),
        error: p.error?.message,
      );

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.tryParse(raw);
  }

  Future<void> dispose() => _sub.cancel();
}
