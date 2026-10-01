import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'consistency_service.dart';
import 'measurements.dart';
import 'monetization.dart';
import 'nutrition_service.dart';
import 'persistence/local_backend.dart';
import 'progress_photos.dart';
import 'reminders.dart';
import 'workout_session.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PULSE APP STATE — lightweight InheritedNotifier store (no external
/// deps, implementable in React Native too). All user data is captured
/// during onboarding (§14); nothing is pre-filled.
/// Analytics events are annotated as `track('event_name')` calls.
/// Privacy rule: never track sensitive health values, only behavior.
/// ═══════════════════════════════════════════════════════════════════

enum MealType { breakfast, lunch, dinner, snacks }

extension MealTypeName on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snacks => 'Snacks',
      };
}

class FoodItem {
  final String id;
  final String name;
  final String serving; // "150 g"
  final double kcalPerServing;
  final double protein; // g per serving
  final double carbs;
  final double fat;
  final double fiber;
  final bool frequent;

  const FoodItem({
    required this.id,
    required this.name,
    required this.serving,
    required this.kcalPerServing,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.frequent = false,
  });
}

class DiaryEntry {
  final String id;
  final FoodItem food;
  final double servings;
  final MealType meal;
  DiaryEntry({required this.id, required this.food, required this.servings, required this.meal});

  double get kcal => food.kcalPerServing * servings;
  double get protein => food.protein * servings;
  double get carbs => food.carbs * servings;
  double get fat => food.fat * servings;
}

class Goals {
  double calorieGoal;
  double proteinGoal;
  double carbGoal;
  double fatGoal;
  double waterGoalLiters;
  int stepGoal;
  double targetWeightKg;
  int workoutsPerWeek;
  Goals({
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    required this.waterGoalLiters,
    required this.stepGoal,
    required this.targetWeightKg,
    required this.workoutsPerWeek,
  });
  Goals clone() => Goals(
      calorieGoal: calorieGoal, proteinGoal: proteinGoal, carbGoal: carbGoal,
      fatGoal: fatGoal, waterGoalLiters: waterGoalLiters, stepGoal: stepGoal,
      targetWeightKg: targetWeightKg, workoutsPerWeek: workoutsPerWeek);
}

/// A single weigh-in record (local-first persistence model).
class WeightRecord {
  final DateTime date;
  final double kg;
  const WeightRecord(this.date, this.kg);
  double get weightKg => kg;
}

/// App-wide change store.
class PulseStore extends ChangeNotifier {
  PulseStore();

  /// Construct and immediately restore user data from the local backend.
  /// Await before first use so derived totals reflect persisted state.
  Future<void> initLocal(LocalRepository repository) =>
      attachPersistence(repository);

