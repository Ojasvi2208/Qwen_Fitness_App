# PULSE — Phase 7 QA findings

Written for: whoever reviews or continues the Phase 7 remediation.
Status: **Steps 1 and 2 complete.** Step 3 (the responsive refactor) is the
next work item and its scope is the O-series table below.

Gate at every commit so far: `flutter analyze` 0 errors, `flutter test` all
passing. Figures in this document are console output, not estimates.

---

## 1. Step 1 — defects fixed

Each carries a regression case in [test/ui_fit_test.dart](../test/ui_fit_test.dart)
that sizes the test surface to a real device **before** pumping, because the
800×600 default is wider and shorter than any phone and is precisely why 235
passing cases never saw any of this.

| # | Defect | Root cause | Fix |
|---|---|---|---|
| D1 | Avatar read "AM" beside the name "Ojasvi" | `PulseAvatar` defaulted `initials = 'AM'`, a leftover of the sample profile removed in Phase 5 | `initials` is now required so no stale default can outlive its data; `pulseInitials()` derives them; an empty profile renders a neutral icon, never invented letters |
| D2 | Centre FAB covered the Train tab | `centerDocked` over a five-destination `NavigationBar` puts the FAB on the middle destination | `endFloat`. Five tabs and the bar are untouched |
| D3 | Quick Log sheet overflowed by 176 px | 8 items in a 65 %-height cap, `shrinkWrap`, no scroll | `tall: true` plus a scrolling `Flexible` list, so a larger text scale cannot overflow it either |
| D4 | Notification permission could not be granted | `POST_NOTIFICATIONS` absent from the manifest; Android 13+ refuses the runtime request without it | Declared in `AndroidManifest.xml` |
| D6 | **New.** `MacroRow` overflowed by 62 px | Label and value both unconstrained in a `Row` | Label is `Expanded` and ellipsises; the number keeps its space |

D6 was found by the *first* test written at 360 px width, before any harness
existed. That is the entire argument for Step 2.

### C1 / C4 — fabricated data

Scope agreed with the project owner: fix what a user cannot avoid seeing on a
fresh install; size the rest as follow-up (§3 below).

Fixed: the greeting said "Good morning" at every hour and dated itself
29 September forever; the diary's whole date axis was three literals pinned to
that date; the Today steps card drew a seven-bar week from a `const` list; the
habit chips named progress strings no store field feeds; the insight strip
asserted a protein streak on an empty profile; the Train hero typed "45 min /
Intermediate / 8 exercises" beside a hard-coded name; two seven-bar charts on
Activity and Nutrition Progress presented invented weeks.

Date formatting now lives in `common.dart` beside the other `fmt*` helpers
(`fmtLongDate`, `fmtMediumDate`, `fmtShortDate`, `fmtGreeting`) — there is no
`intl` dependency in this project and adding one for four format strings was
not worth the lock-file churn.

Where no history exists the screen says so, reusing the `EmptyState` wording
`StepsScreen` already had for exactly this case. **Nothing in this app records
a daily step or calorie series** — the store holds `stepsToday` and `foodKcal`
and no more — so those charts could not be drawn honestly at all.

---

## 2. Step 2 — the golden harness, and what it found

[test/golden/device_profiles.dart](../test/golden/device_profiles.dart) is a
hand-rolled device matrix (no `golden_toolkit`: this project carries no test
dependency beyond `flutter_test` and writes its own doubles).
[test/golden/overflow_sweep_test.dart](../test/golden/overflow_sweep_test.dart)
renders 16 screens across the §2.1 matrix.

The overflow assertion is the primary gate rather than image diffing, because
**a golden only fails once a person looks at the diff, while a `RenderFlex`
overflow throws and can fail the build on its own.**

### Result

```
160 renders · 117 passed · 43 failed
97 RenderFlex overflows, the largest 281 px
```

**43 of 160 renders overflow.** The plan predicted this step would surface more
than the five known defects; it surfaced nine distinct root-cause sites.

### O-series — the Step 3 scope

Nine sites account for all 97 overflows. Every one is the same shape as D6: an
unconstrained `Text` inside a `Row`.

