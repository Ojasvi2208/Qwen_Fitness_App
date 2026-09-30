# PULSE — Phase 6 status

Phase 6 is the release-preparation phase: every item is a platform integration
(release doc §7.3). This file records what has been built, and — more
importantly — **what has not been verified and why**.

Last updated: 2026-10-01

## The constraint

Neither Xcode nor the Android SDK is installed on the machine this work was done
on. `flutter doctor` is green for Flutter, Chrome and network only.

Phase 5 was unaffected: `flutter analyze` and `flutter test` are headless. Phase
6 is not. Adding `in_app_purchase` or `google_mobile_ads` to `pubspec.yaml`
triggers a CocoaPods install on iOS and a Gradle sync on Android, neither of
which can run here.

**So the plugins are deliberately not yet in `pubspec.yaml`.** The adapters are
written against narrow backend seams instead, which keeps the app building, the
suite green and the app-side logic genuinely tested. Wiring the real plugin is
then a small, well-defined change.

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

## What is NOT verified

Stated plainly, because the distinction matters:

- **No real purchase, ad impression, notification or health read has occurred.**
  Every test above runs against a hand-written fake.
- The plugins are **not** in `pubspec.yaml`, so native dependency resolution is
  untested.
- No device or simulator build has been attempted.
- StoreKit and Play Billing product configuration, AdMob account setup, APNs
  entitlements and Android 13+ POST_NOTIFICATIONS runtime flow are all
  **untouched** — they are console and platform work, not code.

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

## Next session

1. Install Xcode **or** Android Studio and get `flutter doctor` green for one.
2. Add the three plugins to `pubspec.yaml`, then `flutter pub get`.
3. Implement the concrete backends — `InAppPurchaseBackend`,
   `GoogleMobileAdsBackend`, `FlutterLocalNotificationsBackend` — as thin
   translations. The adapters and their tests do not change.
4. Wire them in `main.dart` behind a flavor or `--dart-define`, keeping the
   stubs for tests.
5. Only then claim any of this verified.
