# Next session prompt

Paste everything below the line into a fresh session.

---

Continue the PulseFit Flutter app at
`/Users/ojasvimalik/Desktop/Ojasvi/Projects_Ojasvi/Pulse`.

**Read first, in this order:**
1. `CLAUDE.md` — environment, gate, style rules, idioms
2. `docs/SESSION_HANDOFF.md` — where the last session stopped
3. `docs/QA_FINDINGS_V2.md` — **the five defects you are fixing**, each with
   its cause already located in source
4. `docs/ADMOB_SETUP.md` and `docs/STORE_LISTING.md` — submission state

**State at handoff:** `flutter analyze` 0 errors, `flutter test` 304 passing,
overflow sweep 160/160, signed release APK and AAB built and verified running
on both the Pixel 7 emulator and the Moto Edge 30. `flutter doctor` is fully
green. `main` is current through PR #7.

**This is a utility, not a demo.** Every number the app shows must be one it
actually computed or recorded. Seven screens were wired to a real daily archive
this session on exactly that basis, and three capabilities the app does not
have were removed from the UI rather than faked. Hold that line.

---

## Do these in order. Do not reorder.

### 1. V1 — the water toast (`docs/QA_FINDINGS_V2.md` V1)

Reported: adding water shows a banner that never dismisses and is dark even in
light theme.

The theming half is certain: `lib/widgets/pulse_components.dart:606` picks
`PulseColors.darkElevated` for dark and a hardcoded `Color(0xFF22302C)` for
light — **both dark navy**, so the ternary only looks theme-aware.

The dismissal half is **not diagnosed**. `duration` is already 3 seconds.
**Reproduce it on a device before changing anything** — add water, watch for
five seconds, and find out whether the snack is being re-shown on every
`notifyListeners()` or genuinely held open. Do not "fix" the duration blind.

### 2. V2 — food search tabs

`lib/screens/nutrition/logging_screens.dart:26`. The TabBar has five tabs and
`_results` handles three. Tab 2 returns `[]` with a comment calling it an
"empty state demo"; tabs 3 and 4 fall through to the unfiltered food list, so
they show the wrong data silently.

`PulseData.savedMeals` and `PulseData.recipes` exist and are never read here.
They are **catalogue** data, not user metrics, so wiring them does not
reintroduce seeded user data. The text filter itself is correct.

### 3. V3 — hardcoded colours (the big one)

80 sites outside `lib/theme/`: 23 `Color(0xFF…)` and 57
`Colors.white`/`Colors.black`.

**Classify before you edit. Three categories, and a blind replace breaks the
second:**

1. **Brand constants** — `PulsePalette` in `pulse_store.dart` exists because
   `const` contexts cannot read a `Theme`. Correct as-is.
2. **Deliberately fixed surfaces** — widget/watch previews paint a device mock
   that is dark in both themes on purpose; white text on a saturated brand
   fill is legitimately always white.
3. **Genuine defects** — should follow `colorScheme` and does not. V1's toast
   is the proven example.

Fix category 3 only, and **add a test that pumps a screen in both brightnesses
and asserts the surface colour actually differs** — the suite was 304 green
with this live, so without that test it will regress.

This overlaps Step 3b of the old remediation plan (39 fixed `fontSize:`, 31
hard-coded dimensions, unused `PulseBreakpoints`). Absorbing 3b here is
sensible; say so if you do.

### 4. V4 — one-line comment fix

`lib/widgets/common.dart:72`. A helper added last session landed between
`PulseScaffold`'s doc comment and its class.

### 5. iOS — first build

The toolchain is ready: Xcode licensed, simulators 18.4 and 27.0 installed,
CocoaPods 1.17.0, iPhone 15 pairing wirelessly (no cable needed). `ios/Podfile`
has never been generated.

```bash
flutter build ios --debug --no-codesign
```

That generates the Podfile and resolves pods for three native plugins
(`in_app_purchase`, `google_mobile_ads`, `flutter_local_notifications`).
Expect version conflicts; report them rather than forcing versions.

---

## Non-negotiable

- **The gate at every commit**: 0 analyzer errors, all tests passing, sweep
  still 160/160. Paste real console output; never claim a pass without it.
- **A green suite does not mean the app works.** Proven a fifth time last
  session — 304 tests and 160 renders were green while the toast was
  undismissable, search showed the wrong list, and onboarding accepted a 0 kg
  body. **Launch and use the app before calling any UI work done.**
- Match the original author's style — `CLAUDE.md` has the guide. **Never run
  `dart format`.**
- Never reintroduce seeded user data. Empty states are the pattern.
- Commit messages: plain prose, no `Co-Authored-By`, no mention of any AI tool.

## Traps, in the order you will hit them

- `flutter` is not on `PATH`: `export PATH="$HOME/development/flutter/bin:$PATH"`.
  The old `DEVELOPER_DIR` workaround is **no longer needed** — the Xcode
  licence is signed.
- **The ADB daemon goes stale.** A connected phone vanished from `adb devices`
  *and* `system_profiler` entirely; `adb kill-server && adb start-server`
  brought it back. Do that before concluding a device is unplugged.
- **A missing process is not a crash.** Grep logcat for `Fully drawn` before
  calling one.
- Installing release over debug fails with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE` — uninstall first. That error is proof
  signing works.
- A release build **must** carry
  `--dart-define=PULSE_AD_BANNER_ID=ca-app-pub-2404540193833318/6131499270`
  or it silently ships test ads. Full command in `docs/ADMOB_SETUP.md`.
- `adb screencap` is black on the Moto, fine on the emulator.
- `adb input text` breaks on a literal space — use `%s`.
- Clear app data between onboarding runs: `adb shell pm clear com.pulse.pulse_app`.
- Autosave is debounced: mutate → `flushPendingSave()` → `bootFresh(repo)`.
- `PulseStore()` is zero-arg; `OnboardingScreen` takes a required `step`.
- graphify runs under Python 3.14, not the shell's `python3`.
- The overflow sweep reports *that* a render overflowed and discards *where*.
  To locate one, walk the render tree for horizontal `RenderFlex`es whose
  children exceed their box — that is how six sites were found last session
  after the written plan pointed at the wrong widget.

## Owed by the owner — raise early, do not guess

1. **App icon** — `logo/Pulse Fit Branding Board.png` has only a ~200×300 px
   icon tile; Play needs 512×512. Needs a 1024×1024 PNG, an SVG, or the source
   file. Until then the icon cannot be generated at acceptable quality.
2. **Privacy policy URL** — Play rejects a submission without one.
3. Feature graphic 1024×500 and screenshots.

## Deferred — do not start these

- The trainer feature (workout + diet plan builder, PDF export with digital
  signature, WhatsApp share) is **v1.1**. It is 3–5 days and touches file IO,
  permissions and sharing.
- Health Connect, barcode scanning and photo file IO are **cut from v1** and
  the UI no longer claims them.
- AI features stay stubbed.

At the end of the session: update `claude-mem`, run
`/opt/homebrew/opt/python@3.14/bin/python3.14 -m graphify update .`, and
refresh `docs/SESSION_HANDOFF.md` and this prompt.