  /// Watch access used across screens: PulseStore.of(context).
  static PulseStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PulseScope>();
    assert(scope != null, 'PulseScope missing — wrap the app in PulseScope.');
    return scope!.notifier!;
  }

  // ── Profile (§14): captured during onboarding, never pre-filled ───
  // A new install shows the onboarding flow first and every figure below
  // comes from the person using the app. Empty name == not yet onboarded.
  String userName = '';
  String userFirstName = '';
  int age = 0;
  double heightCm = 0;
  double startWeight = 0;
  double currentWeight = 0;
  String memberSince = '';

  /// True once onboarding has captured a profile (§14). Drives the launch
  /// route: no profile yet → onboarding rather than the dashboard.
  bool get hasProfile => userName.isNotEmpty;

  /// Starting targets, held only until onboarding computes the user's own
  /// from their details (§14 step 9, see energy_plan.dart). Generic on
  /// purpose: they are what a profile-less install shows, never a claim
  /// about anybody. The previous comment here said onboarding overwrote
  /// them, which was false until N3 was fixed — setTargets had no carb or
  /// fat parameter at all, so these survived the whole flow.
  final Goals goals = Goals(
    calorieGoal: 2000, proteinGoal: 120, carbGoal: 200, fatGoal: 65,
    waterGoalLiters: 2.5, stepGoal: 8000, targetWeightKg: 0, workoutsPerWeek: 3,
  );

  // ── Today's logged state — empty until the user logs something ────
  final List<DiaryEntry> diary = [];

  double activityCaloriesBurned = 0;
  double stepsToday = 0;
  double waterLogged = 0;
  int workoutsCompletedToday = 0;

  /// ── WP3.5 Reminders (§58/§64) ───────────────────────────────────
  /// Models persist in the snapshot; OS scheduling lives behind the
  /// injectable [ReminderScheduler] seam (production wires the plugin).
  late final ReminderManager reminders = ReminderManager(
    onChanged: () {
      _markDirty();
      notifyListeners();
    },
  );

  /// ── WP3.4 Habit toggles (§40 "customize which habits are tracked") ─
  /// Starts from the catalog defaults; persisted so a user's choices
  /// survive restarts. Keyed by habit name.
  final Map<String, bool> habitEnabled = {for (final h in PulseData.habits) h.name: h.on};

  bool toggleHabit(String name) {
    final v = !(habitEnabled[name] ?? true);
    habitEnabled[name] = v;
    _markDirty();
    notifyListeners();
    return v;
  }

  List<({String name, IconData icon, Color color, String progress, bool on})> get activeHabits =>
      PulseData.habits.where((h) => habitEnabled[h.name] ?? h.on).toList(growable: false);

  /// ── WP3.2 Nutrition service accessor ────────────────────────────
  /// The single source of truth for calorie/macro figures. Screens that
  /// need fiber or per-meal totals read this instead of recomputing.
  DayNutrition get nutrition => NutritionService.forToday(this);

  /// ── WP3.4 Consistency engine accessor ───────────────────────────
  ConsistencyStore get consistency => ConsistencyStore(this);

  /// ── WP3.1 Workout Session Engine ────────────────────────────────
  /// Single source of truth for active + completed sessions. Every
  /// mutation persists via autosave and notifies listeners.
  late final WorkoutSessionManager sessions =
      WorkoutSessionManager(onChanged: () {
    _markDirty();
    notifyListeners();
  });

  /// Start a workout for [templateName]; returns the live session.
  WorkoutSession startWorkout(String templateName) {
    track('workout_started');
    return sessions.start(templateName);
  }

  /// Record one completed set (Active Workout screen).
  SetRecord logSet({required int exerciseIndex, required int setNumber,
      required int reps, required double weightKg}) =>
      sessions.logSet(
          exerciseIndex: exerciseIndex,
          setNumber: setNumber,
          reps: reps,
          weightKg: weightKg);

  /// Undo the last logged set — symmetric with logSet (§76 undo).
  SetRecord? undoLastSet() => sessions.undoLastSet();

  /// Rate the most recently completed session (Workout Complete screen).
  void rateLastWorkout(int rating) {
    if (sessions.history.isEmpty) return;
    final s = sessions.history.first; // newest-first view
    // mutate through a manager-level API so autosave fires
    sessions.rate(s.id, rating);
    _markDirty();
    notifyListeners();
  }

  /// Finish (complete or end-early) the active session, credit derived
  /// calories, bump today's workout count, and persist everything.
  WorkoutSession? finishWorkout({int? rating}) {
    final s = sessions.finish(rating: rating);
    if (s == null) return null;
    if (s.totalSets > 0) {
      activityCaloriesBurned += s.estimatedKcal;
      workoutsCompletedToday += 1;
    }
    track('workout_completed');
    _markDirty();
    notifyListeners();
    return s;
  }

  /// ── WP3.3 Body Measurements + Progress Photos (§45/§46) ─────────
  /// Metadata-only photo book — image bytes never enter the snapshot.
  /// Both start empty: the trend screens show their empty state until the
  /// user logs a measurement, and logging a value for today upserts rather
  /// than duplicates (same semantics as the weight log).
  MeasurementBook measurements = MeasurementBook();
  final ProgressPhotoBook progressPhotos = ProgressPhotoBook();

  /// Log (or same-day replace) a measurement. Returns false for unknown
  /// sites or invalid values so the UI can show inline errors (§75).
  bool logMeasurement(String siteId, double value, {DateTime? onDate}) {
    final ok = measurements.log(siteId, onDate ?? DateTime.now(), value);
    if (ok) {
      track('measurement_logged');
      _markDirty();
      notifyListeners();
    }
    return ok;
  }

  /// Add a custom measurement site (§45 "Allow custom measurement").
  /// Returns false when the label collides with an existing site.
  bool addMeasurementSite(String label, {String unit = 'cm', bool lowerIsBetter = true}) {
    final id = 'custom_${label.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}';
    final ok = measurements.addSite(MeasurementSite(id: id, label: label, unit: unit, lowerIsBetter: lowerIsBetter));
    if (ok) {
      _markDirty();
      notifyListeners();
    }
    return ok;
  }

  /// Register a captured progress photo. [fileName] points into the app's
  /// private documents directory; nothing is uploaded (§46 privacy).
  void addProgressPhoto(PhotoPose pose, String fileName, {DateTime? onDate}) {
    progressPhotos.add(ProgressPhoto(
      id: 'ph_${DateTime.now().microsecondsSinceEpoch}',
      date: onDate ?? DateTime.now(),
      pose: pose,
      fileName: fileName,
      weightKgAtCapture: currentWeightLive ?? currentWeight,
    ));
    track('progress_photo_added');
    _markDirty();
    notifyListeners();
  }

  /// Remove a photo record; returns the file name so the caller can
  /// delete the image from disk atomically (§60 erasure).
  String? removeProgressPhoto(String id) {
    final f = progressPhotos.remove(id);
    if (f != null) {
      _markDirty();
      notifyListeners();
    }
    return f;
  }

  /// Weigh-in history (local-first). Seeded with the sample trend so
  /// charts have data on first launch; new entries are appended live.
  final List<WeightRecord> weights = [];
  /// ── PHASE 4: subscription state (single source of truth) ──────
  /// Legacy `premium` reads now derive from the entitlement engine so
  /// trial expiry, paid plans and ad policy can never disagree with UI.
  final SubscriptionState subscription = SubscriptionState();
  late final Entitlements entitlements = Entitlements(() => subscription);

  /// Back-compat getter used across screens (§61/§87 premium states).
  bool get premium => entitlements.isPro;
  bool get adsAllowed => entitlements.shouldShowAds;
  PulsePlan get plan => entitlements.effectivePlan();
  String? get trialBanner => entitlements.trialBannerText();

  /// Start the one-shot 3-day Pro trial via the purchase gateway seam.
  /// Platform billing, attached at startup when the build wires it. Null
  /// means the stub is used, which is what tests and a bare run want.
  PurchaseGateway? purchaseGateway;

  /// Platform ads, attached at startup when the build wires it.
  AdProvider? adProvider;

  Future<bool> startTrial({PurchaseGateway? gateway}) async {
    if (subscription.trialUsed || entitlements.isPro) return false;
    final gw = gateway ?? purchaseGateway ?? StubPurchaseGateway();
    if (!await gw.purchase(PulsePricing.yearly)) return false;
    if (!entitlements.beginTrial()) return false;
    track('trial_started');
    _markDirty();
    notifyListeners();
    return true;
  }

  /// Complete a paid purchase (monthly/yearly price from PulsePricing).
  Future<bool> purchasePro(PulsePrice price, {PurchaseGateway? gateway}) async {
    final gw = gateway ?? purchaseGateway ?? StubPurchaseGateway();
    if (!await gw.purchase(price)) return false;
    entitlements.activatePaid(price);
    track('subscription_purchased', {'plan': price.cadence});
    _markDirty();
    notifyListeners();
    return true;
  }

  /// Cancel → free immediately (data is never deleted — §60 promise).
  void cancelSubscription() {
    entitlements.revertToFree();
    track('subscription_cancelled');
    _markDirty();
    notifyListeners();
  }

  /// Called on app resume: settles an expired trial into persisted free.
  void settleSubscription() {
    if (entitlements.settleExpired()) {
      track('trial_expired');
      _markDirty();
      notifyListeners();
    }
  }

  bool offlineMode = false;
  String unitsMass = 'kg'; // kg | lb
  String unitsLength = 'cm'; // cm | ft+in
  String unitsVolume = 'ml'; // ml | oz
  String unitsDistance = 'km'; // km | mi

  static const weightHistory = <(String, double)>[
    ('Jun 1', 84.5), ('Jun 15', 83.6), ('Jul 1', 83.1), ('Jul 15', 82.4),
    ('Aug 1', 81.9), ('Aug 15', 81.0), ('Sep 1', 80.6), ('Sep 15', 80.1),
  ];
  static const weeklyCalories = <int>[2120, 1980, 2065, 2210, 2040, 1995, 2145];

  /// Fiber goal in grams — general adult guidance (displayed as an
  /// informational target; PULSE does not provide medical advice).
  static const double fiberGoal = 28;

  // ── Derived totals ────────────────────────────────────────────────
  double get foodKcal => diary.fold(0.0, (s, e) => s + e.kcal);
  double get protein => diary.fold(0.0, (s, e) => s + e.protein);
  double get carbs => diary.fold(0.0, (s, e) => s + e.carbs);
  double get fat => diary.fold(0.0, (s, e) => s + e.fat);
  double get remainingKcal => goals.calorieGoal - foodKcal + activityCaloriesBurned;
  double kcalFor(MealType m) =>
      diary.where((e) => e.meal == m).fold(0.0, (s, e) => s + e.kcal);

  /// Daily Score — a simple day-progress composite, explicitly NOT a
  /// medical health score.
  double get dailyScore {
    double clampP(double v, double g) => (v / g).clamp(0.0, 1.0);
    final nutrition = clampP(foodKcal, goals.calorieGoal) * 0.4 +
        clampP(protein, goals.proteinGoal) * 0.2;
    final activity = clampP(stepsToday, goals.stepGoal.toDouble()) * 0.2 +
        clampP(waterLogged, goals.waterGoalLiters) * 0.2;
    return ((nutrition + activity) * 100).roundToDouble();
  }

  void addFood(FoodItem f, double servings, MealType meal) {
    diary.add(DiaryEntry(id: DateTime.now().microsecondsSinceEpoch.toString(),
        food: f, servings: servings, meal: meal));
    track('food_logged');
    _markDirty();
    notifyListeners();
  }

  void removeEntry(String id) {
    diary.removeWhere((e) => e.id == id);
    _markDirty();
    notifyListeners();
  }

  void addWater(double liters) {
    waterLogged = (waterLogged + liters).clamp(0.0, 10.0);
    track('water_logged');
    _markDirty();
    notifyListeners();
  }

  void logWeight(double kg, {DateTime? date}) {
    final now = date ?? DateTime.now();
    // Day-granular upsert: re-logging a day replaces that day's record
    // (seed rows included) instead of duplicating it.
    weights.removeWhere((w) =>
        w.date.year == now.year && w.date.month == now.month && w.date.day == now.day);
    weights.add(WeightRecord(now, kg));
    weights.sort((a, b) => a.date.compareTo(b.date));
    currentWeightLive = kg;
    currentWeight = kg; // headline figure stays in sync with latest entry
    track('weight_logged');
    _markDirty();
    notifyListeners();
  }

  void deleteWeight(DateTime date) {
    weights.removeWhere((w) =>
        w.date.year == date.year && w.date.month == date.month && w.date.day == date.day);
    if (weights.isNotEmpty) {
      currentWeightLive = weights.last.kg;
      currentWeight = weights.last.kg;
    } else {
      currentWeightLive = null; // fall back to profile default
    }
    track('weight_deleted');
    _markDirty();
    notifyListeners();
  }

  /// Null until the first real weigh-in; the headline figure falls back to
  /// the profile weight captured during onboarding.
  double? currentWeightLive;
  double get displayWeight => currentWeightLive ?? currentWeight;

  /// Live current weight — latest weigh-in or the seeded sample value.
  double get currentWeightKg => weights.isEmpty ? currentWeight : weights.last.kg;

  /// Normalized (date-ordered) weight series for Chart/WeightTrend.
  List<double> get weightSeries => weights.map((w) => w.kg).toList(growable: false);

  bool get hasAnyData =>
      diary.isNotEmpty || weights.isNotEmpty || waterLogged > 0 || workoutsCompletedToday > 0;

  // ── Accessibility + appearance settings (§70) ────────────────────
  bool highContrast = false;
  bool largeText = false;
  bool reduceMotion = false;
  ThemeMode themeMode = ThemeMode.system;
  bool analyticsEnabled = true;

  void setHighContrast(bool v) { highContrast = v; track('accessibility_changed'); _markDirty();
    notifyListeners(); }
  void setLargeText(bool v) { largeText = v; _markDirty();
    notifyListeners(); }
  void setReduceMotion(bool v) { reduceMotion = v; _markDirty();
    notifyListeners(); }
  void setThemeMode(ThemeMode m) { themeMode = m; _markDirty();
    notifyListeners(); }
  void setAnalytics(bool v) { analyticsEnabled = v; _markDirty();
    notifyListeners(); }

  // ── Units (§59) ──────────────────────────────────────────────────
  void setUnitsWeight(String u) { unitsMass = u; _markDirty();
    notifyListeners(); }
  void setUnitsHeight(String u) { unitsLength = u; _markDirty();
    notifyListeners(); }
  void setUnitsVolume(String u) { unitsVolume = u; _markDirty();
    notifyListeners(); }
  void setUnitsDistance(String u) { unitsDistance = u; _markDirty();
    notifyListeners(); }
  String get unitsWeight => unitsMass;
  String get unitsHeight => unitsLength;

  /// Smart goal review seam (§51): updates multiple targets atomically and
  /// never silently alters calorie targets without an explicit call here.
  void setTargets({double? targetWeightKg, double? calorieGoal, double? proteinGoal}) {
    if (targetWeightKg != null) goals.targetWeightKg = targetWeightKg;
    if (calorieGoal != null) goals.calorieGoal = calorieGoal;
    if (proteinGoal != null) goals.proteinGoal = proteinGoal;
    track('goal_updated');
    _markDirty();
    notifyListeners();
  }

  /// §14 onboarding hand-off: records the profile the user actually entered,
  /// replacing the sample identity. Only non-null fields are applied so a
  /// partially completed flow never blanks what was already captured.
  void setProfile({
    String? name,
    int? age,
    double? heightCm,
    double? startWeightKg,
  }) {
    if (name != null && name.trim().isNotEmpty) {
      userName = name.trim();
      userFirstName = userName.split(' ').first;
    }
    if (age != null) this.age = age;
    if (heightCm != null) this.heightCm = heightCm;
    if (startWeightKg != null) startWeight = startWeightKg;
    track('profile_updated');
    _markDirty();
    notifyListeners();
  }

  void updateGoals(void Function(Goals g) edit) {
    edit(goals);
    track('goal_updated');
    _markDirty();
    notifyListeners();
  }

  void togglePremium() {
    // Dev/QA shortcut only — production paths use startTrial/purchasePro.
    if (subscription.plan.isPro) {
      cancelSubscription();
    } else {
      entitlements.beginTrial();
      track('trial_started');
      _markDirty();
      notifyListeners();
    }
  }

  void setOffline(bool v) {
    offlineMode = v;
    _markDirty();
    notifyListeners();
  }

  /// Analytics seam — behavior events only, never raw health values.
  /// Tests (and a future real SDK) can attach a sink to observe events.
  void Function(String event)? analyticsSink;
  void track(String event, [Map<String, String>? props]) {
    analyticsSink?.call(event);
    debugPrint('📊 pulse_analytics → $event ${props ?? ''}');
  }

  // ══════════════════════════════════════════════════════════════════
  // PHASE 2 — LOCAL PERSISTENCE (local-first, no external DB)
  //
  // Snapshot = JSON of everything the user created/changed: diary,
  // water, steps, activity kcal, weight history, goals, units,
  // appearance/accessibility settings and premium flag. Static sample
  // content (food catalog, workout library) is NOT persisted — it is
  // app data, not user data. Derived fields (currentWeightLive) are
  // recomputed on hydrate so state can never drift from source records.
  // ══════════════════════════════════════════════════════════════════

  LocalRepository? _repository;
  AutosaveCoordinator? _autosave;
  bool get persistenceEnabled => _repository != null;
  bool _hydratedFromDisk = false;
  bool get hydratedFromDisk => _hydratedFromDisk;

  /// Wire the local repository and restore any previously saved state.
  /// Safe to call more than once; awaits all pending writes first.
  Future<void> attachPersistence(LocalRepository repository,
      {ReminderScheduler? reminderScheduler}) async {
    await flushPendingSave();
    if (reminderScheduler != null) reminders.attachScheduler(reminderScheduler);
    _repository = repository;
    await repository.init();
    final snapshot = repository.readSnapshot();
    try {
      _hydrate(await snapshot);
    } catch (_) {
      // Defensive: a malformed-but-decodable snapshot must never brick
      // the app. Fall back to defaults and let the next save overwrite.
    }
    _autosave = AutosaveCoordinator(
      repository: repository,
      buildSnapshot: toSnapshot,
    );
  }

  void _hydrate(Map<String, dynamic>? s) {
    if (s == null) return;
    _hydratedFromDisk = true;

    final g = s['goals'];
    if (g is Map) {
      goals.calorieGoal = (g['calorie'] as num?)?.toDouble() ?? goals.calorieGoal;
      goals.proteinGoal = (g['protein'] as num?)?.toDouble() ?? goals.proteinGoal;
      goals.carbGoal = (g['carbs'] as num?)?.toDouble() ?? goals.carbGoal;
      goals.fatGoal = (g['fat'] as num?)?.toDouble() ?? goals.fatGoal;
      goals.waterGoalLiters = (g['waterGoal'] as num?)?.toDouble() ?? goals.waterGoalLiters;
      goals.stepGoal = (g['steps'] as num?)?.toInt() ?? goals.stepGoal;
      goals.targetWeightKg = (g['targetWeight'] as num?)?.toDouble() ?? goals.targetWeightKg;
      goals.workoutsPerWeek = (g['workoutsPerWeek'] as num?)?.toInt() ?? goals.workoutsPerWeek;
    }

    final entries = s['diary'];
    if (entries is List) {
      diary.clear();
      for (final e in entries.whereType<Map>()) {
        final foodId = e['foodId'];
        if (foodId is! String) continue;
        FoodItem food;
        try {
          food = PulseData.foodById(foodId);
        } catch (_) {
          continue; // unknown catalog id → skip entry, keep rest intact
        }
        diary.add(DiaryEntry(
          id: e['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
          food: food,
          servings: (e['servings'] as num?)?.toDouble() ?? 1,
          meal: MealType.values[(e['meal'] as num?)?.toInt() ?? 0],
        ));
      }
    }

    final prof = s['profile'];
    if (prof is Map) {
      final n = prof['name'];
      if (n is String && n.trim().isNotEmpty) {
        userName = n.trim();
        userFirstName = userName.split(' ').first;
      }
      age = (prof['age'] as num?)?.toInt() ?? age;
      heightCm = (prof['heightCm'] as num?)?.toDouble() ?? heightCm;
      startWeight = (prof['startWeight'] as num?)?.toDouble() ?? startWeight;
      final ms = prof['memberSince'];
      if (ms is String && ms.isNotEmpty) memberSince = ms;
    }

    final w = s['weights'];
    if (w is List && w.isNotEmpty) {
      weights.clear();
      for (final r in w.whereType<Map>()) {
        final d = DateTime.tryParse('${r['date']}');
        final kg = (r['kg'] as num?)?.toDouble();
        if (d != null && kg != null) weights.add(WeightRecord(d, kg));
      }
      weights.sort((a, b) => a.date.compareTo(b.date));
      currentWeightLive = weights.isEmpty ? null : weights.last.kg;
    }

    waterLogged = (s['water'] as num?)?.toDouble() ?? waterLogged;
    stepsToday = (s['steps'] as num?)?.toDouble() ?? stepsToday;
    activityCaloriesBurned =
        (s['activityKcal'] as num?)?.toDouble() ?? activityCaloriesBurned;
    workoutsCompletedToday =
        (s['workoutsToday'] as num?)?.toInt() ?? workoutsCompletedToday;
    // PHASE 4: hydrate full subscription state; legacy v1/v2 snapshots
    // stored only a bool → map true onto an active yearly plan.
    if (s['subscription'] is Map) {
      final loaded = SubscriptionState.fromJson((s['subscription'] as Map).cast<String, dynamic>());
      subscription.plan = loaded.plan;
      subscription.trialStartedAt = loaded.trialStartedAt;
      subscription.trialUsed = loaded.trialUsed;
      subscription.periodStart = loaded.periodStart;
      subscription.periodCadence = loaded.periodCadence;
    } else if (s['premium'] == true) {
      entitlements.activatePaid(PulsePricing.yearly);
    }
    settleSubscription();
    offlineMode = s['offline'] as bool? ?? offlineMode;

    if (s['units'] is Map) {
      final u = s['units'] as Map;
      unitsMass = u['mass'] as String? ?? unitsMass;
      unitsLength = u['length'] as String? ?? unitsLength;
      unitsVolume = u['volume'] as String? ?? unitsVolume;
      unitsDistance = u['distance'] as String? ?? unitsDistance;
    }
    if (s['settings'] is Map) {
      final st = s['settings'] as Map;
      highContrast = st['highContrast'] as bool? ?? highContrast;
      largeText = st['largeText'] as bool? ?? largeText;
      reduceMotion = st['reduceMotion'] as bool? ?? reduceMotion;
      analyticsEnabled = st['analytics'] as bool? ?? analyticsEnabled;
      themeMode = switch (st['theme'] as String?) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => themeMode,
      };
    }
    // schema v2 block — absent in v1 snapshots → empty history (safe).
    sessions.hydrate(s['workouts'] is Map
        ? (s['workouts'] as Map).cast<String, dynamic>()
        : null);
    // schema v3 block. Absent in v1/v2 snapshots → keep seeded sample
    // history (§84). Present but empty (post-"Delete My Data") → start
    // from a clean book so erased data never resurrects on restart.
    if (s['measurements'] is Map) {
      measurements = MeasurementBook();
      measurements.hydrate((s['measurements'] as Map).cast<String, dynamic>());
    }
    if (s['photos'] is Map) {
      progressPhotos.hydrate((s['photos'] as Map).cast<String, dynamic>());
    }
    // schema v4 block — reminders + habit toggles. Absent in older
    // snapshots → keep defaults (safe additive migration).
    if (s['reminders'] is Map) {
      reminders.hydrate((s['reminders'] as Map).cast<String, dynamic>());
    }
    if (s['habits'] is Map) {
      for (final e in (s['habits'] as Map).entries) {
        if (e.key is String && e.value is bool) habitEnabled[e.key as String] = e.value as bool;
      }
    }
    notifyListeners();
  }

  /// Serializable snapshot of all *user* state (see block comment).
  Map<String, dynamic> toSnapshot() => {
        'schemaVersion': kPulseSchemaVersion,
        'profile': {
          'name': userName,
          'age': age,
          'heightCm': heightCm,
          'startWeight': startWeight,
          'memberSince': memberSince,
        },
        'goals': {
          'calorie': goals.calorieGoal, 'protein': goals.proteinGoal,
          'carbs': goals.carbGoal, 'fat': goals.fatGoal,
          'waterGoal': goals.waterGoalLiters, 'steps': goals.stepGoal,
          'targetWeight': goals.targetWeightKg,
          'workoutsPerWeek': goals.workoutsPerWeek,
        },
        'diary': [
          for (final e in diary)
            {'id': e.id, 'foodId': e.food.id, 'servings': e.servings, 'meal': e.meal.index},
        ],
        'weights': [
          for (final r in weights) {'date': r.date.toIso8601String(), 'kg': r.kg},
        ],
        'water': waterLogged,
        'steps': stepsToday,
        'activityKcal': activityCaloriesBurned,
        'workoutsToday': workoutsCompletedToday,
        'workouts': sessions.toJson(),
        'measurements': measurements.toJson(),
        'photos': progressPhotos.toJson(),
        'reminders': reminders.toJson(),
        'habits': {...habitEnabled},
        'premium': premium, // legacy mirror for v1/v2 readers
        'subscription': subscription.toJson(),
        'offline': offlineMode,
        'units': {
          'mass': unitsMass, 'length': unitsLength,
          'volume': unitsVolume, 'distance': unitsDistance,
        },
        'settings': {
          'highContrast': highContrast, 'largeText': largeText,
          'reduceMotion': reduceMotion, 'analytics': analyticsEnabled,
          'theme': themeMode.name,
        },
      };

  /// Called by every mutation path — debounced disk write.
  void _markDirty() => _autosave?.request();

  /// Force completion of pending saves (app lifecycle `paused`/`detached`,
  /// or before tests assert on-disk state). No-op without persistence.
  Future<void> flushPendingSave() => _autosave?.flush() ?? Future.value();

  /// Privacy Center "Delete My Data" (§60): wipes memory + disk atomically.
  Future<void> deleteAllLocalData() async {
    diary.clear();
    weights.clear();
    waterLogged = 0;
    stepsToday = 0;
    activityCaloriesBurned = 0;
    workoutsCompletedToday = 0;
    currentWeightLive = null;
    sessions.discardActive(); // active session lives in memory + disk — wipe both
    measurements = MeasurementBook(); // §60: seeded sample history erased too
    progressPhotos.eraseAll();
    reminders.eraseAll();
    // §60/§97: entitlement state is account data — erased with everything
    // else. (Store receipt restoration remains the recovery path.)
    entitlements.revertToFree();
    subscription.trialStartedAt = null;
    subscription.trialUsed = false;
    habitEnabled.updateAll((k, v) => PulseData.habits.firstWhere((h) => h.name == k).on);
    _hydratedFromDisk = false;
    final repo = _repository;
    if (repo != null) {
      _autosave?.dispose();
      _autosave = null;
      await repo.clearAll();
      _autosave = AutosaveCoordinator(
        repository: repo,
        buildSnapshot: toSnapshot,
      );
    }
    // clearAll removed the snapshot; stop the just-recreated coordinator
    // from immediately rewriting a (now-empty-but-seeded) snapshot.
    _autosave?.cancelPending();
    track('data_deleted');
    notifyListeners();
  }

  /// Export bundle for Privacy Center "Download My Data" (§60).
  String exportUserDataJson() =>
      const JsonEncoder.withIndent('  ').convert(toSnapshot());
}

