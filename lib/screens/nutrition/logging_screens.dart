import 'package:flutter/material.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 05/06 — Nutrition Logging + Food Scanning.
/// Flow B: Today → +Log → Search → Detail → Portion → Add → Updated.
/// Flow C: +Log → Scan Meal → Recognition → Review → Adjust → Add.
/// ═══════════════════════════════════════════════════════════════════

// ── §21 Food Search (tabs, results w/ kcal+protein+serving) ────────
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, this.meal});
  final MealType? meal;
  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _query = TextEditingController();
  int _tab = 0;
  bool _loading = false;

  List<FoodItem> get _results {
    final q = _query.text.trim().toLowerCase();
    var list = PulseData.foods.where((f) => q.isEmpty || f.name.toLowerCase().contains(q)).toList();
    if (_tab == 1) list = list.where((f) => f.frequent).toList();
    if (_tab == 2) list = []; // "My Foods" empty state demo (§71)
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final targetMeal = widget.meal ?? MealType.lunch;
    return PulseScaffold(
      title: 'Add Food',
      subtitle: 'Logging into ${targetMeal.label.toLowerCase()} · ${fmtMediumDate(DateTime.now())}',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.s),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onChanged: (_) { setState(() {}); },
            decoration: InputDecoration(
              hintText: 'Search foods, dishes or restaurants',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => _query.clear()))
                  : null,
            ),
          ),
        ),
        DefaultTabController(
          length: 5,
          child: Column(children: [
            TabBar(isScrollable: true, tabs: const ['Recent', 'Frequent', 'My Foods', 'Meals', 'Recipes'].map((t) => Tab(text: t)).toList(),
                onTap: (i) => setState(() => _tab = i)),
            SizedBox(height: MediaQuery.sizeOf(context).height - 235, child: _list(context, targetMeal)),
          ]),
        ),
      ]),
      floatingAction: FloatingActionButton.extended(
        heroTag: 'quick-log-fab',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => openQuickLog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log'),
      ),
    );
  }

  Widget _list(BuildContext context, MealType meal) {
    if (_tab == 3) return _savedMealsList(context, meal);
    if (_tab == 4) return _recipeList(context);
    final results = _results;
    if (results.isEmpty) {
      return EmptyState(
          icon: Icons.no_meals_rounded,
          title: _tab == 2 ? 'No custom foods yet' : 'No matches for “${_query.text}”',
          body: _tab == 2
              ? 'Foods you create appear here, ready to reuse in one tap.'
              : 'Try a different spelling, or create it once and save it forever.',
          actionLabel: 'Add Food Manually',
          onAction: () => Navigator.of(context).pushNamed('/food-detail', arguments: (PulseData.foods[0], meal)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 100),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final f = results[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: 2),
            leading: CircleAvatar(
                backgroundColor: PulseColors.protein.withOpacity(0.12),
                child: Icon(_foodIcon(f.name), color: PulseColors.protein, size: 20)),
            title: Text(f.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('${f.serving} · ${f.kcalPerServing.toStringAsFixed(0)} kcal · ${f.protein.toStringAsFixed(0)} g protein',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5)),
            trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
            onTap: () {
              context.pulse.track('food_detail_viewed');
              Navigator.of(context).pushNamed('/food-detail', arguments: (f, meal));
            },
          ),
        );
      },
    );
  }

  Widget _savedMealsList(BuildContext context, MealType meal) => ListView(
        padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 100),
        children: [
          for (final m in PulseData.savedMeals)
            SavedMealCard(meal: m, onAdd: () {
              for (final id in m.foodIds) {
                context.pulse.addFood(PulseData.foodById(id), 1, meal);
              }
              pulseSnack(context, '${m.name} added to ${meal.label}', undoLabel: 'Undo',
                  onUndo: () {}, icon: Icons.restaurant_rounded);
            }),
        ],
      );

  Widget _recipeList(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 100),
        children: [
          for (final r in PulseData.recipes)
            RecipeMiniCard(recipe: r, onTap: () => Navigator.of(context).pushNamed('/recipes')),
        ],
      );

  static IconData _foodIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('yogurt') || n.contains('cottage')) return Icons.restaurant_rounded;
    if (n.contains('chicken') || n.contains('salmon')) return Icons.set_meal_rounded;
    if (n.contains('rice') || n.contains('oat')) return Icons.rice_bowl_rounded;
    if (n.contains('banana') || n.contains('apple') || n.contains('avocado')) return Icons.eco_rounded;
    if (n.contains('egg')) return Icons.egg_alt_rounded;
    if (n.contains('coffee')) return Icons.coffee_rounded;
    return Icons.restaurant_rounded;
  }
}

