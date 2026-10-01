# PULSE — Play Store listing copy

Written for: whoever fills in the Play Console form. Every field Google
requires for a first submission is below, ready to paste.

Tone follows §85 and the rule the app is built on: **say what is true, promise
nothing the app does not do.** No fake urgency, no shame, no medical claim.
Where a capability is not in v1, the copy stays silent rather than hinting.

---

## App details

| Field | Value |
|---|---|
| App name (30 char max) | `PulseFit — Nutrition & Fitness` (30) |
| Short description (80 max) | `Track meals, workouts and progress. Private by default, works offline.` (70) |
| Category | Health & Fitness |
| Tags | Nutrition, Fitness, Calorie counter, Workout log |
| Contact email | *(owner to supply)* |
| Website | *(optional — leave blank if none)* |

---

## Full description (4000 char max — this is ~1,450)

```
PULSE is a nutrition and fitness tracker that keeps your data on your phone.

No account is required to use it. Nothing is uploaded, nothing is sold, and
the app works with no connection at all.

WHAT IT DOES

• Food diary — log meals from a built-in food library with calories, protein,
  carbs, fat and fibre per serving.
• Daily plan from your own body — PULSE estimates your energy needs from the
  age, height, weight and activity level you enter, then adjusts for the goal
  and pace you choose. Every target is calculated, never a default dressed up
  as advice.
• Workouts — follow a built-in library, record sets and reps as you go, and
  keep a history of what you finished.
• Progress — weight trend, measurements, photos and a weekly summary built
  only from days you actually logged.
• Water, steps and habits — simple daily tracking with honest totals.
• Reminders — optional, supportive, and never guilt-based.

HOW IT TREATS YOU

PULSE shows you what you recorded. If you have not logged a day, it says so
rather than filling the gap with an estimate. Streaks celebrate consistency
and never punish a miss, and the app never changes a calorie target silently.

PRIVACY

Your logs live on your device. There is no account, no sync service and no
advertising profile built from your health data.

NOT MEDICAL ADVICE

PULSE is a tracking tool, not a medical device. Targets are estimates. Talk to
a qualified professional before making significant changes to how you eat or
train, particularly if you have a health condition.
```

---

## Required before submission

| Item | State |
|---|---|
| Signed AAB | ✅ `build/app/outputs/bundle/release/app-release.aab` (58 MB) |
| App icon 512×512 PNG | ⬜ needs export |
| Feature graphic 1024×500 | ⬜ needs design |
| Phone screenshots (2–8, min 320 px) | ⬜ capture from emulator |
| Privacy policy URL | ⬜ **required** — Play rejects without it |
| Content rating questionnaire | ⬜ in console |
| Data safety form | ⬜ in console — see below |
| Target audience | ⬜ 18+ recommended (fitness/nutrition) |

### Data safety answers

These must match what the app actually does, and for v1 that is simple:

- **Does your app collect or share user data?** No.
- **Is data encrypted in transit?** Not applicable — no data leaves the device.
- **Can users request deletion?** Yes — Settings → Privacy → Delete My Data
  erases everything, in memory and on disk.

If ads are enabled before launch, this changes: Google Mobile Ads collects a
device advertising identifier, and the form must say so. **Do not submit the
"no data collected" answer with live ads in the build.**

---

## Screenshots to capture

Take these on the Pixel 7 emulator after walking onboarding, so figures are
real rather than empty:

1. Today dashboard with a logged meal
2. Food diary
3. The daily plan (onboarding result — it is the honest-calculation story)
4. Workout in progress
5. Weight progress chart
6. Weekly report

```bash
adb -s emulator-5554 exec-out screencap -p > shot1.png
```

Note: `adb screencap` returns black frames on the Moto Edge 30. Use the
emulator.

---

## Known gaps to keep out of the listing

Do not mention, imply or screenshot any of these — they are not in v1:

- Barcode scanning
- Apple Health / Health Connect sync
- Meal photo analysis (AI)
- The trainer plan-builder, PDF export and WhatsApp sharing (planned v1.1)

Screenshot 3 is safe because the plan really is computed. Avoid any shot of a
screen that still carries placeholder AI content.
