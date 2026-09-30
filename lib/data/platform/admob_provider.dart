import '../monetization.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 6 — Real ads adapter (§7.3 item 6, brief §61).
/// Implements [AdProvider]. Every banner still renders through the
/// AdBanner widget, so [AdPolicy] cannot be bypassed by this adapter —
/// slot eligibility and the one-interstitial-a-day rule stay client-side
/// where they can be reasoned about.
///
/// Unit ids come from [AdUnitIds], which defaults to Google's documented
/// test ids. Real ids arrive via --dart-define so a debug build can never
/// accidentally serve production inventory.
/// ═══════════════════════════════════════════════════════════════════

/// Ad unit ids per slot. Test ids are the default on purpose: shipping a
/// build that forgot to pass real ids shows test inventory rather than
/// billing a real advertiser.
class AdUnitIds {
  const AdUnitIds({required this.banner});

  /// Google's published Android test banner id.
  static const kTestBanner = 'ca-app-pub-3940256099942544/6300978111';

  final String banner;

  static const test = AdUnitIds(banner: kTestBanner);

  /// Reads `--dart-define=PULSE_AD_BANNER_ID=…`, falling back to the test id.
  /// An empty define is treated as absent rather than shipped as a blank id.
  static AdUnitIds fromEnvironment() {
    const banner = String.fromEnvironment('PULSE_AD_BANNER_ID',
        defaultValue: kTestBanner);
    return banner.isEmpty ? test : const AdUnitIds(banner: banner);
  }

  bool get isTestInventory => banner == kTestBanner;
}

/// The slice of `google_mobile_ads` this app needs, behind a seam so the
/// policy logic is testable without the plugin or a platform toolchain.
abstract class AdBackend {
  Future<void> initialize();

  /// Loads a banner for [unitId]. Returns false on no-fill, which is a
  /// normal outcome and must never surface as an error to the user.
  Future<bool> loadBanner(String unitId);
}

class AdMobProvider implements AdProvider {
  AdMobProvider({required AdBackend backend, AdUnitIds? units})
      : _backend = backend,
        units = units ?? AdUnitIds.test;

  final AdBackend _backend;
  final AdUnitIds units;

  bool _ready = false;
  bool get isReady => _ready;

  /// Slots that reported no fill. The widget renders nothing for these
  /// rather than reserving empty space.
  final Set<AdSlot> unfilled = <AdSlot>{};

  @override
  Future<void> initialize() async {
    await _backend.initialize();
    _ready = true;
  }

  @override
  WidgetSlotDescriptor descriptorFor(AdSlot slot) =>
      // The label stays the literal 'Advertisement' for transparency (§61):
      // a user must always be able to tell paid placement from content.
      WidgetSlotDescriptor(slot, 'Advertisement');

  /// Requests inventory for a slot the policy has already allowed. Returns
  /// false when the slot is not eligible, so a caller cannot use this to
  /// route around [AdPolicy].
  Future<bool> requestBanner(AdSlot slot) async {
    if (!AdPolicy.allowedSlots.contains(slot)) return false;
    if (!_ready) return false;
    final filled = await _backend.loadBanner(units.banner);
    if (filled) {
      unfilled.remove(slot);
    } else {
      unfilled.add(slot);
    }
    return filled;
  }
}