/// ═══════════════════════════════════════════════════════════════════
/// STATIC SAMPLE DATA — realistic content, zero placeholder text.
/// ═══════════════════════════════════════════════════════════════════
class PulseData {
  PulseData._();

  static const foods = <FoodItem>[
    FoodItem(id: 'f1', name: 'Greek Yogurt', serving: '150 g', kcalPerServing: 118, protein: 15, carbs: 8, fat: 3, fiber: 0, frequent: true),
    FoodItem(id: 'f2', name: 'Banana', serving: '1 medium', kcalPerServing: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1, frequent: true),
    FoodItem(id: 'f3', name: 'Grilled Chicken Breast', serving: '150 g', kcalPerServing: 248, protein: 46, carbs: 0, fat: 5.4, fiber: 0, frequent: true),
    FoodItem(id: 'f4', name: 'Brown Rice', serving: '1 cup', kcalPerServing: 216, protein: 5, carbs: 45, fat: 1.8, fiber: 3.5, frequent: true),
    FoodItem(id: 'f5', name: 'Whole Egg', serving: '1 large', kcalPerServing: 72, protein: 6.3, carbs: 0.4, fat: 4.8),
    FoodItem(id: 'f6', name: 'Salmon Fillet', serving: '140 g', kcalPerServing: 280, protein: 34, carbs: 0, fat: 15.6),
    FoodItem(id: 'f7', name: 'Oatmeal', serving: '1 cup cooked', kcalPerServing: 158, protein: 6, carbs: 27, fat: 3.2, fiber: 4),
    FoodItem(id: 'f8', name: 'Almonds', serving: '28 g', kcalPerServing: 164, protein: 6, carbs: 6.1, fat: 14.2, fiber: 3.5),
    FoodItem(id: 'f9', name: 'Apple', serving: '1 medium', kcalPerServing: 95, protein: 0.5, carbs: 25, fat: 0.3, fiber: 4.4),
    FoodItem(id: 'f10', name: 'Avocado', serving: '1/2 fruit', kcalPerServing: 160, protein: 2, carbs: 8.5, fat: 14.7, fiber: 6.4),
    FoodItem(id: 'f11', name: 'Sweet Potato', serving: '1 medium', kcalPerServing: 112, protein: 2.3, carbs: 26, fat: 0.15, fiber: 3.8),
    FoodItem(id: 'f12', name: 'Cottage Cheese', serving: '1/2 cup', kcalPerServing: 110, protein: 12, carbs: 4.8, fat: 5),
    FoodItem(id: 'f13', name: 'Broccoli', serving: '1 cup', kcalPerServing: 55, protein: 3.7, carbs: 11, fat: 0.6, fiber: 5.1),
    FoodItem(id: 'f14', name: 'Whey Protein Shake', serving: '1 scoop + water', kcalPerServing: 120, protein: 24, carbs: 3, fat: 1.5),
    FoodItem(id: 'f15', name: 'Black Coffee', serving: '1 cup', kcalPerServing: 2, protein: 0.1, carbs: 0, fat: 0),
    FoodItem(id: 'f16', name: 'Whole Wheat Toast', serving: '1 slice', kcalPerServing: 80, protein: 4, carbs: 14, fat: 1, fiber: 2),
    FoodItem(id: 'f17', name: 'Olive Oil', serving: '1 tbsp', kcalPerServing: 119, protein: 0, carbs: 0, fat: 13.5),
    FoodItem(id: 'f18', name: 'Chickpeas', serving: '1/2 cup', kcalPerServing: 134, protein: 7, carbs: 22, fat: 2.1, fiber: 6.3),
  ];

