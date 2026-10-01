# PULSE — Phase 7 remediation plan (Steps 3–6)

Written for: whoever executes the rest of Phase 7, human or agent.
Status: **plan only — no code written for it yet.**

Companion to [PHASE7_QA_AUTOMATION_PLAN.md](PHASE7_QA_AUTOMATION_PLAN.md),
which remains the governing document. This one exists because Steps 1 and 2
found work that plan could not have known about: nine overflow sites (O1–O9),
and an onboarding flow that never writes the goals it promises (N3). Evidence
for every item is in [QA_FINDINGS.md](QA_FINDINGS.md).

**Order is fixed.** Step 3 before 4 before 5 before 6, exactly as the governing
plan sequences them. The one rule that must never bend: the golden harness
(Step 2) exists so the responsive refactor can be proven safe, so no layout
change ships without running it.

---

## 0. Standing rules for every step below

1. **The gate, at every commit**: `flutter analyze` 0 errors, `flutter test`
   all passing. Paste real console output; never claim a pass without it.
2. **A green suite does not mean the app works.** It has missed a startup
   crash, a permanent spinner and three keyboard failures in this project.
   Launch on a device before calling any UI work done.
3. **Run the sweep after every layout change**:
   `flutter test --run-skipped test/golden`. The pass count must go up, never
   down.
4. **Match the original author's style.** `CLAUDE.md` is the guide:
   `═`-boxed banners, `// ──` dividers, comments that say *why* and cite `§NN`,
   `Pulse*` prefixes, `k`-prefixed constants, hand-written doubles, no
   `copyWith`, never a `_build*` helper.
5. **Never reintroduce seeded user data.** Empty states are the pattern.
6. **If reality contradicts this plan, stop and ask.** Do not silently
   re-scope. Three times already the honest move was to raise the conflict
   rather than guess — D2's fix choice, C1's true size, and N3.

---

## Step 3 — the responsive refactor

Governing plan §4 Step 3, now with the concrete scope the harness produced.
Baseline to beat: **117 of 160 renders passing.**

### 3a. O1–O9 — the overflow sites

All nine are one defect shape: an unconstrained `Text` inside a `Row`. The fix
is the same one D6 took — the label yields, the number keeps its space — so
these are mechanical, but they are *not* all independent (see O6).