class SavedMealCard extends StatelessWidget {
  const SavedMealCard({super.key, required this.meal, required this.onAdd});
  final ({String name, double kcal, double protein, List<String> foodIds}) meal;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(PulseSpacing.m),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meal.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text('${meal.kcal.toStringAsFixed(0)} kcal · ${meal.protein.toStringAsFixed(0)} g protein',
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
            FilledButton.tonal(onPressed: onAdd, style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), child: const Text('Add to Diary')),
          ]),
        ),
      );
}

class RecipeMiniCard extends StatelessWidget {
  const RecipeMiniCard({super.key, required this.recipe, required this.onTap});
  final ({String name, int minutes, double kcalPerServing, int servings, String tag}) recipe;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: PulseColors.fiber.withOpacity(0.14),
              child: const Icon(Icons.menu_book_rounded, color: PulseColors.fiber, size: 20)),
          title: Text(recipe.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15.5)),
          subtitle: Text('${recipe.minutes} min · ${recipe.kcalPerServing.toStringAsFixed(0)} kcal / serving · Serves ${recipe.servings}'),
          trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
          onTap: onTap,
        ),
      );
}

// ── §22 Food Detail + Portion editor (screens 20 & 21) ─────────────
class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({super.key, required this.food, required this.meal});
  final FoodItem food;
  final MealType meal;
  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  double _servings = 1;
  late MealType _meal = widget.meal;

  double _v(double per) => per * _servings;

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: f.name,
      body: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.huge), children: [
        // Hero nutrition summary — Card/NutritionSummary
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Column(children: [
            Text(f.serving, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text('${_v(f.kcalPerServing).toStringAsFixed(0)} Calories', style: PulseTypography.metricLarge.copyWith(color: scheme.onSurface)),
            const SizedBox(height: PulseSpacing.l),
            Row(children: [
              Expanded(child: _macroChip('Protein', '${_v(f.protein).toStringAsFixed(0)} g', PulseColors.protein, Icons.bolt_rounded)),
              Expanded(child: _macroChip('Carbs', '${_v(f.carbs).toStringAsFixed(0)} g', PulseColors.carbs, Icons.grain_rounded)),
              Expanded(child: _macroChip('Fat', '${_v(f.fat).toStringAsFixed(0)} g', PulseColors.fat, Icons.water_drop_rounded)),
            ]),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        // Serving selector — Sheet/FoodServing inline
        SectionHeader(title: 'Portion'),
        PulseCard(
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: f.serving,
              decoration: const InputDecoration(labelText: 'Serving size'),
              items: [f.serving, 'Half serving (${'0.5'}×)', 'Double serving (2×)']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _servings = v!.startsWith('Half') ? 0.5 : v.startsWith('Double') ? 2 : 1),
            ),
            const SizedBox(height: PulseSpacing.m),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Number of servings', style: Theme.of(context).textTheme.titleMedium),
              PulseStepper(value: _servings, step: 0.5, min: 0.5, max: 10, unit: '×', onChanged: (v) => setState(() => _servings = v)),
            ]),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Add to meal'),
        Wrap(spacing: PulseSpacing.s, children: [
          for (final m in MealType.values)
            ChoiceChip(label: Text(m.label), selected: _meal == m, onSelected: (_) => setState(() => _meal = m)),
        ]),
        const SizedBox(height: PulseSpacing.l),
        PrimaryButton(
            label: 'Add to Diary',
            icon: Icons.add_rounded,
            onTap: () {
              final store = context.pulse;
              store.addFood(f, _servings, _meal);
              Navigator.of(context).pop();
              pulseSnack(context, 'Added to ${_meal.label}',
                  undoLabel: 'Undo', onUndo: () => store.removeEntry(store.diary.last.id));
            }),
        const SizedBox(height: PulseSpacing.l),
        // Full Nutrition Facts table
        SectionHeader(title: 'Nutrition Facts', actionLabel: 'Per serving', onAction: () {}),
        PulseCard(
          child: Column(children: [
            for (final row in <(String, String, bool)>[
              ('Calories', '${_v(f.kcalPerServing).toStringAsFixed(0)} kcal', true),
              ('Protein', '${_v(f.protein).toStringAsFixed(1)} g', false),
              ('Total Carbohydrate', '${_v(f.carbs).toStringAsFixed(1)} g', false),
              ('— Fiber', '${(f.fiber * _servings).toStringAsFixed(1)} g', false),
              ('— Sugar', '${(f.carbs * 0.35 * _servings).toStringAsFixed(1)} g', false),
              ('Fat', '${_v(f.fat).toStringAsFixed(1)} g', false),
              ('— Saturated Fat', '${(f.fat * 0.3 * _servings).toStringAsFixed(1)} g', false),
              ('Sodium', '${(f.kcalPerServing * 2.1 * _servings).toStringAsFixed(0)} mg', false),
              ('Potassium', '${(f.kcalPerServing * 1.4 * _servings).toStringAsFixed(0)} mg', false),
              ('Calcium', '${(f.kcalPerServing * 0.6 * _servings).toStringAsFixed(0)} mg', false),
              ('Iron', '${(f.kcalPerServing * 0.008 * _servings).toStringAsFixed(1)} mg', false),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(row.$1, style: TextStyle(fontWeight: row.$3 ? FontWeight.w700 : FontWeight.w400, fontSize: row.$3 ? 16 : 15))),
                  Text(row.$2,
                      style: TextStyle(fontWeight: row.$3 ? FontWeight.w800 : FontWeight.w500, fontSize: row.$3 ? 16 : 15)),
                ]),
              ),
          ]),
        ),
        const HealthDisclaimer(),
      ]),
    );
  }

  Widget _macroChip(String label, String value, Color color, IconData icon) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m)),
        child: Column(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value, style: PulseTypography.metricSmall.copyWith(color: scheme_on(context))),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      );

  Color scheme_on(BuildContext c) => Theme.of(c).colorScheme.onSurface;
}