  static FoodItem foodById(String id) => foods.firstWhere((f) => f.id == id);

  static const savedMeals = <({String name, double kcal, double protein, List<String> foodIds})>[
    (name: 'High-Protein Breakfast', kcal: 620, protein: 42, foodIds: ['f1', 'f5', 'f5', 'f16', 'f16']),
    (name: 'Chicken Rice Bowl', kcal: 710, protein: 53, foodIds: ['f3', 'f4', 'f13', 'f17']),
    (name: 'Overnight Oats Jar', kcal: 430, protein: 22, foodIds: ['f7', 'f1', 'f8', 'f9']),
    (name: 'Salmon & Sweet Potato', kcal: 640, protein: 41, foodIds: ['f6', 'f11', 'f13']),
  ];

  static const recipes = <({String name, int minutes, double kcalPerServing, int servings, String tag})>[
    (name: 'Mediterranean Chickpea Bowl', minutes: 20, kcalPerServing: 520, servings: 2, tag: 'High protein'),
    (name: 'Berry Protein Smoothie', minutes: 5, kcalPerServing: 280, servings: 1, tag: 'Quick'),
    (name: 'Herb Roasted Chicken Tray Bake', minutes: 45, kcalPerServing: 590, servings: 4, tag: 'Meal prep'),
    (name: 'Veggie Fried Brown Rice', minutes: 15, kcalPerServing: 410, servings: 2, tag: 'Vegetarian'),
  ];

