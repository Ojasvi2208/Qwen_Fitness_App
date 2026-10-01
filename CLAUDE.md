# PULSE — working notes for agents

Local-first Flutter fitness and nutrition app. Read
[docs/IMPLEMENTATION_RELEASE_DOCUMENT.md](docs/IMPLEMENTATION_RELEASE_DOCUMENT.md)
for the phase status and file map, and
[docs/PHASE5_TEST_PLAN.md](docs/PHASE5_TEST_PLAN.md) for how to run and extend
the suite.

## Environment

No SDK ships with this repo. On this machine:

- **Flutter 3.47.5 / Dart 3.13.4** at `~/development/flutter`, on `PATH` via
  `~/.zshrc`. Verify with `flutter --version`.
- **Android SDK** at `/opt/homebrew/share/android-commandlinetools` (platform 36,
  build-tools 36.0.0), `ANDROID_HOME` set in `~/.zshrc`. `flutter doctor` is
  green for Android. Emulator AVD: `pulse_pixel7` (API 36, Play Store image —
  Ads and In-App Purchase need Play Services).
- **Xcode is NOT installed** and cannot be from a terminal (App Store only,
  needs an Apple ID and `sudo`). All iOS work is unverified.
- **graphify** lives under Python 3.14 (`/opt/homebrew/opt/python@3.14/bin/python3.14`),
  *not* the shell's aliased `python3` (3.11). Checking its deps under 3.11
  falsely reports everything missing — do not "fix" that. `graphify-out/` is
  gitignored and regenerates via `graphify update .`.

## The gate

```bash
flutter analyze && flutter test
```

**Zero errors and 100% of tests passing.** As of Phase 5: 201 cases across 9
suites.

The release doc §8 words the gate as the literal string `No issues found!`.
That overstates it: 13 warnings and ~239 info-level lints predate this work
(unused imports, unused locals, deprecated `withOpacity`). They are cosmetic and
none affects behaviour. **Treat the gate as zero errors + all tests passing**,
and do not claim a run passed without pasting real console output.

## Style — match the original author, do not introduce a new one

- **File banner**: imports first, then a `═`-boxed header
  `<WP/PHASE id> — <Title> (§refs)`. 67 `═` in core files, 66 in the WP3.x
  domain files — match the file's neighbours.
- **Section dividers**: `// ── Title ────` padded to about column 70.
- **Comments explain WHY and cite the brief** (`§NN`). Never restate the code.
- **Naming**: `Pulse*` prefix for anything reusable; role suffixes `*Engine`,
  `*Book`, `*Service`, `*Manager`, `*Gateway`, `*Provider`, `*Repository`;
  `k`-prefixed top-level constants; `snake_case` files; `_Fake*`, `_Mem*`,
  `Stub*`, `Placeholder*` for test doubles.
- **Value objects**: all `final`, `const` constructor, `toJson()` and a
  **`static fromJson()`** (not a factory). **There is no `copyWith` in this
  codebase** — `Goals.clone()` is the draft-then-commit idiom.
- **Store mutators, every time**: mutate → `track('event_name')` →
  `_markDirty()` → `notifyListeners()`.
- **Seams**: every side effect is an `abstract class` plus a `Stub`/`Placeholder`,
  injected as an optional named parameter defaulting to the stub.
- **Injectable clock**: anything time-dependent takes `{DateTime? now}` or
  `DateTime Function()? clock`.
- **Widgets**: `const` constructor first; `PulseSpacing`/`PulseRadius`/
  `PulseDuration` tokens, never literals; `Semantics` on every metric; private
  `Widget _cardName(BuildContext, PulseStore)` helpers — **never** a `_build*`
  prefix (zero occurrences in the codebase).
- **Hydration never throws**: `is`-guard every field,
  `(x as num?)?.toDouble() ?? currentValue` — fall back to the *current* value,
  never a hard-coded default — and `catch (_)` with a comment.
- **Tests**: hand-written doubles, no mocking package; one-level `group()`;
  lowercase-sentence `test()` names carrying `§`/flow IDs; `closeTo` for floats;
  `reason:` on invariants; and the restart signature
  mutate → `flushPendingSave()` → `bootFresh(repo)` → assert.
- **Microcopy**: honest, gentle, says what is kept. No fake urgency, no shame,
  no medical claim. A test enforces it:
  `expect(hint.toLowerCase(), isNot(contains('fail')))`.

## Injection idiom

`PulseStore()` is **zero-arg**. There is no `PulseStore(repository: …)`
constructor. Attach persistence explicitly:

```dart
final store = PulseStore();
await store.attachPersistence(repo);   // pulse_store.dart
```

Autosave is **debounced**, so any test that mutates and then reboots must
`await store.flushPendingSave()` first or it reads the pre-mutation snapshot.
This was the single largest cause of test failures in Phase 5.

## No sample data

A fresh install has **no profile and nothing logged**. Onboarding (§14) is the
first screen and the only source of the user's name, age, height and weight;
`store.hasProfile` gates the launch route. An earlier build shipped a sample
identity ("Alex Morgan") whose weight drove the calorie targets, plus fabricated
7-day charts and statistics. All of it is gone. **Do not reintroduce seeded user
data**; empty states (`EmptyState`, `store.hasAnyData`) are the pattern.

Screens must therefore survive empty collections — no unguarded `.first`,
`.last` or `[0]` on store lists.

## Commit messages

Plain prose matching the existing log. **Never** a `Co-Authored-By` trailer, and
never a mention of Claude, Anthropic or any other AI tool. Explain *why*, not
just what.

## Next work

[docs/PHASE7_QA_AUTOMATION_PLAN.md](docs/PHASE7_QA_AUTOMATION_PLAN.md) is the
current plan: five verified UI defects (D1–D5), a golden-image layer to catch
overflow and overstretch, and an integration suite for the critical journeys.
[docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) has the full state.

## Phase 6

`in_app_purchase`, `google_mobile_ads` and `flutter_local_notifications` are
declared and compile into the APK. The app builds, installs and runs on the
emulator. Their adapters live in `lib/data/platform/`, each behind a narrow
backend seam so the app-side rules are testable without the plugin.

**Still unverified**: no real purchase, ad impression or notification has
occurred, and nothing on iOS. The AdMob ids in `AndroidManifest.xml` and
`AdUnitIds` are Google's **test** ids — a release build must override both.

Build and run:

```bash
emulator -avd pulse_pixel7 -no-snapshot-save -no-boot-anim &
adb wait-for-device && flutter run
```

**A passing suite does not mean the app starts.** `google_mobile_ads` crashed
the process at launch over a missing manifest id while `analyze` and `test`
were both clean. Launch it before claiming anything works.
