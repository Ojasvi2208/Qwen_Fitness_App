import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/theme/pulse_theme.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 7 — Golden harness device matrix (§2.1).
/// Hand-rolled rather than golden_toolkit: this project carries no test
/// dependencies beyond flutter_test and writes its own doubles, so a
/// package is not worth the lock-file churn for one Size and one DPR.
/// ═══════════════════════════════════════════════════════════════════

/// One entry of the §2.1 matrix. [logical] is what the widget tree sees;
/// [dpr] only affects golden pixel dimensions, never layout.
class PulseDeviceProfile {
  const PulseDeviceProfile({
    required this.name,
    required this.logical,
    required this.dpr,
    required this.why,
  });

  final String name;
  final Size logical;
  final double dpr;

  /// Why this profile earns its place — each one multiplies run time.
  final String why;

  @override
  String toString() => name;
}

// Each profile is named so a render case can reference it as a constant;
// a const list cannot be indexed in a const expression.

const kPhoneSmall = PulseDeviceProfile(
    name: 'phone_small', logical: Size(320, 568), dpr: 2.0,
    why: 'smallest realistic Android — first to overflow');

const kPhoneMoto = PulseDeviceProfile(
    name: 'phone_moto', logical: Size(360, 800), dpr: 2.5,
    why: 'the reported device: Moto Edge 30, 1080x2400 at 400dpi');

const kPhonePixel7 = PulseDeviceProfile(
    name: 'phone_pixel7', logical: Size(412, 915), dpr: 2.625,
    why: 'the emulator already in use');

const kPhoneLarge = PulseDeviceProfile(
    name: 'phone_large', logical: Size(480, 1067), dpr: 3.0,
    why: 'large-phone upper bound');

const kTablet = PulseDeviceProfile(
    name: 'tablet', logical: Size(768, 1024), dpr: 2.0,
    why: '§7.4 QA matrix requires a tablet');

/// The §2.1 matrix. Deliberately five entries: the smallest realistic
/// Android, the device the defects were reported on, the emulator in use,
/// a large-phone bound, and the tablet §7.4 requires.
const kPulseDevices = <PulseDeviceProfile>[
  kPhoneSmall, kPhoneMoto, kPhonePixel7, kPhoneLarge, kTablet,
];

/// One render of the §2.1 pruned cross-product: a device, a text scale and
/// a theme. The full 5x3x2 is 30 renders per screen; §2.1 prunes to 8.
class PulseRenderCase {
  const PulseRenderCase({
    required this.device,
    this.textScale = 1.0,
    this.dark = false,
  });

  final PulseDeviceProfile device;
  final double textScale;
  final bool dark;

  /// Stable golden filename segment: `phone_moto_t15_light`.
  String get id => '${device.name}'
      '_t${(textScale * 10).round()}'
      '_${dark ? 'dark' : 'light'}';

  @override
  String toString() => id;
}

/// The pruned §2.1 matrix: 8 renders per screen, not 30.
/// - all five sizes at textScale 1.0 light (the fit baseline)
/// - phone_moto and phone_small at 1.5 (accessibility stress)
/// - phone_moto dark (theme parity)
const kPulseRenderCases = <PulseRenderCase>[
  PulseRenderCase(device: kPhoneSmall),
  PulseRenderCase(device: kPhoneMoto),
  PulseRenderCase(device: kPhonePixel7),
  PulseRenderCase(device: kPhoneLarge),
  PulseRenderCase(device: kTablet),
  PulseRenderCase(device: kPhoneMoto, textScale: 1.5),
  PulseRenderCase(device: kPhoneSmall, textScale: 1.5),
  PulseRenderCase(device: kPhoneMoto, dark: true),
];

/// Sizes the test surface to [c] and restores it afterwards. The 800x600
/// default is wider and shorter than any phone, which is precisely why it
/// hid five overflow defects from 235 passing cases.
void pulseApplyRenderCase(WidgetTester tester, PulseRenderCase c) {
  tester.view.physicalSize = c.device.logical * c.device.dpr;
  tester.view.devicePixelRatio = c.device.dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Wraps [child] in the app's own theme and store scope at the text scale
/// and brightness of [c]. Screens read the store, so a caller that wants
/// the empty-state path passes a bare `PulseStore()`.
Widget pulseHarness({
  required PulseStore store,
  required Widget child,
  required PulseRenderCase renderCase,
  Map<String, WidgetBuilder>? routes,
}) =>
    PulseScope(
      store: store,
      child: MaterialApp(
        theme: renderCase.dark ? PulseTheme.dark() : PulseTheme.light(),
        routes: routes ?? const {},
        builder: (ctx, w) => MediaQuery.withClampedTextScaling(
          minScaleFactor: renderCase.textScale,
          maxScaleFactor: renderCase.textScale,
          child: w!,
        ),
        home: child,
      ),
    );

/// A store with a profile but nothing logged — the state a real user is in
/// for their first session, and the one the removed sample data used to
/// paper over. Never seed logged data here: see [[pulse-no-sample-data]].
PulseStore pulseProfiledStore() {
  final store = PulseStore();
  store.userName = 'Ojasvi Malik';
  store.userFirstName = 'Ojasvi';
  return store;
}