  static const groceryCategories = <String, List<({String item, bool done})>>{
    'Produce': [(item: 'Bananas × 6', done: false), (item: 'Broccoli × 3', done: true), (item: 'Apples × 4', done: false), (item: 'Spinach 200 g', done: false)],
    'Protein': [(item: 'Chicken breast 1.2 kg', done: false), (item: 'Eggs × 12', done: true), (item: 'Salmon fillets × 2', done: false)],
    'Dairy': [(item: 'Greek yogurt × 4', done: false), (item: 'Cottage cheese 500 g', done: false)],
    'Grains': [(item: 'Brown rice 500 g', done: true), (item: 'Whole wheat bread', done: false), (item: 'Rolled oats 1 kg', done: false)],
    'Pantry': [(item: 'Olive oil', done: true), (item: 'Almonds 250 g', done: false), (item: 'Chickpeas 2 cans', done: false)],
  };

  // ── Workouts ──────────────────────────────────────────────────────
  static const workoutLibrary = <({
    String name, int minutes, String level, String category, int exercises, int kcal, List<String> equipment,
  })>[
    (name: 'Upper Body Strength', minutes: 45, level: 'Intermediate', category: 'Strength', exercises: 8, kcal: 280, equipment: ['Dumbbells', 'Bench']),
    (name: 'Full Body Strength', minutes: 45, level: 'Intermediate', category: 'Strength', exercises: 9, kcal: 310, equipment: ['Barbell', 'Bench']),
    (name: 'Morning Mobility', minutes: 12, level: 'Beginner', category: 'Mobility', exercises: 6, kcal: 60, equipment: ['None']),
    (name: 'HIIT Burn', minutes: 20, level: 'Advanced', category: 'HIIT', exercises: 7, kcal: 240, equipment: ['None']),
    (name: 'Upper Body Push', minutes: 35, level: 'Intermediate', category: 'Strength', exercises: 6, kcal: 220, equipment: ['Dumbbells']),
    (name: 'Restorative Yoga', minutes: 25, level: 'Beginner', category: 'Yoga', exercises: 8, kcal: 95, equipment: ['Mat']),
    (name: 'Core Circuit', minutes: 18, level: 'Beginner', category: 'Strength', exercises: 6, kcal: 140, equipment: ['Mat']),
    (name: 'Tempo Run Intervals', minutes: 32, level: 'Advanced', category: 'Cardio', exercises: 1, kcal: 380, equipment: ['None']),
  ];