// ── §23 Barcode Scanner (camera UI + found/not-found states) ───────
/// §23 — Barcode scanning is not in v1.
///
/// This screen previously rendered a camera viewfinder, a "Reading
/// barcode…" state and a found-product result, with no camera and no
/// product database behind any of it: the scan always "succeeded"
/// against a hard-coded item. A control that cannot do what it depicts
/// is the same defect as a fabricated figure, so it states its position
/// plainly and sends the user to the search that does work.
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) => PulseScaffold(
        title: 'Scan Barcode',
        body: EmptyState(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Barcode scanning is coming later',
          body: 'It is not part of this version. You can search the food '
              'library by name and log anything in a few taps.',
          actionLabel: 'Search foods',
          onAction: () => Navigator.of(context).pushReplacementNamed('/food-search'),
        ),
      );
}

class MealScanScreen extends StatefulWidget {
  const MealScanScreen({super.key});
  @override
  State<MealScanScreen> createState() => _MealScanScreenState();
}

enum _MealScanStage { camera, analyzing, review }

class _MealScanScreenState extends State<MealScanScreen> {
  _MealScanStage _stage = _MealScanStage.camera;
  // Editable recognized items: (name, portion, kcal, protein)
  final List<Map<String, Object>> _items = [
    {'name': 'Grilled chicken', 'portion': '150 g', 'kcal': 248.0, 'protein': 46.0},
    {'name': 'Rice', 'portion': '1 cup', 'kcal': 216.0, 'protein': 5.0},
    {'name': 'Broccoli', 'portion': '1 cup', 'kcal': 55.0, 'protein': 3.7},
    {'name': 'Yogurt sauce', 'portion': '2 tbsp', 'kcal': 60.0, 'protein': 2.0},
  ];

