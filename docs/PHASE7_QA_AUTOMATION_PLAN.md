# PULSE — UI-Fit Remediation & E2E Flow Automation Plan

Written for: the engineer (or agent) executing this in a later session.
Status: **plan only — no code written for it yet.**
Author context: Flutter 3.47.5 · 235 tests passing · 0 analyzer errors ·
Android toolchain green · Pixel 7 emulator (API 36, 440dpi) and a physical
Moto Edge 30 (API 34, 400dpi, 1080×2400) both attached.

---

## 0. Why this plan exists

Five defects were observed on the physical device that the 235-case suite did
not catch. That is the real finding: **the suite proves screens build, not that
they fit, and not that a person can complete a task.** Three separate times this
session, running the app found what tests could not — the AdMob startup crash,
the sign-up spinner, the onboarding keyboard. This plan closes that gap
deliberately rather than one bug report at a time.

---

## 1. Confirmed defects (verified in source, not guessed)

| # | Defect | Root cause | File |
|---|---|---|---|
| D1 | Avatar reads "AM" while greeting reads "Ojasvi" | `PulseAvatar` defaults `initials = 'AM'` — leftover from the removed Alex Morgan sample profile. Nothing passes real initials. | [common.dart:293](../lib/widgets/common.dart#L293) |
| D2 | Centre FAB covers the "Train" tab | `FloatingActionButtonLocation.centerDocked` over a **5**-destination `NavigationBar`; the middle destination is Train, so the FAB lands on its icon and label. | [main.dart:345](../lib/main.dart#L345) |
| D3 | Quick Log sheet "BOTTOM OVERFLOWED BY 176 PIXELS" | 8 items rendered inside `pulseSheet`, which caps height at **65%** of screen, with no `tall: true` and no internal scroll. | [common.dart:76](../lib/widgets/common.dart#L76), [:109](../lib/widgets/common.dart#L109) |
| D4 | Notification permission cannot be granted | `POST_NOTIFICATIONS` is **absent from AndroidManifest.xml**. Android 13+ refuses the runtime request without it, so `requestPermission()` can never succeed. | `android/app/src/main/AndroidManifest.xml` |
| D5 | UI reads overstretched at 400dpi | 39 fixed `fontSize:` literals, 31 hard-coded `height:`/`width:` values, and only **8** responsive helpers (`LayoutBuilder`/`MediaQuery.sizeOf`/`PulseBreakpoints`) across all screens. `PulseBreakpoints` exists in the token file and is essentially unused. | `lib/screens/**`, [tokens.dart](../lib/theme/tokens.dart) |

**Sequencing note:** D1–D4 are bounded fixes. D5 is a systemic refactor and
must come after the harness in §3 exists, or there is no way to prove the
refactor did not break layout somewhere else.

---

## 2. Test architecture

Four layers, each catching what the one below cannot. The existing 235 cases
are layers 1–2; everything new is layers 3–4.

| Layer | Tool | Catches | Runs on |
|---|---|---|---|
| 1 Unit | `flutter test` | logic, persistence, maths | CI, headless |
| 2 Widget | `flutter test` | a screen builds; a form behaves | CI, headless |
| 3 **Golden** | `flutter test --update-goldens` | **overflow, overstretch, truncation** | CI, headless |
| 4 **Integration** | `integration_test` + `flutter drive` | a real task completes on a real device | emulator + physical |

### 2.1 Golden layer — the answer to D5

Goldens are the only automated way to catch "it looks wrong". Render every
screen at a device matrix and diff against approved images.

Device matrix (deliberately small — each entry multiplies run time):

| Profile | Logical size | DPR | Why |
|---|---|---|---|
| `phone_small` | 320×568 | 2.0 | smallest realistic Android; first to overflow |
| `phone_moto` | 360×800 | 2.5 | **the reported device** (1080×2400 @ 400dpi) |
| `phone_pixel7` | 412×915 | 2.625 | the emulator already in use |
| `phone_large` | 480×1067 | 3.0 | large-phone upper bound |
| `tablet` | 768×1024 | 2.0 | §7.4 QA matrix requires it |

Cross with **text scale** {1.0, 1.3, 1.5} and **theme** {light, dark}.
Full cross = 5 × 3 × 2 = 30 renders per screen. Too many. **Prune to:**
- all 5 sizes × textScale 1.0 × light (fit baseline)
- `phone_moto` and `phone_small` × textScale 1.5 × light (accessibility stress)
- `phone_moto` × textScale 1.0 × dark (theme parity)
= **8 renders per screen**, ~15 screens = ~120 goldens. Tractable.

Add an **overflow assertion** independent of image diffing, since a golden only
fails if someone looks at it:

```dart
// Fails the test on any RenderFlex overflow, which is what the yellow-and-
// black stripes represent. Cheaper and clearer than diffing an image.
expect(tester.takeException(), isNull);
```

### 2.2 Integration layer — the answer to "all possible flows"

`integration_test` drives the real app on a real device: real keyboard, real
permission dialogs, real Play Services.

---

## 3. Flow enumeration — being honest about combinatorics

The request was "using permutation combination try to find out all possible
flows". Stated plainly: **a true permutation of 58 routes is 58! — not
enumerable, and most of it meaningless.** Chasing it would produce thousands of
nonsense paths and no signal.

The disciplined substitute is a **state-transition model**, which is what a
test architect actually builds. Three tiers:

### Tier 1 — Critical journeys (must never break) — ~12 flows

End-to-end, each a complete user intention:

| ID | Journey |
|---|---|
| J1 | First launch → onboarding → dashboard with own data |
| J2 | Log food → totals update → survives restart |
| J3 | Log water → ring updates → survives restart |
| J4 | Start workout → log sets → finish → stats credited |
| J5 | Log weight → trend updates → persists |
| J6 | Edit goals → targets recalculate → persist |
| J7 | Free → paywall → trial → Pro → ads disappear |
| J8 | Log measurement → trend → export contains it |
| J9 | Create reminder → permission prompt → scheduled |
| J10 | Delete My Data → everything erased → app still usable |
| J11 | Offline → log → reconnect → nothing lost |
| J12 | Change units → every screen reflects it |

### Tier 2 — Intermediate transitions (the "in-between flows") — ~40 flows

Pairwise transitions that matter, derived from the route graph rather than
invented. Generate with:

```bash
graphify query "which screens can reach the food search screen?"
graphify path "TodayScreen" "FoodDetailScreen"
```

Rules for inclusion: a transition qualifies if it (a) crosses a tab boundary,
(b) opens a modal or sheet, (c) carries an argument, or (d) can be reached by
the system back button. That bounds it to roughly 40 and each one is defensible.

### Tier 3 — Data-response matrix (what the request means by "how UI behaves
as per data entered") — ~60 cases

For each of the **26 input surfaces**, cross with an equivalence-class vector:

| Class | Example | Expected |
|---|---|---|
| empty | `""` | gentle prompt, never an error on arrival |
| minimum | `1` | accepted |
| maximum | `999` | accepted or clearly capped |
| over-maximum | `100000` | rejected with a reason |
| zero / negative | `0`, `-5` | rejected for weight/age |
| decimal | `72.5` | accepted where meaningful |
| non-numeric | `abc` | rejected, no crash |
| very long | 500 chars | truncates or wraps, never overflows |
| unicode / emoji | `Ojasvi 🏃‍♀️` | renders, persists, round-trips |
| injection-ish | `<script>`, `'; DROP` | treated as literal text |

Not every class applies to every field — the matrix is `applicable(field,
class)`, which lands near 60 real cases rather than 260.

**Total: ~112 automated cases**, on top of the existing 235.

---

## 4. Execution order

Each step ends green; nothing proceeds on a red suite.

### Step 1 — Fix D1–D4 (bounded, ~half a day)
- **D1**: `PulseAvatar` takes required `initials`; derive from
  `store.userFirstName`; empty profile → neutral icon, never letters.
- **D2**: Either (a) widen to 6 destinations with a spacer slot, or (b) move
  to `BottomAppBar` with a notch, or (c) drop `centerDocked` for
  `endFloat`. **Recommend (b)** — it is what the Material spec intends and
  keeps the 5 tabs the brief specifies.
- **D3**: `openQuickLog` passes `tall: true`, and the sheet body becomes a
  `ListView` so it scrolls instead of overflowing.
- **D4**: Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
  to the manifest; verify the runtime prompt appears on the Moto device.
- Regression test per fix. Suite must stay green.

### Step 2 — Build the golden harness (~1 day)
- Add `golden_toolkit` or hand-roll a `DeviceProfile` helper.
- `test/golden/` with the 8-render matrix per screen.
- Commit approved goldens; CI fails on diff.
- **Expect this step to surface more overflows than D1–D5.** That is success,
  not scope creep: log each, fix in Step 3.

### Step 3 — D5 responsive refactor (~2 days)
Only after goldens exist to prove it.
- Replace fixed `fontSize:` with theme text styles that honour `textScaler`.
- Replace hard-coded `height:`/`width:` with `LayoutBuilder` or
  `PulseBreakpoints`.
- Re-approve goldens deliberately, reviewing each diff.

### Step 4 — Integration suite (~2 days)
- `integration_test/` with the 12 Tier-1 journeys.
- `flutter drive` against both emulator and the Moto device.
- Capture screenshots per step for a human-reviewable artifact.
- **Note:** `adb screencap` returns black frames on the Moto Edge 30. Use
  `integration_test`'s own screenshot API (which captures through the Flutter
  engine) rather than `adb`.

### Step 5 — Tier 2 and 3 (~2 days)
- Generate Tier-2 transitions from the graphify route graph.
- Table-drive Tier 3 from the equivalence-class matrix.

### Step 6 — Report
`docs/QA_FINDINGS.md`: every broken flow, severity, repro, fix or ticket.

---

## 5. Definition of done

- [ ] D1–D5 fixed and regression-tested
- [ ] `flutter analyze` 0 errors; suite green at every commit
- [ ] ~120 goldens committed; zero overflow exceptions across the matrix
- [ ] 12 Tier-1 journeys pass on emulator **and** physical device
- [ ] Tier-2 and Tier-3 cases pass or have filed tickets
- [ ] `docs/QA_FINDINGS.md` written
- [ ] C1–C5 remediated; C6 swept in its own commit; C7 recorded or done
- [ ] No fabricated value remains presented as the user's own data
- [ ] Release doc Phase 7 row updated

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Goldens are flaky across host platforms (font rendering) | Pin a test font; run goldens only on CI's platform, or tag them `@Tags(['golden'])` and exclude from the default run |
| The D5 refactor churns every golden at once | Do D5 **after** goldens exist; review diffs in small batches per screen |
| Integration tests are slow and flaky | Keep Tier 1 only on device; Tiers 2–3 stay widget-level |
| `adb screencap` is black on the Moto | Use the `integration_test` screenshot API, not `adb` |
| Combinatorial explosion returns via Tier 2 | The four inclusion rules in §3 are the gate; anything failing them is out of scope |

---

## 6a. Code-quality remediation (hardcoding and related defects)

Audited this session, **not yet fixed**. Each item below was verified in source.
The constraint throughout: **extend the existing conventions, do not introduce a
new style.** `k`-prefixed top-level constants, `Pulse*` prefixes, role suffixes,
comments that cite the brief — all as CLAUDE.md describes.

### C1 — Fabricated display values still hard-coded

Values presented as the user's own but typed into the source:

| Value | Where |
|---|---|
| `'6,932'` steps daily average, `'2,140'` kcal | [progress_screens.dart:406](../lib/screens/progress/progress_screens.dart#L406), `:408`, `:736` |
| `'45 min'`, `'Intermediate'`, `'8 exercises'` on the Today's Workout card | [train_screens.dart:38-44](../lib/screens/train/train_screens.dart#L38) |
| 2 remaining `values: const [...]` chart arrays | progress and train screens |

These are the same class of problem as the removed sample profile: numbers the
user will read as theirs. Each must either derive from the store or be replaced
by an empty state. See [[pulse-no-sample-data]].

### C2 — Magic numbers in business logic

Unexplained constants doing real arithmetic:

| Constant | Meaning | Where |
|---|---|---|
| `0.000715` | stride length, km per step | [today_screen.dart:309](../lib/screens/today/today_screen.dart#L309), [train_screens.dart:878](../lib/screens/train/train_screens.dart#L878) |
| `0.04` | kcal burned per step | train_screens.dart:879 |
| `18` | kcal per kg of target-weight delta | progress_screens.dart:974 |
| `1.15` | protein-day tolerance | [consistency_service.dart:165](../lib/data/consistency_service.dart#L165) |
| `6.2`, `5.4`, `7.4` | MET rates per difficulty | [workout_session.dart:195](../lib/data/workout_session.dart#L195) |

Two of these (`0.04`, `18`) were introduced during this session's fixes and are
as much a defect as the originals. Promote each to a `k`-prefixed constant in
the owning domain file with a comment stating the unit and its source. The MET
rates already carry an explanation and only need extracting.

### C3 — Duplicated string literals

`'Protein'` appears 15 times across screens, `'Weight'`/`'Steps'`/`'Calories'`
9 times each, `'Water'` 8. A rename or a translation pass would have to find
every one. Extract to a constants file following the existing `k` convention.

### C4 — Remaining stale defaults

`PulseAvatar` defaults `initials = 'AM'` (defect D1). Audit for other defaults
that encode the removed sample identity rather than failing loudly or showing a
neutral state.

### C5 — Force-unwrap audit

Ten `!.` force-unwraps across `lib/data/` (workout_session 7, monetization 2,
pulse_store 1). Each needs review: a force-unwrap is correct only where the
null case is genuinely impossible, and that reasoning belongs in a comment.

### C6 — Pre-existing analyzer debt

13 warnings and ~239 info lints, none introduced by recent work: unused imports,
unused locals, one `dead_null_aware_expression`, deprecated `withOpacity`
(superseded by `withValues`), `prefer_const_constructors`. This is the only
thing standing between the project and the release doc's literal
`No issues found!` gate. Sweep mechanically, in its own commit, so the diff is
reviewable as pure cleanup.

### C7 — Release-build configuration

`android/app/build.gradle` still signs release with the debug key
(`signingConfig = signingConfigs.debug`) and carries the generated
`applicationId = "com.pulse.pulse_app"` TODO. Both block a real release and are
Phase 6 item 11, recorded here so they are not forgotten.

### Sequencing

C1 and C4 belong with Step 1 (they are user-visible falsehoods). C2, C3 and C5
are safe refactors once goldens exist (Step 3). C6 is independent and can be
done at any time. C7 waits for signing material.

---

## 7. What this plan deliberately does NOT do

- It does not attempt literal permutation of 58 routes (§3 explains why).
- It does not add a mocking package — the codebase uses hand-written doubles
  and that convention holds.
- It does not touch iOS: no Xcode on this machine, so nothing there can be
  verified and nothing should be claimed.