  static const upperBodyExercises = <({String name, String sets, String muscle})>[
    (name: 'Dumbbell Bench Press', sets: '4 × 10', muscle: 'Chest'),
    (name: 'Shoulder Press', sets: '3 × 10', muscle: 'Shoulders'),
    (name: 'One-Arm Row', sets: '4 × 12', muscle: 'Back'),
    (name: 'Lateral Raise', sets: '3 × 15', muscle: 'Shoulders'),
    (name: 'Biceps Curl', sets: '3 × 12', muscle: 'Arms'),
    (name: 'Triceps Extension', sets: '3 × 12', muscle: 'Arms'),
    (name: 'Push-Up Finisher', sets: '2 × AMRAP', muscle: 'Chest'),
    (name: 'Face Pull', sets: '3 × 15', muscle: 'Shoulders'),
  ];

  static const habits = <({String name, IconData icon, Color color, String progress, bool on})>[
    (name: 'Water', icon: Icons.water_drop_outlined, color: PulsePalette.water, progress: '1.7 / 2.6 L', on: true),
    (name: 'Steps', icon: Icons.directions_walk_rounded, color: PulsePalette.steps, progress: '6,842 / 8,000', on: true),
    (name: 'Sleep', icon: Icons.bedtime_outlined, color: PulsePalette.sleep, progress: '7 h 12 m', on: true),
    (name: 'Fruit & vegetables', icon: Icons.eco_outlined, color: PulsePalette.fiber, progress: '3 / 5 servings', on: true),
    (name: 'Workout', icon: Icons.fitness_center_rounded, color: PulsePalette.exercise, progress: 'Planned 6:30 PM', on: true),
    (name: 'Mindfulness', icon: Icons.self_improvement_rounded, color: PulsePalette.info, progress: 'Not yet today', on: false),
  ];

