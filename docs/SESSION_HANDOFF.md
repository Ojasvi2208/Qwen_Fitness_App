# PULSE — session handoff

Written for: whoever picks this up next, human or agent.
Covering the session of 2026-10-01.

## Start here

1. [CLAUDE.md](../CLAUDE.md) — environment, style rules, gate, idioms
2. [docs/PHASE7_REMEDIATION_PLAN.md](PHASE7_REMEDIATION_PLAN.md) — **the next
   thing to do**, written this session against what was actually found
3. [docs/QA_FINDINGS.md](QA_FINDINGS.md) — the evidence behind that plan
4. [docs/PHASE7_QA_AUTOMATION_PLAN.md](PHASE7_QA_AUTOMATION_PLAN.md) — the
   governing plan; the remediation plan sits under it, not beside it

## Where things stand

```
flutter analyze  →  0 errors (13 warnings, all pre-existing)
flutter test     →  273 passing, 160 skipped
```

The 160 skipped are the golden sweep, deliberately excluded from the default
run — see "The golden sweep" below. **25 commits on `master`, 7 unpushed.**

| Phase | State |
|---|---|
| 1–5 | complete |
| 6 | partial — adapters written and wired; Android builds and runs; nothing platform-verified; no iOS |
| 7 | **Steps 1 and 2 complete**, Step 3 not started |

## What was done this session

**Step 1 — five defects fixed**, each with a regression case in
[test/ui_fit_test.dart](../test/ui_fit_test.dart) that sizes the surface to a
real device *before* pumping:

- **D1** avatar read "AM" beside the real name — `initials` is now required so
  no stale default can outlive its data
- **D2** centre FAB covered the Train tab — `endFloat`
- **D3** Quick Log sheet overflowed by 176 px — opens tall, list scrolls
- **D4** `POST_NOTIFICATIONS` missing from the manifest
- **D6** *(new)* `MacroRow` overflowed by 62 px — found by the first test
  written at 360 px, before any harness existed

**C1/C4 — fabricated data**, scoped with the owner to what a user cannot avoid
seeing: real dates everywhere, Today's invented week removed, the Train hero
reads its template, two fake charts became empty states.

**Step 2 — the golden harness**
([test/golden/](../test/golden/)). 16 screens × the §2.1 device matrix.
**It found 43 failing renders across 9 sites (O1–O9)**, all logged as the Step 3
scope. That is the harness doing its job.

**N3 — the daily plan is now computed.** Onboarding showed "Built from your
answers" over constants; no BMR/TDEE logic existed anywhere. Added
[lib/data/energy_plan.dart](../lib/data/energy_plan.dart): Mifflin-St Jeor,
activity factor, and the deficit each pace option already promises. Verified on
device — a 42 y/o woman, 162 cm, 62 kg → 1262 kcal / 99 g / 131 g / 38 g,
persisted to disk, with an honest line when the safety floor caps the pace.

## Do this next

**Step 3, in the order [PHASE7_REMEDIATION_PLAN.md](PHASE7_REMEDIATION_PLAN.md)
sets out.** Do not reorder it.

The one thing to get right: **O6 first and alone.** It is the shared
`PrimaryButton`, so fixing it may clear failures currently counted against
other screens. Re-run the sweep and re-count before touching anything else, or
you will fix sites that were already green.

```bash
flutter test --run-skipped test/golden    # 117/160 passing today
```

Baseline to beat: **117 of 160.** The count must go up, never down.

## Decisions still owed by the owner

| Item | Decision |
|---|---|
| 8 fabricated screens | Store-wire or empty-state each — see QA_FINDINGS §3 |
| N1 | The onboarding "Enable Notifications" button is a stub showing "System permission dialog would appear here" and can grant nothing. Wire it or remove it |
| Goldens | Images deliberately uncommitted; blocked on the two above |

## Traps that cost time, in the order you will hit them

- **A green suite does not mean the app works.** It has missed a startup crash,
  a permanent spinner and three keyboard failures here. Launch it.
- `flutter` is **not on `PATH`** in a fresh shell on this machine. Every
  command needs `export PATH="$HOME/development/flutter/bin:$PATH"` first.
- **Never run `dart format`** on this codebase. It reflows the author's dense
  style into something unrecognisable — 182 lines changed in one file. Edit by
  hand.
- **Clear app data between onboarding runs** (`adb shell pm clear
  com.pulse.pulse_app`). A prior install's snapshot hydrates into what looks
  like a fresh profile; this cost a full investigation (QA_FINDINGS N2).
- `adb input text` **breaks on a literal space** — use `%s`.
- `adb screencap` returns black frames on the Moto Edge 30; it works on the
  emulator. Use the `integration_test` screenshot API for Step 4.
- Autosave is debounced: mutate → `await store.flushPendingSave()` →
  `bootFresh(repo)`.
- `PulseStore()` is zero-arg; persistence attaches via `attachPersistence`.
  `PulseApp` takes `store`, not `initialRoute` — host `PulseShell` directly.
- In zsh, `D="-s emulator-5554"; adb $D ...` does **not** expand. Write the
  flag out in full.
- graphify runs under Python 3.14, not the shell's `python3` (3.11).

## Knowledge graph

Current as of this session: **1776 nodes, 2243 edges, 91 communities** (was
1630/2065/83). `energy_plan.dart`, `pulseInitials` and the `fmt*` date helpers
are all indexed. Gitignored; regenerate with:

```bash
/opt/homebrew/opt/python@3.14/bin/python3.14 -m graphify update .
```

Two `Contents.json` warnings are Xcode asset stubs, not source. Harmless.

## Still outstanding

- **PR into `main`.** `master` is 7 commits ahead and `gh` is not
  authenticated, so this needs a browser or `gh auth login`:
  https://github.com/Ojasvi2208/Qwen_Fitness_App/compare/main...master
- **C6** — 13 warnings, ~239 info lints, all pre-existing. Own commit.
- **C7** — `android/app/build.gradle` still signs release with the debug key
  and carries the generated `applicationId`. Blocks a real release.
- **Phase 6 remainder** — health, camera, photo IO, signing, flavors, deep
  links, legal pages. iOS needs Xcode, which is not installed.
