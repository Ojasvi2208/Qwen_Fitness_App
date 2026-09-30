import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Concrete [AdBackend] over `google_mobile_ads` (§7.3 item 6,
/// brief §61). Loads inventory and reports fill; it makes no decision
/// about *whether* an ad may appear. That stays in [AdPolicy] and
/// [AdMobProvider], where it is testable and cannot be bypassed.
///
/// Note the plugin also needs an application id in AndroidManifest.xml —
/// without it the process dies at startup, before Flutter runs.
/// ═══════════════════════════════════════════════════════════════════

class GoogleMobileAdsBackend implements AdBackend {
  GoogleMobileAdsBackend({MobileAds? ads}) : _ads = ads ?? MobileAds.instance;

  final MobileAds _ads;

  /// Loaded banners by unit id, so a widget can mount one and dispose it.
  final Map<String, BannerAd> loaded = {};

  /// How long to wait for fill before treating it as no-fill. An ad that
  /// never arrives must not hold a card's layout open indefinitely.
  static const _timeout = Duration(seconds: 10);

  @override
  Future<void> initialize() => _ads.initialize();

  @override
  Future<bool> loadBanner(String unitId) {
    final completer = Completer<bool>();
    final banner = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          loaded[unitId] = ad as BannerAd;
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (ad, error) {
          // No fill is an ordinary outcome, not an error worth surfacing:
          // the slot simply renders nothing (§61).
          ad.dispose();
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
    unawaited(banner.load());
    return completer.future
        .timeout(_timeout, onTimeout: () => false);
  }

  /// Releases a loaded banner. The plugin holds native memory per ad, so a
  /// slot that goes away must dispose rather than leak it.
  Future<void> disposeBanner(String unitId) async {
    await loaded.remove(unitId)?.dispose();
  }

  Future<void> disposeAll() async {
    for (final ad in loaded.values) {
      await ad.dispose();
    }
    loaded.clear();
  }
}