  static const insights = <({String title, String body, String action, IconData icon, Color color})>[
    (title: 'Protein', body: 'You reached at least 90% of your protein goal on 5 of the last 7 days.', action: 'Keep it up — aim for 7 of 7 this week.', icon: Icons.bolt_rounded, color: PulsePalette.protein),
    (title: 'Activity', body: 'Your average daily steps increased 12% this month.', action: 'A 10-minute walk would put you close to today\'s step target.', icon: Icons.trending_up_rounded, color: PulsePalette.steps),
    (title: 'Consistency', body: 'You\'ve logged meals on 18 of the last 21 days.', action: 'Tomorrow is another opportunity to stay consistent.', icon: Icons.check_circle_rounded, color: PulsePalette.success),
    (title: 'Hydration', body: 'You hit your water goal 6 days this week — one short of your best week yet.', action: 'Log one more glass to set a new personal best.', icon: Icons.water_drop_rounded, color: PulsePalette.water),
  ];

  static const notifications = <({String title, String body, String time, IconData icon, Color color})>[
    (title: 'Hydration reminder', body: 'You\'re 700 ml away from today\'s water goal.', time: '2:14 PM', icon: Icons.water_drop_rounded, color: PulsePalette.water),
    (title: 'Workout reminder', body: 'Upper Body Strength is planned for 6:30 PM.', time: '1:00 PM', icon: Icons.fitness_center_rounded, color: PulsePalette.exercise),
    (title: 'Weekly summary', body: 'Your weekly report is ready.', time: 'Yesterday', icon: Icons.summarize_rounded, color: PulsePalette.primary),
    (title: 'Goal milestone', body: 'You\'ve completed 20 workouts. That\'s real consistency.', time: 'Mon', icon: Icons.emoji_events_rounded, color: PulsePalette.warning),
  ];

