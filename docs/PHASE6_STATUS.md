# PULSE — Phase 6 status

Phase 6 is the release-preparation phase: every item is a platform integration
(release doc §7.3). This file records what has been built, and — more
importantly — **what has not been verified and why**.

Last updated: 2026-10-01

## Toolchain

**Android is installed and green.** Command-line tools, platform 36 and
build-tools 36.0.0 via Homebrew and `sdkmanager`; `ANDROID_HOME` is set in
`~/.zshrc`. A Pixel 7 AVD (`pulse_pixel7`, API 36, **Play Store** image — Ads
and In-App Purchase need Play Services) runs the app.

**Xcode is not installed**, and cannot be from a terminal: it is App Store only
and needs an Apple ID, a GUI and `sudo xcode-select`. Everything iOS —
StoreKit, HealthKit, APNs — is therefore unverified.

The three plugins are declared in `pubspec.yaml` and compile into the APK. The
app builds, installs and runs on the emulator.

## What exists

| Item | File | State |
|---|---|---|
| Billing | [lib/data/platform/billing_gateway.dart](../lib/data/platform/billing_gateway.dart) | adapter + 7 tests |
| Ads | [lib/data/platform/admob_provider.dart](../lib/data/platform/admob_provider.dart) | adapter + 6 tests |
| Notifications | [lib/data/platform/local_notification_scheduler.dart](../lib/data/platform/local_notification_scheduler.dart) | adapter + 10 tests |

Each implements an interface that already existed — `PurchaseGateway`,
`AdProvider`, `ReminderScheduler` — so nothing upstream changed. The stubs
remain the defaults, which is why all 224 tests pass without a toolchain.

### Design: a backend seam per plugin

Every adapter reaches its plugin through a second, narrower interface
(`BillingBackend`, `AdBackend`, `NotificationBackend`) holding only the few
calls this app needs. That is what makes the app-side rules testable:

- **Billing** prefers the platform-supplied transaction date over
  `DateTime.now()`, which is the §63 mitigation for a manipulable local clock.
  An unavailable store returns false rather than throwing — a user who cannot
  reach the store keeps every local feature.
- **Ads** refuses any slot absent from `AdPolicy.allowedSlots` *before* calling
  the backend, so the adapter cannot be used to route around policy. Unit ids
  default to Google's published test ids; real ids arrive by `--dart-define`, so
  a build that forgets them shows test inventory instead of billing an
  advertiser. No fill is recorded, never surfaced as an error.
- **Notifications** expand one reminder into one notification for a daily
  repeat or one per selected weekday otherwise, deferring to
  `Reminder.firesOn` so repeat semantics live in one place. `sync` is a full
  replace, not a diff — an exact mirror of the book is easier to trust. A
  refused permission cancels everything and returns; reminders stay in the book
  and simply do not fire, per §58.

## What the toolchain proved

Making a build possible immediately exposed five defects that `analyze` and
`test` are structurally blind to. Four were in the Android scaffold, unchanged
since the project was generated, and one only appears at runtime:

| Defect | Was | Now |
|---|---|---|
| Gradle incompatible with Java 21, below Flutter's minimum 8.14.0 | 8.3 | 8.14.3 |
| Android Gradle Plugin below the required 8.11.1 | 8.1.0 | 8.11.1 |
| Kotlin below the required 2.2.20 | 1.8.22 | 2.2.20 |
| `flutter_local_notifications` needs core library desugaring (`java.time`) | off | enabled, Java 8 → 11 |
| `google_mobile_ads` crashes at process start without an AdMob app id | missing | test id in the manifest |

The last one is worth dwelling on: the APK built and installed cleanly, the
suite passed 224/224, and the app still died before rendering a frame. Only
launching it revealed that.

Running on the emulator also confirmed the §14 launch gate on a real device:
the app opens on the welcome screen, not a dashboard, because `hasProfile` is
false on a fresh install — exactly what `state_matrix_test` asserts.

## What is NOT verified

Stated plainly, because the distinction still matters:

- **No real purchase, ad impression, notification or health read has occurred.**
  Every adapter test runs against a hand-written fake. The plugins compile and
  the app runs; their behaviour is not yet exercised.
- **Nothing on iOS.** No CocoaPods install, no simulator build, no StoreKit.
- Store-console work is **untouched**: Play Billing and App Store product
  configuration, a real AdMob account, APNs entitlements, and the Android 13+
  POST_NOTIFICATIONS runtime permission flow.
- The AdMob ids in the manifest and in `AdUnitIds` are Google's **test** ids. A
  release build must override both.

## Remaining Phase 6 items (§7.3)

Not started, all requiring a toolchain:

- **Health integrations** (item 8) — HealthKit and Health Connect readers
  feeding steps and workouts. `stepsToday` is currently only ever set locally.
- **Camera** (item 9) — `mobile_scanner` barcode capture with the manual-entry
  fallback that is already designed.
- **Progress photo file IO** (item 10) — `path_provider` writing, atomic with
  the existing metadata book.
- **Platform config** (item 11) — bundle ids, signing, privacy strings,
  ProGuard rules, minSdk 23, iOS 15.
- **Flavors, deep links, legal pages** (items 12–14).

## Running it

```bash
emulator -avd pulse_pixel7 -no-snapshot-save -no-boot-anim &
adb wait-for-device
flutter run                     # or: flutter build apk --debug && adb install -r …
```

## Next

1. Implement the concrete backends — `InAppPurchaseBackend`,
   `GoogleMobileAdsBackend`, `FlutterLocalNotificationsBackend` — as thin
   translations of the plugin APIs. The adapters and their tests do not change.
2. Wire them in `main.dart` behind a flavor or `--dart-define`, keeping the
   stubs as the default for tests.
3. Exercise each on the emulator: a test-inventory banner, a scheduled
   notification, a Play Billing test purchase.
4. Install Xcode when iOS matters, then repeat for StoreKit and HealthKit.
5. Only claim verified what has actually been observed running.
