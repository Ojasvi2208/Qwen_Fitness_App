# PULSE — session handoff

Written for: whoever picks this up next, human or agent.
Covering the session of 2026-09-30 → 2026-10-01.

## Start here

1. [CLAUDE.md](../CLAUDE.md) — environment, style rules, gate, idioms
2. [docs/PHASE7_QA_AUTOMATION_PLAN.md](PHASE7_QA_AUTOMATION_PLAN.md) — **the next thing to do**
3. [docs/IMPLEMENTATION_RELEASE_DOCUMENT.md](IMPLEMENTATION_RELEASE_DOCUMENT.md) — phase status
4. [docs/PHASE6_STATUS.md](PHASE6_STATUS.md) — what is and is not platform-verified

## Where things stand

```
flutter analyze  →  0 errors (13 warnings, all pre-existing)
flutter test     →  235/235 passing
```

| Phase | State |
|---|---|
| 1–4 | complete |
| 5 | **complete** — gate green, WP5.2 state matrix, WP5.3 accessibility |
| 6 | **partial** — adapters + concrete backends written and wired; Android builds, installs and runs; **nothing platform-verified** (no real purchase, impression or notification); no iOS |
| 7 | **not started** — the QA/UI plan above is its first work item |

18 commits this session, all on `origin/master`.

## What was done

- Phase 5 finished: verification gate green (was 113/22 failing), state-matrix
  sweep (44 cases), accessibility sweep (19 cases) which also **wired two dead
  toggles** — `largeText` and `reduceMotion` had switches that did nothing.
- The sample profile was removed entirely; onboarding is now the first launch
  step and actually writes what the user types. See [[pulse-no-sample-data]].
- Android toolchain installed from scratch; the first-ever build of this project
  exposed four broken scaffold versions plus a startup crash.
- Phase 6 adapters and concrete plugin backends, behind
  `--dart-define=PULSE_PLATFORM_SERVICES=true`.
- Three form/keyboard defects found by using the app, not by tests.

## Open items, in priority order

1. **Five UI defects** (D1–D5) — all verified in source, see the Phase 7 plan.
2. **PR into `main`.** `master` is ~7 commits ahead. `gh` is not authenticated
   here, so this needs a browser or `gh auth login`:
   https://github.com/Ojasvi2208/Qwen_Fitness_App/compare/main...master
3. **Form audit** — log-weight, measurements, food search and goal editing have
   the same `TextField`-without-`FocusNode` shape that caused three bugs.
4. **13 analyzer warnings + ~239 infos** — all pre-existing. They are why the
   release doc's literal `No issues found!` gate is unreachable.
5. **Phase 6 remainder** — health, camera, photo IO, signing, flavors, deep
   links, legal pages. All need a toolchain; iOS needs Xcode.

## Traps worth knowing

- **A green suite does not mean the app starts.** Proven three times. Launch it.
- Autosave is debounced: a test that mutates then reboots must
  `await store.flushPendingSave()` first. Largest single cause of test failures.
- `PulseStore()` is zero-arg. There is no `PulseStore(repository:)`.
- `adb screencap` returns black frames on the Moto Edge 30.
- graphify runs under Python 3.14, not the shell's `python3`.

## Knowledge graph

`graphify-out/` is current as of this session: 1630 nodes, 2065 edges,
83 communities, 100% EXTRACTED, zero token cost. Gitignored; regenerate with
`graphify update .`. Community labels stay as placeholders unless
`GOOGLE_API_KEY` or `GEMINI_API_KEY` is set, then `graphify label .`.

Useful queries:

```bash
graphify query "how does autosave reach the repository?"
graphify path "TodayScreen" "FoodDetailScreen"
graphify affected "PulseStore"
```

## Memory

Four notes under the project memory directory, indexed in `MEMORY.md`:
`pulse-environment`, `pulse-testing-gaps`, `pulse-focusnode-pattern`,
`pulse-no-sample-data`.