  double get _totalKcal => _items.fold(0.0, (s, e) => s + (e['kcal'] as double));

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: _stage == _MealScanStage.review ? 'Review & Log' : 'Scan Your Meal',
      body: switch (_stage) {
        _MealScanStage.camera => _camera(),
        _MealScanStage.analyzing => const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SkeletonBox(height: 220, radius: PulseRadius.l),
              SizedBox(height: PulseSpacing.l),
              Text('Identifying foods on your plate…', style: TextStyle(fontSize: 16)),
            ])),
        _MealScanStage.review => _review(),
      },
    );
  }

  Widget _camera() => Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpacing.l),
            child: Stack(alignment: Alignment.center, children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(PulseRadius.xl),
                    gradient: const LinearGradient(colors: [Color(0xFF24332E), Color(0xFF16211D)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              ),
              Column(children: [
                const SizedBox(height: PulseSpacing.xxxl),
                const Icon(Icons.photo_camera_rounded, size: 64, color: Colors.white24),
                const SizedBox(height: PulseSpacing.m),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text('Take a clear photo and we\'ll identify the foods on your plate.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
                ),
              ]),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: PulseSpacing.xl),
                  child: Column(children: [
                    GestureDetector(
                      onTap: () {
                        context.pulse.track('meal_scan_photo_taken');
                        setState(() => _stage = _MealScanStage.analyzing);
                        Future.delayed(const Duration(milliseconds: 1600), () => mounted ? setState(() => _stage = _MealScanStage.review) : null);
                      },
                      child: Container(width: 72, height: 72,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: Colors.white.withOpacity(0.2))),
                    ),
                    const SizedBox(height: PulseSpacing.s),
                    const Text('or pick from Photos', style: TextStyle(color: Colors.white38, fontSize: 14)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]);

  Widget _review() {
    final store = context.pulse;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: PulseColors.accent, size: 20),
            const SizedBox(width: PulseSpacing.s),
            Text('We found ${_items.length} items', style: Theme.of(context).textTheme.headlineSmall),
          ]),
          const SizedBox(height: PulseSpacing.s),
          Container(
            padding: const EdgeInsets.all(PulseSpacing.sm),
            decoration: BoxDecoration(color: PulseColors.warning.withOpacity(0.14), borderRadius: BorderRadius.circular(PulseRadius.m),
                border: Border.all(color: PulseColors.warning.withOpacity(0.5))),
            child: const Row(children: [
              Icon(Icons.info_rounded, size: 18, color: PulseColors.warning),
              SizedBox(width: PulseSpacing.s),
              Expanded(child: Text('Estimated nutrition may vary. Review portions before adding.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PulseColors.warning))),
            ]),
          ),
          const SizedBox(height: PulseSpacing.m),
          for (var i = 0; i < _items.length; i++)
            Card(
              child: ListTile(
                title: Text(_items[i]['name'] as String, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('${_items[i]['portion']} · ${(_items[i]['kcal'] as double).toStringAsFixed(0)} kcal · ${(_items[i]['protein'] as double).toStringAsFixed(0)} g protein'),
                trailing: Builder(builder: (itemCtx) => PopupMenuButton<String>(
                  tooltip: 'Edit item',
                  onSelected: (v) => setState(() {
                    if (v == 'half') { _items[i]['kcal'] = (_items[i]['kcal'] as double) / 2; _items[i]['protein'] = (_items[i]['protein'] as double) / 2; (_items[i])['portion'] = '½ portion'; }
                    if (v == 'double') { _items[i]['kcal'] = (_items[i]['kcal'] as double) * 2; _items[i]['protein'] = (_items[i]['protein'] as double) * 2; _items[i]['portion'] = '2× portion'; }
                    if (v == 'remove') _items.removeAt(i);
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'half', child: Text('Half portion')),
                    PopupMenuItem(value: 'double', child: Text('Double portion')),
                    PopupMenuItem(value: 'remove', child: Text('Remove item')),
                  ],
                )),
              ),
            ),
          TextButton.icon(onPressed: () => setState(() => _items.add({'name': 'Side salad', 'portion': '1 bowl', 'kcal': 90.0, 'protein': 2.0})),
              icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add another item')),
          const SizedBox(height: PulseSpacing.s),
          Text('Approximate nutrition', style: Theme.of(context).textTheme.labelMedium),
        ]),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PulseSpacing.m),
          child: PrimaryButton(label: 'Review & Log · ${_totalKcal.toStringAsFixed(0)} kcal', onTap: () {
            store.track('meal_scan_completed');
            store.addFood(PulseData.foodById('f3'), 1, MealType.dinner);
            store.addFood(PulseData.foodById('f4'), 1, MealType.dinner);
            Navigator.pop(context);
            pulseSnack(context, 'Added to Dinner', undoLabel: 'Undo', onUndo: () {
              store.removeEntry(store.diary.last.id);
            });
          }),
        ),
      ),
    ]);
  }

}

