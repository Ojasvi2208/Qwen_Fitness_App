# PulseFit — session handoff

Written for: whoever picks this up next, human or agent.
Covering the session of 2026-10-01 (the long one: Phase 7 Step 3 through a
signed, device-verified Android release).

## Start here

1. [CLAUDE.md](../CLAUDE.md) — environment, gate, style rules, idioms
2. [docs/QA_FINDINGS_V2.md](QA_FINDINGS_V2.md) — **the five defects to fix
   next**, each with its cause located in source
3. [docs/NEXT_SESSION_PROMPT.md](NEXT_SESSION_PROMPT.md) — the prompt to paste
4. [docs/ADMOB_SETUP.md](ADMOB_SETUP.md) · [docs/STORE_LISTING.md](STORE_LISTING.md)

## Where things stand

```
flutter analyze   0 errors (11 warnings, ~242 info — all pre-existing)
flutter test      304 passing
sweep             160/160          (117/160 at session start)
release APK       60.3 MB, signed CN=PULSE
release AAB       58 MB, Play upload format
verified on       Pixel 7 emulator AND Moto Edge 30, release build, 0 crashes
flutter doctor    all green, including Xcode
```

**App is named PulseFit.** It was shipping as `pulse_app`, the Flutter template
default — the name a user would have seen under the icon.

`main` is current through PR #7. Everything below is pushed except the final
docs commit.

## What was done

**Phase 7 Step 3 — the overflow sweep closed, 117 → 160/160.** Six fixes. Two
were shared components that cleared far more than their own row: the
`PulseScaffold` app bar (all nine Goals failures) and `PrimaryButton` (nine
across four screens). The plan's site list was partly wrong — O1/O2 were
recorded as a `ListTile` defect and rewriting that tile changed nothing. The
real sites were found with a throwaway probe that walks the render tree for
horizontal `RenderFlex`es whose children exceed their box, because the sweep
reports *that* an overflow happened and discards *where*.

**The daily archive** ([day_archive.dart](../lib/data/day_archive.dart)) — the
history seven screens were inventing. One `DayRecord` per calendar day, bounded
to 92 days, filled by `rolloverIfNeeded` on boot and resume. Wiring it exposed
a defect nothing else would have: **the daily scalars were never reset**, so
`stepsToday` accumulated across calendar days forever.

**Seven fabricated screens wired** to real data, and the three capabilities v1
does not ship (Health Connect, barcode scanning, photo file IO) no longer
claimed anywhere — including a paywall row that sold Pro on barcode scanning.

**N1 resolved** — the onboarding notification button called a seam that already
existed and was unused. Verified on device: real dialog, `granted=true` in
`dumpsys`, button settles to "Notifications enabled".

**C7 resolved** — release signing, keystore outside the repo. First release
build this project has ever had.

**AdMob wired** per build type: real ids in release, Google's test ids in
debug, verified by reading both artifacts back.

**Three onboarding defects** found by walking the release build: Continue
advanced past an empty details step (storing 0 kg and printing "CURRENT WEIGHT
0.0 kg" as fact), the system back gesture discarded all nine steps, and
`MetricStat` overflowed once a form had content.

## Do this next

**[docs/QA_FINDINGS_V2.md](QA_FINDINGS_V2.md), in order.** Five items, all
found by the owner using the app:

| | Item | Shape |
|---|---|---|
| V1 | Water toast never dismisses, dark in light theme | `pulse_components.dart:606` — both ternary branches are dark navy |
| V2 | Search tabs 3/4 show the wrong list, tab 2 hardcoded `[]` | `logging_screens.dart:26` — five tabs, three handled |
| V3 | 80 hardcoded colour sites defeat theming | three categories; **never mass-replace** |
| V4 | `pulseMetaChip` doc comment inside `PulseScaffold`'s | `common.dart:72` |
| V5 | App icon cannot be produced from the supplied board | blocked on the owner |

Then **iOS**: the toolchain is ready for the first `flutter build ios`.

## Decisions already taken — do not reopen

| Decision | Outcome |
|---|---|
| Trainer feature (plan builder, PDF, signature, WhatsApp) | **v1.1**, not v1 — 3–5 days, touches file IO and sharing |
| Health Connect, barcode, photo IO | **cut from v1**, UI no longer claims them |
| Ads | real ids wired; AdMob app review clears only once live on Play |
| AI features | stay stubbed, explicitly not required |
| Deadline | moved to **day after**, both platforms |

## Blocked on the owner

- **App icon** — the branding board's tile is ~200×300 px; Play needs 512×512.
  Send a 1024×1024 PNG, an SVG, or the source file.
- **Privacy policy URL** — Play rejects a submission without one.
- Feature graphic 1024×500, screenshots.
- AdMob payments profile (address PIN, 2–4 weeks in India).

## Traps, in the order you will hit them

- **A green suite does not mean the app works.** Proven a *fifth* time this
  session: 304 tests and 160/160 renders were green while the toast was
  undismissable, search tabs showed the wrong list, and onboarding accepted a
  0 kg body. Every one was found by using the app.
- **`flutter` is not on `PATH`** — `export PATH="$HOME/development/flutter/bin:$PATH"`.
  The `DEVELOPER_DIR` workaround is **no longer needed**; the Xcode licence is
  signed.
- **The ADB daemon goes stale.** The Moto vanished from `adb devices` and from
  `system_profiler` entirely; `adb kill-server && adb start-server` brought it
  back. Do that before concluding a device is unplugged.
- **A missing process is not a crash.** Read `logcat` for `Fully drawn` before
  calling one — a "crash" this session was the owner uninstalling the app.
- Release over debug install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`;
  uninstall first. That error is *proof signing works*.
- **Never run `dart format`** — reflows the author's dense style.
- `adb screencap` is black on the Moto, fine on the emulator.
- `adb input text` breaks on a literal space — use `%s`.
- Autosave is debounced: mutate → `flushPendingSave()` → `bootFresh(repo)`.
- `PulseStore()` is zero-arg; `OnboardingScreen` takes a required `step`.
- graphify runs under Python 3.14, not the shell's `python3`.

## Knowledge graph

**1850 nodes, 2320 edges, 96 communities** (was 1776/2243/91). Gitignored:

```bash
/opt/homebrew/opt/python@3.14/bin/python3.14 -m graphify update .
```

## Still outstanding

- **C6** — 11 warnings, ~242 info lints, all pre-existing. Own commit.
- **Steps 3b/3c** — 39 fixed `fontSize:`, 31 hard-coded dimensions, unused
  `PulseBreakpoints`; C2 magic numbers, C3 duplicated literals, C5
  force-unwraps. V3 overlaps 3b and should probably absorb it.
- **Steps 4–6** — integration suite, Tier 1–3 cases, final report.
- **Goldens** — still uncommitted. The fabricated screens and N1 are resolved,
  so the only blocker left is agreeing the reference images.