  static const achievements = <({String name, String detail, IconData icon, bool earned})>[
    (name: 'First Workout', detail: 'Completed Aug 3', icon: Icons.flag_rounded, earned: true),
    (name: '10 Workouts', detail: 'Completed Sep 12', icon: Icons.sports_martial_arts_rounded, earned: true),
    (name: '7-Day Logging Consistency', detail: 'Current streak activity', icon: Icons.calendar_month_rounded, earned: true),
    (name: '50 km Walked', detail: '48.2 km — almost there', icon: Icons.route_rounded, earned: false),
    (name: '100,000 Steps', detail: '61,300 this cycle', icon: Icons.directions_walk_rounded, earned: false),
    (name: 'First Recipe Created', detail: 'Locked until you create one', icon: Icons.menu_book_rounded, earned: false),
  ];

  static const coachPrompts = <String>[
    'What should I eat for dinner?',
    'How can I reach my protein target?',
    'Build me a 30-minute workout.',
    'How did I do this week?',
    'Why was my calorie intake higher yesterday?',
  ];

  static const weeklyStepChart = <double>[0.72, 0.95, 0.61, 1.0, 0.88, 0.45, 0.86]; // vs 8,000 goal
}

/// Palette mirror for const contexts in data above.
class PulsePalette {
  const PulsePalette._();
  static const Color water = Color(0xFF3B82C4);
  static const Color steps = Color(0xFF14919B);
  static const Color sleep = Color(0xFF8E6BC9);
  static const Color fiber = Color(0xFF4CAF6D);
  static const Color exercise = Color(0xFF0E7C6B);
  static const Color protein = Color(0xFFE4567A);
  static const Color info = Color(0xFF3B82C4);
  static const Color success = Color(0xFF1E9E6A);
  static const Color warning = Color(0xFFE8A13C);
  static const Color primary = Color(0xFF0E7C6B);
}


// ── Lightweight state wiring (no external dependencies) ────────────
// PulseScope exposes the app store via InheritedNotifier so that any
// screen reading `PulseStore.of(context)` rebuilds on notifyListeners().
class PulseScope extends InheritedNotifier<PulseStore> {
  const PulseScope({super.key, required PulseStore store, required super.child})
      : super(notifier: store);
}

extension PulseStoreWatch on BuildContext {
  /// Watch access — rebuilds dependents when the store notifies.
  PulseStore get pulseWatch => PulseStore.of(this);
}