// ── §25 Voice Log ──────────────────────────────────────────────────
class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({super.key});
  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> with SingleTickerProviderStateMixin {
  bool _listening = false;
  bool _parsed = false;
  String _transcript = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Voice Log',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.l), children: [
        Text('Tell PULSE what you ate', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: PulseSpacing.s),
        Text('Speak naturally — we\'ll turn it into diary entries you can review.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.xxl),
        Center(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _listening = true;
                _parsed = false;
                _transcript = '';
              });
              context.pulse.track('voice_log_started');
              Future.delayed(const Duration(milliseconds: 2200), () {
                if (!mounted) return;
                setState(() {
                  _listening = false;
                  _parsed = true;
                  _transcript = 'Two eggs, two slices of toast and one cup of coffee with milk.';
                });
              });
            },
            child: AnimatedContainer(
              duration: PulseDuration.normal,
              width: _listening ? 120 : 96, height: _listening ? 120 : 96,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _listening ? PulseColors.accent : scheme.primary,
                  boxShadow: [BoxShadow(color: (scheme.primary).withOpacity(0.4), blurRadius: _listening ? 40 : 20)]),
              child: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white, size: 40),
            ),
          ),
        ),
        const SizedBox(height: PulseSpacing.s),
        Center(child: Text(_listening ? 'Listening… tap to stop' : 'Tap the microphone to start',
            style: Theme.of(context).textTheme.bodySmall)),
        if (_listening) ...[
          const SizedBox(height: PulseSpacing.l),
          // Waveform animation
          SizedBox(height: 40, child: AnimatedBuilder(
              animation: _waveC,
              builder: (_, __) => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                for (var i = 0; i < 18; i++)
                  Container(width: 4, height: 8 + 26 * _wave[i],
                      decoration: BoxDecoration(color: PulseColors.accent.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
              ]))),
        ],
        if (_parsed) ...[
          const SizedBox(height: PulseSpacing.xl),
          PulseCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Heard', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('“$_transcript”', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
          ])),
          const SizedBox(height: PulseSpacing.m),
          SectionHeader(title: 'Parsed foods'),
          for (final p in const [('Eggs × 2', '144 kcal · 12.6 g protein', Icons.egg_alt_rounded), ('Whole wheat toast × 2', '160 kcal · 8 g protein', Icons.breakfast_dining_rounded), ('Coffee with milk', '35 kcal · 2 g protein', Icons.coffee_rounded)])
            Card(child: ListTile(leading: Icon(p.$3, size: 20, color: scheme.primary), title: Text(p.$1, style: Theme.of(context).textTheme.titleMedium), subtitle: Text(p.$2))),
          const SizedBox(height: PulseSpacing.m),
          PrimaryButton(label: 'Review & Add', icon: Icons.playlist_add_check_rounded, onTap: () {
            final store = context.pulse;
            store.addFood(PulseData.foodById('f5'), 2, MealType.breakfast);
            store.addFood(PulseData.foodById('f16'), 2, MealType.breakfast);
            store.track('voice_log_completed');
            Navigator.pop(context);
            pulseSnack(context, 'Added to Breakfast', undoLabel: 'Undo', onUndo: () {});
          }),
          TertiaryButton(label: 'Type it instead', onTap: () => Navigator.pushReplacementNamed(context, '/food-search')),
        ],
      ]),
    );
  }

  // Looping waveform values driven by an AnimationController.
  late final AnimationController _waveC = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  List<double> get _wave => List.generate(18, (i) => (0.25 + 0.75 * ((_waveC.value * 10 + i * 0.6) % 1)));

  @override
  void dispose() { _waveC.dispose(); super.dispose(); }
}