| # | Site | Overflows | Screens affected |
|---|---|---|---|
| O1 | [progress_screens.dart:943](../lib/screens/progress/progress_screens.dart#L943) — goal `ListTile` trailing `Row` | 16 | Goals |
| O2 | [progress_screens.dart:942](../lib/screens/progress/progress_screens.dart#L942) — the same tile's title | 12 | Goals |
| O3 | [progress_screens.dart:915](../lib/screens/progress/progress_screens.dart#L915) — "adjust goals" card | 12 | Goals |
| O4 | [common.dart:369](../lib/widgets/common.dart#L369) — `TrendIndicator` label row | 8 | Progress, Weight progress |
| O5 | [progress_screens.dart:170](../lib/screens/progress/progress_screens.dart#L170) — weight chart legend row | 8 | Weight progress |
| O6 | [pulse_components.dart:56](../lib/widgets/pulse_components.dart#L56) | 4 | several |
| O7 | [train_screens.dart:76](../lib/screens/train/train_screens.dart#L76) | 3 | Train |
| O8 | [train_screens.dart:80](../lib/screens/train/train_screens.dart#L80) | 1 | Train |
| O9 | [premium_screens.dart:139](../lib/screens/profile/premium_screens.dart#L139) | 1 | Subscription |

### Worst profiles

`phone_small` (320×568) and `phone_moto` at textScale 1.5 fail the most, which
is the matrix doing its job: the smallest realistic Android and the reported
device under accessibility stress. Five screens fail on **both** —
Diary, Goals, Train, Weight progress and Subscription.

Notably `tablet` (768×1024) also fails on Weight progress, so this is not
purely a narrow-screen problem; O5's legend row is wide regardless.

### Goldens proper

Not yet committed. The O-series fixes will churn every image, so approving
~120 goldens before Step 3 would mean approving 43 renders with visible
overflow stripes baked in as the reference. The overflow gate is green-or-red
on its own and is the useful half today; images are worth committing once the
O-series is closed.

---

## 3. Known-fabricated screens — not fixed, deliberately

Eight screens remain invented end to end. Each needs either store wiring or an
empty state, and each is a user-visible falsehood of the same class as the
removed sample profile.

| Screen | What it claims |
|---|---|
| `WeeklyReportScreen` | every row — "58,420 steps", "5 / 7 protein days", "Sep 21–27" |
| `StreaksScreen` | "7-day streak", earned/unearned badges, "18 of the last 21 days" |
| `ActivityDetailScreen` | "5.26 km", "31:42", "146 bpm", plus a painted fake GPS route |
| `WidgetsWatchScreen` | every tile value |
| `_ProgressCalendar`, `_HistoryCalendar` | activity dots from `d % 3 == 0` arithmetic |
| `WaterScreen` "Today's sips" | five fake timestamped entries, each with a working delete button |
| `NotificationsScreen` | "You've completed 20 workouts" |
| onboarding `_planPage` | "2,050 kcal" under the words "Built from your answers" — see N3, which is worse than it looks |

`PulseData.habits`, `.insights`, `.notifications`, `.achievements` and
`.weeklyStepChart` are the shared sources behind several of these.

**Risk if Step 2's goldens are approved before this is addressed:** the
fabricated figures become the approved reference images, and a later honest fix
then reads as a regression.

---

## 4. Outstanding from the plan

- **Step 3** — the O-series above, then C2 (magic numbers), C3 (duplicated
  string literals), C5 (force-unwrap audit).
- **Steps 4–5** — integration suite, Tier 1–3 flow cases. Note `adb screencap`
  returns black frames on the Moto Edge 30; use the `integration_test`
  screenshot API.
- **C6** — 13 warnings, ~239 info lints, all pre-existing. Sweep in its own
  commit.
- **C7** — `android/app/build.gradle` still signs release with the debug key
  and carries the generated `applicationId`. Blocks a real release.
- **PR into `main`** — `master` is ahead; `gh` is not authenticated here.

## 5. Device verification

A passing suite has missed a startup crash, a permanent spinner and three
keyboard failures in this project, so every Step 1 fix was confirmed by eye on
a running device, not by test output alone.

Run on the Pixel 7 emulator (API 36, 1080×2400 at 420 dpi), full first-launch
journey: welcome → sign-up → 9 onboarding steps → permissions → dashboard.
The physical Moto Edge 30 took the first build and launched clean (process
alive, no `FATAL`, no `AndroidRuntime`, no overflow in `logcat`) but detached
from `adb` before the walkthrough, so the per-screen confirmation below is the
emulator's.

| Fix | Confirmed on device |
|---|---|
| D1 | Avatar reads **"OM"** beside "Ojasvi" — the name typed in onboarding. No "AM" anywhere |
| D2 | All five tabs visible and legible; the FAB sits clear at the right and covers no destination |
| D3 | The Quick Log sheet shows **all eight** items including "Log Measurement", with room to spare and no overflow stripes |
| D4 | `dumpsys package` reports `android.permission.POST_NOTIFICATIONS: granted=false, USER_SENSITIVE` — Android now treats it as requestable, which is what the missing declaration blocked |
| D6 | Macro rows render without stripes at every width walked |
| C1 | The greeting read "Good morning, Ojasvi" at 11:45 and dated itself "Thursday, October 1" — both from the clock |

Also confirmed: the sign-up form raised the keyboard on both fields and the
onboarding details form on all four, so the Phase 5 `FocusNode` fixes hold; no
spinner hung; nothing was pre-filled with another identity.

### Two things found during the walkthrough

**N1 — the onboarding "Enable Notifications" button is a stub.** It shows a
snackbar reading *"System permission dialog would appear here."* and never
calls the scheduler
([onboarding_screen.dart:383](../lib/screens/auth/onboarding_screen.dart#L383)).
The D4 manifest fix is still required and verified, but **this button cannot
grant anything**, so a user who taps it gets a reassuring message and no
permission. Pre-existing; not introduced by this work.

**N2 — a dashboard showing 1088 kcal on an apparently fresh profile.** Half of
this is benign and half is a real defect; they were initially conflated.

*Benign:* the food itself came from a *previous install's* snapshot on the same
emulator (`revision 20`, `savedAt` an hour before the run), which `_hydrate`
correctly restored. After `pm clear` the app returns to a clean welcome screen.
Local-first persistence behaving as designed — **not** reseeded sample data.

*Real:* the same screen showed goals of 2000/120/200/65 while onboarding's
final page had just promised 2,050/135/220/70. That mismatch is **not** stale
data — it is N3.

**N3 — onboarding never writes the user's goals, and nothing computes them.**
Three separable defects, all verified in source:

1. `setTargets` ([pulse_store.dart:487](../lib/data/pulse_store.dart#L487))
   accepts only `targetWeightKg`, `calorieGoal` and `proteinGoal` — **there is
   no `carbGoal` or `fatGoal` parameter at all**. `_commitProfile`
   ([onboarding_screen.dart:66](../lib/screens/auth/onboarding_screen.dart#L66))
   passes only `targetWeightKg`. So the store defaults at
   [pulse_store.dart:136](../lib/data/pulse_store.dart#L136) survive onboarding
   untouched, and the comment above them — *"onboarding overwrites them from
   the user's own details (§14 step 9)"* — **is false**. `updateGoals` is the
   only path that can set all four; onboarding never calls it.
2. The "Your daily plan is ready" page is hardcoded
   ([onboarding_screen.dart:289–311](../lib/screens/auth/onboarding_screen.dart#L289)):
   2,050 kcal / 135 g / 220 g / 70 g / 2.6 L / 8,000 are literals in the widget
   tree, shown to every user regardless of input. These are the same constants
   the removed sample profile used.
3. **No goal computation exists anywhere in `lib/`** — no BMR, TDEE,
   Mifflin-St Jeor or activity factor (grepped; zero hits). The "Why these
   numbers?" dialog explains a derivation from "age, sex, height, weight and
   activity level" that is not implemented.

Observed live: entering age 28, height 178 cm, weight 78 kg changed no target.
This is the most serious honesty defect found so far — the app states a
personalised calculation it does not perform — and it is **larger than C1 as
scoped**, so it is recorded here rather than fixed mid-step.

Fixing it properly means deciding what the goals *should* be (a real
Mifflin-St Jeor implementation against §14), which is a product decision, not a
refactor. Until then the plan page should not claim the numbers were built from
the user's answers.