| # | Site | Shape | Fix |
|---|---|---|---|
| O6 | [pulse_components.dart:56](../lib/widgets/pulse_components.dart#L56) | `PrimaryButton`'s inner `Row`: icon + `Text(label)`, `mainAxisSize.min`, nothing flexible | **Do this one first.** It is the shared button used across most screens, so its fix may resolve failures counted under other screens. Re-run the sweep immediately after and re-count before touching anything else. |
| O1 | [progress_screens.dart:943](../lib/screens/progress/progress_screens.dart#L943) | Goal `ListTile` `trailing:` — value `Text` + gap + icon | Constrain the trailing row; let the value ellipsise before the icon is pushed off |
| O2 | [progress_screens.dart:942](../lib/screens/progress/progress_screens.dart#L942) | The same tile's `title:` | `ListTile` gives `title` and `trailing` no shared budget — the pair must be sized together, so O1 and O2 are **one fix, not two** |
| O3 | [progress_screens.dart:915](../lib/screens/progress/progress_screens.dart#L915) | "Review your goals?" card header row | Already has `Expanded` on the text; the overflow is the icon + `IconButton3` pair at a large text scale. Verify before changing |
| O4 | [common.dart:369](../lib/widgets/common.dart#L369) | `TrendIndicator` — icon + `Text('+1.2 kg this month')`, `mainAxisSize.min` | The label is caller-supplied and unbounded; constrain it |
| O5 | [progress_screens.dart:170](../lib/screens/progress/progress_screens.dart#L170) | Weight chart legend: two swatch+label pairs in one `Row` with a fixed `SizedBox(width: PulseSpacing.l)` between | Fails on **tablet** too, so this is not a narrow-screen fix — it needs to wrap, not shrink. `Wrap` is the right widget |
| O7 | [train_screens.dart:76](../lib/screens/train/train_screens.dart#L76) | Suggested-workout meta row inside a `Wrap` | Introduced by the Step 1 C1 fix. The `Wrap` wraps, but each inner `Row` can still exceed the line at 1.5 scale |
| O8 | [train_screens.dart:80](../lib/screens/train/train_screens.dart#L80) | Same `Wrap`, second item | One fix with O7 |
| O9 | [premium_screens.dart:139](../lib/screens/profile/premium_screens.dart#L139) | Plan name `Text` + gap + `ProBadge` | Same shape as O1 |

**Sequencing within 3a**: O6 first and alone, re-run the sweep, re-count. Then
O1+O2 together, O5 (different fix — wrapping), then O3, O4, O7+O8, O9. One
commit per site or logical pair, each with the sweep count in the message.

### 3b. The systemic half of D5

The governing plan's D5 is wider than O1–O9: 39 fixed `fontSize:` literals, 31
hard-coded `height:`/`width:`, and `PulseBreakpoints` sitting unused in the
token file. O1–O9 are the symptoms that *throw*; D5 is the cause that makes the
UI read overstretched at 400 dpi without throwing anything.

Do this **after** 3a, because 3a's fixes are small and verifiable while this is
broad. Replace fixed `fontSize:` with theme text styles that honour
`textScaler`; replace hard-coded dimensions with `LayoutBuilder` or
`PulseBreakpoints`. Review the sweep diff per screen, in small batches.

### 3c. C2, C3, C5 — safe refactors

Governing plan §6a. Only after the layout work is green.

- **C2** — promote magic numbers to `k`-prefixed constants in their owning
  domain file, each with a comment naming the unit and its source: `0.000715`
  (km/step), `0.04` (kcal/step), `18` (kcal per kg of target delta), `1.15`
  (protein-day tolerance), the MET rates `6.2`/`5.4`/`7.4`.
- **C3** — extract duplicated literals (`'Protein'` ×15, `'Weight'`/`'Steps'`/
  `'Calories'` ×9 each, `'Water'` ×8) to a constants file on the `k` convention.
- **C5** — audit the ten `!.` force-unwraps in `lib/data/` (workout_session 7,
  monetization 2, pulse_store 1). A force-unwrap is correct only where null is
  genuinely impossible, and that reasoning belongs in a comment.

### Step 3 exit criteria

- [ ] All 160 sweep renders pass
- [ ] Gate green; app launched and walked on a device
- [ ] Goldens committed (see §Goldens below)

---

## Step 3.5 — N3, and the decision it needs

**This step is blocked on a product decision and cannot be executed without
one.** It is placed here, not later, because it is the most serious honesty
defect found and every day it ships is a day the app states a calculation it
does not perform.

The three parts, all verified in source
([QA_FINDINGS.md](QA_FINDINGS.md) N3):

1. `setTargets` has no `carbGoal`/`fatGoal` parameter, and `_commitProfile`
   passes only `targetWeightKg` — so the store defaults survive onboarding and
   the comment claiming otherwise is false.
2. The plan page hardcodes 2,050 / 135 g / 220 g / 70 g / 2.6 L / 8,000.
3. No BMR, TDEE or Mifflin-St Jeor logic exists anywhere in `lib/`.

**The decision required:** implement a real calculation, or stop claiming one.

| Option | Work | Consequence |
|---|---|---|
| **A — implement it** | Add a `NutritionService`-owned Mifflin-St Jeor + activity-factor calculation against §14; widen `setTargets` or call `updateGoals`; derive the plan page from the result | The app does what it says. Largest effort; needs the §14 numbers confirmed against the brief |
| **B — stop claiming it** | Plan page reads `store.goals` (the real defaults); reword "Built from your answers" and the "Why these numbers?" dialog to describe defaults the user can edit | Honest immediately, small diff. The targets are then generic, not personal |
| **C — split** | B now, A as its own work item | Removes the falsehood today without blocking on a product call |

**Recommendation: C.** It makes the app honest in one small commit and leaves
the calculation as a properly-scoped piece rather than something improvised
inside a QA step.

Whichever is chosen, part 1 is a plain bug and is fixed regardless: the false
comment goes, and onboarding either writes all four goals or stops pretending
it does.

---

## Step 4 — the integration suite

Governing plan §4 Step 4, unchanged. 12 Tier-1 journeys in `integration_test/`,
driven on the emulator **and** the physical Moto.

Carry forward from this session:
- `adb screencap` returns black frames on the Moto — use the `integration_test`
  screenshot API, which captures through the Flutter engine.
- `adb input text` breaks on a literal space; use `%s`.
- **Clear app data between runs** (`pm clear`). A prior install's snapshot
  hydrates into what looks like a fresh profile and will make a journey assert
  against someone else's logged day — this cost an investigation already (N2).
- `PulseApp` takes `store`, not `initialRoute`; host `PulseShell` directly.

---

## Step 5 — Tier 2 and Tier 3

Governing plan §4 Step 5, unchanged. Tier-2 transitions generated from the
graphify route graph under the four inclusion rules in its §3; Tier-3
table-driven from the equivalence-class matrix.

Note for Tier 3: the eight fabricated screens below will fail honest
data-response cases, because they do not respond to data at all. Either fix
them first or exclude them explicitly with a reason.

---

## Step 6 — report

[QA_FINDINGS.md](QA_FINDINGS.md) already exists and is current. Final pass:
close out O1–O9 and N3, record the Tier-2/3 results, update the release doc's
Phase 7 row.

---

## The fabricated screens — still outstanding

Eight screens remain invented end to end
([QA_FINDINGS.md](QA_FINDINGS.md) §3): Weekly Report, Streaks, Activity Detail,
Widgets/Watch, both calendars, Today's sips, the notification list. Plus N1 —
the onboarding "Enable Notifications" button is a stub that can grant nothing.

These were deliberately scoped out of Step 1. They are **not** scheduled above
because fixing them is the same class of product decision as N3: each needs
either store wiring that does not exist yet or an agreed empty state.

**They block meaningful goldens.** Approving reference images while these
screens show invented figures means a later honest fix reads as a regression.

---

## Goldens — when to commit the images

Not yet committed, deliberately. The sequence:

1. Finish 3a so no render overflows.
2. Decide the fabricated screens and N3 — their fixes change what the images
   should show.
3. Then capture and commit, reviewing each image rather than approving in bulk.

Committing them earlier bakes 43 overflowing renders and a screenful of
invented data in as the approved reference.

---

## Summary of what needs a decision, not code

| Item | Decision |
|---|---|
| N3 | Implement the goal calculation, or stop claiming it (recommend C: stop claiming now, implement as its own item) |
| 8 fabricated screens | Store-wire or empty-state each |
| N1 | Wire the onboarding notification button, or remove it |
| Goldens | Confirm the above before images are approved |

Everything else above is mechanical and can proceed without further input.
