# Master prompt — next session

Paste this as the opening message of the next session.

---

Continue the PULSE Flutter app at
`/Users/ojasvimalik/Desktop/Ojasvi/Projects_Ojasvi/Pulse`.

**Read first, in this order:**
1. `CLAUDE.md` — environment, gate, style rules, idioms
2. `docs/SESSION_HANDOFF.md` — where the last session stopped
3. `docs/PHASE7_REMEDIATION_PLAN.md` — **the plan you are executing**
4. `docs/QA_FINDINGS.md` — the evidence behind it

State at handoff: `flutter analyze` 0 errors, `flutter test` 273 passing and
160 skipped, Android toolchain green, Pixel 7 emulator working, 25 commits on
`master` of which 7 are unpushed. Phase 7 Steps 1 and 2 are complete; Step 3
has not started.

**This is a utility, not a demo.** The guiding standard all session has been
that every number the app shows must be one it actually computed or recorded.
Four defects were fixed on exactly that basis, and the daily plan is now
derived from the user's own body rather than displayed as a constant. Hold that
line.

**Execute `PHASE7_REMEDIATION_PLAN.md` in its stated order. Do not reorder it.**

- **Step 3a** — the nine overflow sites O1–O9. **O6 first and alone**: it is the
  shared `PrimaryButton`, so fixing it may clear failures currently counted
  against other screens. Re-run the sweep and re-count before touching anything
  else. O1+O2 are one fix (`ListTile` gives `title` and `trailing` no shared
  width budget). O5 fails on the tablet too, so it must wrap, not shrink.
- **Step 3b** — the systemic half of D5: 39 fixed `fontSize:`, 31 hard-coded
  dimensions, `PulseBreakpoints` unused.
- **Step 3c** — C2 magic numbers, C3 duplicated literals, C5 force-unwraps.
- **Steps 4–6** — integration suite, Tier 1–3 cases, final report.

```bash
flutter test --run-skipped test/golden   # 117/160 passing — the count must rise
```

**Non-negotiable constraints:**
- The gate is **zero analyzer errors and a fully passing suite**, verified at
  every commit. Paste real console output; never claim a pass without it.
- **A green suite does not mean the app works.** It has missed a startup crash,
  a permanent spinner and three keyboard failures in this project. Launch on
  the emulator before calling any UI work done.
- Match the original author's style exactly — `CLAUDE.md` has the full guide.
  **Never run `dart format`**; it reflows the whole file.
- Never reintroduce seeded user data. Empty states are the pattern.
- Commit messages: plain prose, no `Co-Authored-By`, no mention of any AI tool.

**Traps that cost time last session:**
- `flutter` is **not on `PATH`** in a fresh shell — `export
  PATH="$HOME/development/flutter/bin:$PATH"` first, every time.
- **Clear app data between onboarding runs** (`adb shell pm clear
  com.pulse.pulse_app`) or a previous install's snapshot hydrates into what
  looks like a fresh profile. This cost a full investigation.
- `adb input text` breaks on a literal space — use `%s`.
- `adb screencap` is black on the Moto Edge 30 but fine on the emulator.
- In zsh, `D="-s emulator-5554"; adb $D ...` does not expand.
- Autosave is debounced — `await store.flushPendingSave()` before `bootFresh`.
- `PulseStore()` is zero-arg; `PulseApp` takes `store`, not `initialRoute`.
- graphify runs under Python 3.14, not the shell's `python3`.

**Three decisions are owed by the owner before some work can finish** — raise
them early rather than guessing:
1. The eight fabricated screens (QA_FINDINGS §3) — store-wire or empty-state?
2. N1 — the onboarding "Enable Notifications" button is a stub that can grant
   nothing. Wire it or remove it?
3. Golden images stay uncommitted until 1 and 2 are settled, or a later honest
   fix will read as a regression.

**Also outstanding:** `master` is 7 commits ahead of `main` and `gh` is not
authenticated, so the PR needs a browser or `gh auth login`.

Work through Step 3a and check in after O6 and its re-count, so the shared-
component effect can be reviewed before the remaining eight sites are touched.
