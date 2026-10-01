# Master prompt — next session

Paste this as the opening message of the next session.

---

Continue the PULSE Flutter app at
`/Users/ojasvimalik/Desktop/Ojasvi/Projects_Ojasvi/Pulse`.

**Read first, in this order:**
1. `CLAUDE.md` — environment, gate, style rules, idioms
2. `docs/SESSION_HANDOFF.md` — where the last session stopped
3. `docs/PHASE7_QA_AUTOMATION_PLAN.md` — the plan you are executing

State at handoff: `flutter analyze` 0 errors, `flutter test` 235/235, Android
toolchain green, Pixel 7 emulator and a physical Moto Edge 30 both working,
18 commits on `origin/master`.

**Execute the Phase 7 plan in its stated order. Do not reorder it** — the
golden harness exists specifically so the responsive refactor can be proven
safe, so Step 3 must not precede Step 2.

- **Step 1** — fix defects D1–D5 and code-quality items C1 and C4. These are
  user-visible falsehoods: an avatar reading "AM" beside the name "Ojasvi",
  a FAB covering the Train tab, a sheet overflowing by 176 px, a notification
  permission that cannot be granted, and hard-coded step/calorie figures
  presented as the user's own.
- **Step 2** — build the golden-image harness across the device matrix in §2.1.
  Expect it to surface more overflows than the five already known. That is the
  point; log each and fix in Step 3.
- **Step 3** — the responsive refactor (D5), then C2, C3 and C5.
- **Steps 4–5** — the integration suite and the Tier 1–3 flow cases.
- **Step 6** — write `docs/QA_FINDINGS.md`.

C6 (13 warnings, ~239 info lints) may be swept at any point, in its own commit.

**Non-negotiable constraints:**
- Match the original author's style exactly. `CLAUDE.md` has the full guide:
  `═`-boxed file banners, `// ──` dividers, comments that say *why* and cite
  the brief (`§NN`), `Pulse*` prefixes, role suffixes, `k`-prefixed constants,
  hand-written test doubles, no `copyWith`, never a `_build*` helper.
- The gate is **zero analyzer errors and a fully passing suite**, verified at
  every commit. Paste real console output; never claim a pass without it.
- **A green suite does not mean the app works.** It missed a startup crash, a
  permanent spinner and three keyboard failures in one session. Launch the app
  on the emulator or the Moto device before calling any UI work done.
- Never reintroduce seeded user data. Empty states are the pattern.
- Commit messages: plain prose, no `Co-Authored-By`, no mention of any AI tool.

**Traps that cost time last session:**
- Autosave is debounced — a test that mutates then reboots must
  `await store.flushPendingSave()` first.
- `PulseStore()` is zero-arg; persistence attaches via `attachPersistence`.
- `adb screencap` returns black frames on the Moto Edge 30; use the
  `integration_test` screenshot API.
- graphify runs under Python 3.14, not the shell's `python3`.

**Also outstanding:** `master` is ~7 commits ahead of `main` and `gh` is not
authenticated, so the PR needs a browser or `gh auth login`.

Stop and check in after Step 2, so the golden baseline can be reviewed before
the refactor churns it.
