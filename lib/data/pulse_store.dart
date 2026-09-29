import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PULSE APP STATE — lightweight InheritedNotifier store (no external
/// deps, implementable in React Native too). Sample user: Alex Morgan.
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
  /// Watch access used across screens: PulseStore.of(context).
  static PulseStore of(BuildContext context) => PulseStoreAccess.of(context);

  // ── Sample user (§84): consistent across every screen ────────────
  final String userName = 'Alex Morgan';
  final String userFirstName = 'Alex';
  final int age = 32;
  final double heightCm = 178;
  final double startWeight = 84.5;
  final double currentWeight = 79.8;
  final String memberSince = 'March 2026';

  final Goals goals = Goals(
    calorieGoal: 2050, proteinGoal: 135, carbGoal: 220, fatGoal: 70,
    waterGoalLiters: 2.6, stepGoal: 8000, targetWeightKg: 75, workoutsPerWeek: 4,
  );

  // ── Today's logged state (matches brief numbers) ─────────────────
  final List<DiaryEntry> diary = [
    DiaryEntry(id: 'e1', food: PulseData.foods[0], servings: 1, meal: MealType.breakfast),
    DiaryEntry(id: 'e2', food: PulseData.foods[2], servings: 1.2, meal: MealType.lunch),
    DiaryEntry(id: 'e3', food: PulseData.foods[3], servings: 1, meal: MealType.lunch),
    DiaryEntry(id: 'e4', food: PulseData.foods[5], servings: 1, meal: MealType.dinner),
  ];

  double activityCaloriesBurned = 310; // from exercise today
  double stepsToday = 6842;
  double waterLogged = 1.7; // liters
  int workoutsCompletedToday = 1;

  /// Weigh-in history (local-first). Seeded with the sample trend so
  /// charts have data on first launch; new entries are appended live.
  final List<WeightRecord> weights = [
    WeightRecord(DateTime(2026, 6, 1), 84.5),
    WeightRecord(DateTime(2026, 6, 15), 83.6),
    WeightRecord(DateTime(2026, 7, 1), 83.1),
    WeightRecord(DateTime(2026, 7, 15), 82.4),
    WeightRecord(DateTime(2026, 8, 1), 81.9),
    WeightRecord(DateTime(2026, 8, 15), 81.0),
    WeightRecord(DateTime(2026, 9, 1), 80.6),
    WeightRecord(DateTime(2026, 9, 15), 80.1),
    WeightRecord(DateTime(2026, 9, 29), 79.8),
  ];
  bool premium = false;
  bool offlineMode = false;
  String unitsMass = 'kg'; // kg | lb
  String unitsLength = 'cm'; // cm | ft+in
  String unitsVolume = 'ml'; // ml | oz
  String unitsDistance = 'km'; // km | mi

  static const weightHistory = <(String, double)>[
    ('Jun 1', 84.5), ('Jun 15', 83.6), ('Jul 1', 83.1), ('Jul 15', 82.4),
    ('Aug 1', 81.9), ('Aug 15', 81.0), ('Sep 1', 80.6), ('Sep 15', 80.1),
    ('Sep 29', 79.8),
  ];
  static const weeklyCalories = <int>[2120, 1980, 2065, 2210, 2040, 1995, 2145];

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
    notifyListeners();
  }

  void removeEntry(String id) {
    diary.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addWater(double liters) {
    waterLogged = (waterLogged + liters).clamp(0.0, 10.0);
    track('water_logged');
    notifyListeners();
  }

  void logWeight(double kg, {DateTime? date}) {
    final now = date ?? DateTime.now();
    weights.removeWhere((w) =>
        w.date.year == now.year && w.date.month == now.month && w.date.day == now.day);
    weights.add(WeightRecord(now, kg));
    weights.sort((a, b) => a.date.compareTo(b.date));
    currentWeightLive = kg;
    track('weight_logged');
    notifyListeners();
  }

  void deleteWeight(DateTime date) {
    weights.removeWhere((w) =>
        w.date.year == date.year && w.date.month == date.month && w.date.day == date.day);
    if (weights.isNotEmpty) currentWeightLive = weights.last.kg;
    track('weight_deleted');
    notifyListeners();
  }

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

  void setHighContrast(bool v) { highContrast = v; track('accessibility_changed'); notifyListeners(); }
  void setLargeText(bool v) { largeText = v; notifyListeners(); }
  void setReduceMotion(bool v) { reduceMotion = v; notifyListeners(); }
  void setThemeMode(ThemeMode m) { themeMode = m; notifyListeners(); }
  void setAnalytics(bool v) { analyticsEnabled = v; notifyListeners(); }

  // ── Units (§59) ──────────────────────────────────────────────────
  void setUnitsWeight(String u) { unitsMass = u; notifyListeners(); }
  void setUnitsHeight(String u) { unitsLength = u; notifyListeners(); }
  void setUnitsVolume(String u) { unitsVolume = u; notifyListeners(); }
  void setUnitsDistance(String u) { unitsDistance = u; notifyListeners(); }
  String get unitsWeight => unitsMass;
  String get unitsHeight => unitsLength;

  /// Smart goal review seam (§51): updates multiple targets atomically and
  /// never silently alters calorie targets without an explicit call here.
  void setTargets({double? targetWeightKg, double? calorieGoal, double? proteinGoal}) {
    if (targetWeightKg != null) goals.targetWeightKg = targetWeightKg;
    if (calorieGoal != null) goals.calorieGoal = calorieGoal;
    if (proteinGoal != null) goals.proteinGoal = proteinGoal;
    track('goal_updated');
    notifyListeners();
  }

  void updateGoals(void Function(Goals g) edit) {
    edit(goals);
    track('goal_updated');
    notifyListeners();
  }

  void togglePremium() {
    premium = !premium;
    if (premium) track('trial_started');
    notifyListeners();
  }

  void setOffline(bool v) {
    offlineMode = v;
    notifyListeners();
  }

  /// Analytics seam — behavior events only, never raw health values.
  void track(String event, [Map<String, String>? props]) {
    debugPrint('📊 pulse_analytics → $event ${props ?? ''}');
  }
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

  static const insights = <({String title, String body, IconData icon, Color color})>[
    (title: 'Protein', body: 'You reached at least 90% of your protein goal on 5 of the last 7 days.', icon: Icons.bolt_rounded, color: PulsePalette.protein),
    (title: 'Activity', body: 'Your average daily steps increased 12% this month.', icon: Icons.trending_up_rounded, color: PulsePalette.steps),
    (title: 'Consistency', body: 'You\'ve logged meals on 18 of the last 21 days.', icon: Icons.check_circle_rounded, color: PulsePalette.success),
    (title: 'Hydration', body: 'You hit your water goal 6 days this week — one short of your best week yet.', icon: Icons.water_drop_rounded, color: PulsePalette.water),
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

extension PulseStoreAccess on BuildContext {
  /// Watch access — rebuilds dependents when the store notifies.
  static PulseStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PulseScope>();
    assert(scope != null, 'PulseScope missing — wrap MyApp in PulseScope.');
    return scope!.notifier!;
  }
}
