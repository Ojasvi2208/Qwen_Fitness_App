# PULSE / PulseFit — QA findings, round 2

Written for: whoever executes the next session.
Covering 2026-10-01, after the v1 Android build was signed and installed.

Every item below was **found by using the app**, not by the suite. At the time
of writing the suite is 304 passing, the overflow sweep is 160/160 and the
analyzer reports 0 errors — and all five defects here were present anyway.
That is the standing lesson of this project, now proven a fifth time.

---

## Status when these were found

```
flutter analyze   0 errors (11 warnings, ~242 info — all pre-existing)
flutter test      304 passing
sweep             160/160
release APK/AAB   signed with the real keystore, installed and running on
                  the Pixel 7 emulator and the Moto Edge 30
```

---

## V1 — the toast never goes away, and is dark in light theme

**Reported by the owner:** "when I add water it shows a banner in between and
it doesn't go away automatically … even in light theme it still shows dark".

[pulse_components.dart:606](../lib/widgets/pulse_components.dart#L606):

```dart
backgroundColor: scheme.brightness == Brightness.dark
    ? PulseColors.darkElevated
    : const Color(0xFF22302C),
```

Both branches are a dark navy. The light branch is a hardcoded literal that
ignores the scheme entirely, so the toast is dark in both themes **by
construction** — the ternary only looks like it adapts.

The duration is `const Duration(seconds: 3)` on line 604, so a correctly
behaving toast should dismiss itself. Two possibilities, and the next session
must determine which rather than assume:

1. The snack is re-shown on every `notifyListeners()` from the store mutation,
   so it appears to persist while actually being replaced.
2. Something holds the `ScaffoldMessenger` entry open.

**Do not "fix" the duration before reproducing it.** Add water on a device,
watch for 5 seconds, and read what actually happens.

---

## V2 — search tabs 3 and 4 show the wrong list, tab 2 is hardcoded empty

**Reported by the owner:** "search type nothing is showing up".

[logging_screens.dart:26-32](../lib/screens/nutrition/logging_screens.dart#L26):

```dart
var list = PulseData.foods.where(...).toList();
if (_tab == 1) list = list.where((f) => f.frequent).toList();
if (_tab == 2) list = []; // "My Foods" empty state demo (§71)
return list;
```

The TabBar has **five** tabs — Recent, Frequent, My Foods, Meals, Recipes —
and only indices 0, 1 and 2 are handled:

- **Tab 2 "My Foods"** returns `[]` unconditionally. The comment calls it an
  "empty state demo", which is the same class of defect as the fabricated
  screens: a control that depicts a feature it does not have.
- **Tabs 3 "Meals" and 4 "Recipes"** fall through and render the *unfiltered
  food list*, so they silently show the wrong data rather than their own.

`PulseData.savedMeals` and `PulseData.recipes` both exist and are never read
here. Note these are **catalogue** data, not user metrics, so wiring them does
not reintroduce seeded user data.

The text filter itself (`q.isEmpty || f.name.toLowerCase().contains(q)`) is
correct, so if typing shows nothing the cause is the tab, not the query.

---

## V3 — hardcoded colours defeat theming across the app

**Reported by the owner:** "Check everything that should become light with
light theme and dark with dark theme works dynamically nothing hardcoded."

Counted outside `lib/theme/`:

| Pattern | Occurrences |
|---|---|
| `Color(0xFF…)` literals | 23 |
| `Colors.white` / `Colors.black` | 57 |
| **Total** | **80** |

Files affected: `progress_screens.dart`, `today_screen.dart`,
`auth_screens.dart`, `widgets_watch_screen.dart`, `logging_screens.dart`,
`pulse_components.dart`, and `pulse_store.dart`.

**Not all 80 are defects.** Three legitimate categories must be separated
before any mass edit:

1. **Brand constants** — `PulsePalette` in `pulse_store.dart` exists because
   `const` contexts cannot read a theme. These are correct.
2. **Deliberately fixed surfaces** — the widget/watch previews paint a device
   mock that is dark in both themes on purpose, and text on a saturated brand
   fill is legitimately always white.
3. **Genuine defects** — anything that should follow `colorScheme` and does
   not. V1's toast is the proven example.

A blind find-and-replace would break category 2. Audit, classify, then fix.

---

## V4 — `pulseMetaChip` doc comment landed inside PulseScaffold's

[common.dart:72-79](../lib/widgets/common.dart#L72). A helper added this
session was inserted between `PulseScaffold`'s doc comment and its class, so
the file now reads:

```dart
/// Nav/Top — standard screen scaffold with back button & actions.
/// §2.1 — an icon + label pair for a `Wrap` of metadata.
```

Cosmetic, no behaviour change, but it misattributes documentation. One-line
fix: move the scaffold's comment back down to its class.

---

## V5 — the app icon cannot be produced from the supplied asset

`logo/Pulse Fit Branding Board.png` is 1448×1086. The app-icon tile inside it
is roughly **200×300 px** of usable area.

Play Store requires **512×512**; `xxxhdpi` needs 192×192 crisp. Upscaling a
200 px crop to 512 is visibly soft and will read as amateur beside other
listings.

**Blocked on the owner** for one of:

- the source file (Figma / Illustrator / Canva) to export the icon artboard
- a standalone 1024×1024 PNG of the icon alone
- an SVG of the P-monogram

With any of those, every Android density, the adaptive-icon layers, the 512
Play icon and the full iOS set can be generated in one pass.

---

## What is NOT broken, so nobody re-investigates it

- **The app does not crash on the Moto Edge 30.** A "CRASHED" was reported
  during this session and was wrong: the logs read `Fully drawn … +1s28ms`,
  and the process was gone because the owner uninstalled it 300 ms later.
  Both devices run the signed release build cleanly, with zero `RenderFlex`.
- **Signing is real.** The first install on the Moto failed with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match`, which is
  Android refusing the new release key over the old debug one.
- **The energy plan is safe against bad input.** `PulseEnergyPlan` clamps age,
  height and weight and floors calories, so even the 0 kg bug produced a
  survivable plan. The defect was that the app *displayed* 0.0 kg as fact.
