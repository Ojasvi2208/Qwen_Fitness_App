import 'package:flutter/material.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 07 — Food Diary (§26, §78 swipe actions, §79 calendar).
/// Nav/Bottom → Diary tab.
/// ═══════════════════════════════════════════════════════════════════

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  int _dayOffset = 0; // 0 = today (Sep 29); -1 = yesterday etc.
  final Set<String> _expanded = {MealType.breakfast.name, MealType.lunch.name};

  String get _dateLabel {
    if (_dayOffset == 0) return 'Tuesday, Sep 29';
    if (_dayOffset == -1) return 'Monday, Sep 28';
    if (_dayOffset == 1) return 'Wednesday, Sep 30';
    return 'Sep ${29 + _dayOffset}';
  }

  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    final isToday = _dayOffset == 0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: PulseSpacing.m,
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton3(icon: Icons.chevron_left_rounded,
              onTap: () => setState(() => _dayOffset--)),
          Column(children: [
            Text(_dateLabel, style: Theme.of(context).textTheme.titleLarge),
            Text(isToday ? 'Today' : _dayOffset < 0 ? '${-_dayOffset} day(s) ago' : 'Upcoming',
                style: Theme.of(context).textTheme.labelSmall),
          ]),
          IconButton3(icon: Icons.chevron_right_rounded,
              onTap: () => _dayOffset >= 0
                  ? pulseSnack(context, 'You can\'t log into the future yet — plan tomorrow\'s meals in Meal Plan instead.')
                  : setState(() => _dayOffset++)),
        ]),
        actions: [
          IconButton3(icon: Icons.calendar_month_rounded, tooltip: 'Calendar',
              onTap: () => pulseSheet(context, builder: (_) => const _HistoryCalendar())),
          IconButton3(icon: Icons.edit_note_rounded, tooltip: 'Add note',
              onTap: () => _addNote(context)),
        ],
      ),
      body: SafeArea(
        child: !isToday
            ? EmptyState(
                icon: Icons.history_rounded,
                title: 'No diary for $_dateLabel',
                body: 'Food logging started on Sep 1. Pick a logged date from the calendar to review it.',
                actionLabel: 'Open Calendar',
                onAction: () => pulseSheet(context, builder: (_) => const _HistoryCalendar()))
            : ListView(
                padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, 140),
                children: [
                  for (final meal in MealType.values) _mealSection(context, store, meal),
                  const SizedBox(height: PulseSpacing.s),
                  // Bottom summary bar — totals row
                  PulseCard(
                    child: Row(children: [
                      _sum(context, 'Calories', '${store.foodKcal.toStringAsFixed(0)}', PulseColors.accent),
                      _sum(context, 'Protein', '${store.protein.toStringAsFixed(0)} g', PulseColors.protein),
                      _sum(context, 'Carbs', '${store.carbs.toStringAsFixed(0)} g', PulseColors.carbs),
                      _sum(context, 'Fat', '${store.fat.toStringAsFixed(0)} g', PulseColors.fat),
                    ]),
                  ),
                  const SizedBox(height: PulseSpacing.m),
                  PrimaryButton(
                      label: 'Complete Diary',
                      icon: Icons.task_alt_rounded,
                      onTap: () {
                        store.track('diary_completed');
                        pulseSnack(context, 'Diary marked complete. Tomorrow is another opportunity to stay consistent.', icon: Icons.verified_rounded);
                      }),
                  const SizedBox(height: PulseSpacing.s),
                  const HealthDisclaimer(),
                ],
              ),
      ),
      floatingAction: FloatingActionButton(
        heroTag: 'diary-add',
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () {
          store.track('food_search_started');
          Navigator.of(context).pushNamed('/food-search');
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _sum(BuildContext c, String l, String v, Color col) => Expanded(
        child: Column(children: [
          Text(v, style: PulseTypography.metricSmall.copyWith(color: col)),
          Text(l, style: Theme.of(c).textTheme.labelSmall),
        ]),
      );

  Widget _mealSection(BuildContext context, PulseStore store, MealType meal) {
    final entries = store.diary.where((e) => e.meal == meal).toList();
    final open = _expanded.contains(meal.name);
    return Card(
      margin: const EdgeInsets.only(bottom: PulseSpacing.m),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(PulseRadius.l),
          onTap: () => setState(() => open ? _expanded.remove(meal.name) : _expanded.add(meal.name)),
          child: Padding(
            padding: const EdgeInsets.all(PulseSpacing.m),
            child: Row(children: [
              Icon(TodayIcons.iconFor(meal), size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: PulseSpacing.sm),
              Expanded(child: Text('${meal.label} · ${store.kcalFor(meal).toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.titleMedium)),
              IconButton3(icon: Icons.add_rounded, selected: true, size: 36,
                  onTap: () {
                    store.track('food_search_started');
                    Navigator.of(context).pushNamed('/food-search', arguments: meal);
                  }),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.s),
            child: Column(children: [
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PulseSpacing.s),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: PulseSpacing.s),
                    Text('+ Add Food', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 15)),
                  ]),
                ),
              for (final e in entries)
                // §78 Swipe actions: left→delete (with confirm), right→copy
                Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m),
                    decoration: BoxDecoration(color: PulseColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(PulseRadius.m)),
                    child: const Row(children: [Icon(Icons.content_copy_rounded, color: PulseColors.info, size: 20), SizedBox(width: 6), Text('Copy', style: TextStyle(color: PulseColors.info, fontWeight: FontWeight.w600))]),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m),
                    decoration: BoxDecoration(color: PulseColors.error.withOpacity(0.15), borderRadius: BorderRadius.circular(PulseRadius.m)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('Delete', style: TextStyle(color: PulseColors.error, fontWeight: FontWeight.w600)), SizedBox(width: 6), Icon(Icons.delete_outline_rounded, color: PulseColors.error, size: 20)]),
                  ),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.endToStart) {
                      final ok = await pulseConfirm(context,
                          title: 'Remove ${e.food.name}?',
                          body: 'This entry (${e.kcal.toStringAsFixed(0)} kcal) will be removed from ${meal.label}. You can undo right after.',
                          confirmLabel: 'Remove', destructive: true);
                      if (ok && context.mounted) {
                        store.removeEntry(e.id);
                        pulseSnack(context, 'Removed from ${meal.label}', undoLabel: 'Undo',
                            onUndo: () => store.addFood(e.food, e.servings, e.meal));
                      }
                      return false; // we manage removal ourselves so undo stays possible
                    } else {
                      store.addFood(e.food, e.servings, e.meal);
                      if (context.mounted) pulseSnack(context, 'Copied to ${meal.label}', icon: Icons.content_copy_rounded);
                      return false;
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.food.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15.5)),
                          Text('${e.servings.toStringAsFixed(e.servings % 1 == 0 ? 0 : 1)} × ${e.food.serving} · P ${e.protein.toStringAsFixed(0)} · C ${e.carbs.toStringAsFixed(0)} · F ${e.fat.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                        ]),
                      ),
                      Text('${e.kcal.toStringAsFixed(0)} kcal',
                          style: PulseTypography.metricSmall.copyWith(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                    ]),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }

  void _addNote(BuildContext context) {
    final c = TextEditingController();
    pulseSheet(context, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(PulseSpacing.l),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetHeader(title: 'Day note', subtitle: 'Context helps future-you understand patterns.'),
        TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. Late dinner at a family birthday')),
        const SizedBox(height: PulseSpacing.m),
        PrimaryButton(label: 'Save Note', onTap: () {
          Navigator.pop(ctx);
          if (c.text.trim().isNotEmpty) pulseSnack(context, 'Note saved for Tuesday, Sep 29', icon: Icons.sticky_note_2_rounded);
        }),
      ]),
    ));
  }
}

class TodayIcons {
  TodayIcons._();
  static IconData iconFor(MealType m) => switch (m) {
        MealType.breakfast => Icons.free_breakfast_rounded,
        MealType.lunch => Icons.local_dining_rounded,
        MealType.dinner => Icons.restaurant_rounded,
        MealType.snacks => Icons.cookie_rounded,
      };
}

// ── §79 History calendar with activity dots ────────────────────────
class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // levels: 0 none, .5 partial, 1 full logging days
    const levels = [1, 1, .5, 1, 1, 0, 1, 1, .5, 1, 1, 1, .5, 0, 1, 1, 1, .5, 1, 1, 0];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PulseSpacing.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHeader(title: 'Food history', subtitle: 'Dot intensity shows how completely each day was logged.'),
          Row(children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.labelMedium))),
          ]),
          const SizedBox(height: PulseSpacing.s),
          Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
            for (var i = 1; i <= 28; i++)
              Semantics(
                label: 'September $i${_level(levels[(i - 1) % levels.length])}',
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Builder(builder: (_) {
                    final lv = levels[(i - 1) % levels.length];
                    return Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: lv == 0 ? scheme.surfaceContainerHighest : scheme.primary.withOpacity(0.15 + lv * 0.75),
                          borderRadius: BorderRadius.circular(PulseRadius.s)),
                      child: Center(child: Text('$i', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: lv > 0.55 ? Colors.white : null))),
                    );
                  }),
                ),
              ),
          ]),
          const SizedBox(height: PulseSpacing.m),
          Row(children: [
            Text('Less', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 6),
            for (final o in [0.15, 0.45, 0.75, 1.0])
              Padding(padding: const EdgeInsets.only(right: 4),
                  child: Container(width: 14, height: 14, decoration: BoxDecoration(color: scheme.primary.withOpacity(o), borderRadius: BorderRadius.circular(3)))),
            const SizedBox(width: 6),
            Text('More', style: Theme.of(context).textTheme.labelSmall),
          ]),
        ]),
      ),
    );
  }
}

String _level(double l) => l == 1 ? ', fully logged' : l == 0 ? ', not logged' : ', partially logged';

// ── §28/§29 Recipes list, detail & creation ───────────────────────
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.pulse;
    return PulseScaffold(
      title: 'Recipes',
      subtitle: 'Cook once, log forever — nutrition is calculated per serving',
      body: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > PulseBreakpoints.medium ? 3 : 2,
        mainAxisSpacing: PulseSpacing.m,
        crossAxisSpacing: PulseSpacing.m,
        padding: const EdgeInsets.all(PulseSpacing.m),
        childAspectRatio: 0.78,
        children: [
          for (final r in PulseData.recipes)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(PulseRadius.l),
                onTap: () => Navigator.of(context).pushNamed('/recipe-detail', arguments: r.name),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(PulseRadius.l)),
                          gradient: LinearGradient(colors: [PulseColors.fiber.withOpacity(0.35), PulseColors.primary.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.no_meals_rounded, color: Colors.white54, size: 34)),
                        Padding(padding: const EdgeInsets.all(8), child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(PulseRadius.full)),
                            child: Text(r.tag, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)))),
                      ]),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(PulseSpacing.sm),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text('${r.kcalPerServing.toStringAsFixed(0)} kcal / serving', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text('${r.minutes} min · Serves ${r.servings}', style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(PulseRadius.l),
              onTap: () {
                store.track('recipe_create_started');
                Navigator.of(context).pushNamed('/create-recipe');
              },
              child: Column(children: [
                const Expanded(flex: 3, child: Center(child: Icon(Icons.add_rounded, size: 40))),
                const Expanded(flex: 2, child: Center(child: Text('Create Recipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipeName});
  final String recipeName;
  @override
  Widget build(BuildContext context) {
    final r = PulseData.recipes.firstWhere((x) => x.name == recipeName, orElse: () => PulseData.recipes[0]);
    final store = context.pulse;
    return PulseScaffold(
      title: 'Recipe',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        Text(r.name, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: PulseSpacing.s),
        Text('${r.minutes} min · Serves ${r.servings} · ${r.tag}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.l),
        PulseCard(
          child: Row(children: [
            _stat(context, 'Per serving', '${r.kcalPerServing.toStringAsFixed(0)} kcal'),
            _stat(context, 'Protein', '${(r.kcalPerServing * 0.08).toStringAsFixed(0)} g'),
            _stat(context, 'Carbs', '${(r.kcalPerServing * 0.11).toStringAsFixed(0)} g'),
            _stat(context, 'Fat', '${(r.kcalPerServing * 0.035).toStringAsFixed(0)} g'),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Ingredients', actionLabel: '+ Add', onAction: () {}),
        for (final ing in const ['Chicken breast 600 g', 'Chickpeas 1 can', 'Cherry tomatoes 250 g', 'Olive oil 2 tbsp', 'Feta cheese 100 g', 'Lemon 1'])
          ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
              leading: const Icon(Icons.check_rounded, size: 18, color: PulseColors.fiber), title: Text(ing)),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Instructions'),
        for (final (i, step) in const ['Season and sear chicken, 6 min per side.', 'Roast with chickpeas and tomatoes at 200°C for 20 min.', 'Finish with olive oil, feta and lemon.']
            .indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 13, backgroundColor: store.premium ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                  foregroundColor: Colors.white, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              const SizedBox(width: PulseSpacing.sm),
              Expanded(child: Text(step, style: Theme.of(context).textTheme.bodyMedium)),
            ]),
          ),
        const SizedBox(height: PulseSpacing.m),
        PrimaryButton(label: 'Log Serving to Dinner', icon: Icons.add_rounded, onTap: () {
          store.addFood(PulseData.foodById('f3'), 1.2, MealType.dinner);
          store.track('recipe_logged');
          Navigator.pop(context);
          pulseSnack(context, 'Added to Dinner', undoLabel: 'Undo', onUndo: () => store.removeEntry(store.diary.last.id));
        }),
        const SizedBox(height: PulseSpacing.s),
        SecondaryButton(label: 'Add to Meal Plan', icon: Icons.event_available_rounded,
            onTap: () => Navigator.of(context).pushNamed('/meal-plan')),
      ]),
    );
  }

  Widget _stat(BuildContext c, String l, String v) => Expanded(
      child: Column(children: [
        Text(v, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
        Text(l, style: Theme.of(c).textTheme.labelSmall),
      ]));
}

// ── §28 Create Recipe ──────────────────────────────────────────────
class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});
  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _name = TextEditingController(text: 'Weeknight Salmon Bowl');
  final _instructions = TextEditingController(text: 'Roast salmon 12 min at 200°C. Assemble over rice with broccoli and yogurt-lemon drizzle.');
  int _servings = 2;
  final List<String> _ingredients = ['Salmon fillet 280 g', 'Brown rice 2 cups cooked', 'Broccoli 2 cups', 'Greek yogurt 60 g', 'Lemon ½'];

  double get _estKcal => _ingredients.length * 148.0; // rough demo estimate
  double get _perServing => _estKcal / _servings;

  @override
  void dispose() { _name.dispose(); _instructions.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final nameError = _name.text.trim().isEmpty ? 'Give your recipe a name' : null;
    return PulseScaffold(
      title: 'Create Recipe',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: 'Recipe Name', errorText: nameError), onChanged: (_) => setState(() {})),
        const SizedBox(height: PulseSpacing.m),
        Row(children: [
          Expanded(child: Text('Servings', style: Theme.of(context).textTheme.titleMedium)),
          PulseStepper(value: _servings.toDouble(), min: 1, max: 24, unit: '', onChanged: (v) => setState(() => _servings = v.round())),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Ingredients', actionLabel: 'Import Recipe', onAction: () => pulseSnack(context, 'Paste a URL or import from a supported source.', icon: Icons.import_rounded)),
        for (final ing in _ingredients)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            leading: const Icon(Icons.remove_from_queue_rounded, size: 18),
            title: Text(ing),
            trailing: IconButton(tooltip: 'Remove ingredient', icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _ingredients.remove(ing))),
          ),
        OutlinedButton.icon(onPressed: () => setState(() => _ingredients.add('Side salad 1 bowl')),
            icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add Ingredient')),
        const SizedBox(height: PulseSpacing.l),
        // Auto-calculated estimated nutrition per serving
        PulseCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Estimated nutrition per serving', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: PulseSpacing.s),
            Text('${_perServing.toStringAsFixed(0)} kcal · ${( _perServing * 0.11).toStringAsFixed(0)} g protein',
                style: PulseTypography.metricSmall.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 2),
            Text('Approximate nutrition — refine by linking exact foods from search.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Instructions'),
        TextField(controller: _instructions, maxLines: 4, decoration: const InputDecoration(hintText: 'Write steps here…')),
        const SizedBox(height: PulseSpacing.xl),
        PrimaryButton(label: 'Save Recipe', icon: Icons.bookmark_add_rounded, onTap: nameError != null ? null : () {
          context.pulse.track('recipe_created');
          Navigator.pop(context);
          pulseSnack(context, 'Recipe saved — find it under Recipes any time.', icon: Icons.menu_book_rounded);
        }),
      ]),
    );
  }
}

// ── §29 Saved Meals ────────────────────────────────────────────────
class SavedMealsScreen extends StatelessWidget {
  const SavedMealsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    return PulseScaffold(
      title: 'My Meals',
      subtitle: 'Repeatable combos you log in one tap',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final m in PulseData.savedMeals)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PulseSpacing.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text('${m.kcal.toStringAsFixed(0)} kcal · ${m.protein.toStringAsFixed(0)} g protein',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: PulseSpacing.sm),
                Text(m.foodIds.map((id) => PulseData.foodById(id).name).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                const SizedBox(height: PulseSpacing.sm),
                Row(children: [
                  Expanded(child: FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                      onPressed: () {
                        for (final id in m.foodIds) {
                          store.addFood(PulseData.foodById(id), 1, MealType.lunch);
                        }
                        pulseSnack(context, '${m.name} added to Lunch', undoLabel: 'Undo', onUndo: () {});
                      },
                      child: const Text('Add to Diary'))),
                  const SizedBox(width: PulseSpacing.s),
                  IconButton3(icon: Icons.edit_outlined, onTap: () => pulseSnack(context, 'Editing opens the recipe builder.')),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: PulseSpacing.s),
        SecondaryButton(label: 'Create New Meal', icon: Icons.add_rounded,
            onTap: () => Navigator.of(context).pushNamed('/create-recipe')),
      ]),
    );
  }
}

// ── §30 Meal Planner + §31 Grocery List ────────────────────────────
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});
  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  static const _days = ['Mon 28', 'Tue 29', 'Wed 30', 'Thu 1', 'Fri 2', 'Sat 3', 'Sun 4'];
  late Map<String, Map<String, String>> plan = {
    for (final d in _days)
      d: {
        'Breakfast': PulseData.savedMeals[2].name,
        'Lunch': PulseData.savedMeals[1].name,
        'Dinner': d == 'Mon 28' ? 'Salmon & Sweet Potato' : 'Chicken Rice Bowl',
        'Snack': d == 'Wed 30' ? 'Almonds' : '',
      },
  };
  String? _dragging;

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Meal Plan',
      subtitle: 'Week of Sep 28',
      actions: [IconButton3(icon: Icons.auto_awesome_rounded, tooltip: 'Generate suggestions',
          onTap: () => pulseSnack(context, 'Suggestions use your goals, preferences and Frequent foods.', icon: Icons.auto_awesome_rounded))],
      body: DragTarget<String>(
        onAccept: (_) {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PulseSpacing.m),
          child: Column(children: [
            // horizontal week strip
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final d in _days)
                  Padding(
                    padding: const EdgeInsets.only(right: PulseSpacing.s),
                    child: ChoiceChip(label: Text(d), selected: d == 'Tue 29', onSelected: (_) {}),
                  ),
              ]),
            ),
            const SizedBox(height: PulseSpacing.m),
            for (final slot in const ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
              Draggable<String>(
                data: slot,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(PulseRadius.m),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width - 48,
                    padding: const EdgeInsets.all(PulseSpacing.m),
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(children: [
                      const Icon(Icons.drag_handle_rounded, size: 18),
                      const SizedBox(width: PulseSpacing.s),
                      Text(slot, style: Theme.of(context).textTheme.titleMedium),
                    ]),
                  ),
                ),
                onDragStarted: () => setState(() => _dragging = slot),
                onDragEnd: (_) => setState(() => _dragging = null),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(PulseSpacing.m),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.drag_handle_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                        const SizedBox(width: PulseSpacing.s),
                        Text(slot, style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        TextButton(onPressed: () => _replaceSlot(context, slot), child: const Text('Replace')),
                      ]),
                      for (final d in _days.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            SizedBox(width: 56, child: Text(d, style: Theme.of(context).textTheme.labelMedium)),
                            Expanded(
                              child: Text(plan[d]![slot]!.isEmpty ? '+ Add recipe' : plan[d]![slot]!,
                                  style: TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: plan[d]![slot]!.isEmpty ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface)),
                            ),
                          ]),
                        ),
                      if (_dragging == slot)
                        Padding(
                          padding: const EdgeInsets.only(top: PulseSpacing.xs),
                          child: Text('Drag onto another slot to reorder', style: Theme.of(context).textTheme.labelSmall),
                        ),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: PulseSpacing.m),
            PrimaryButton(label: 'Create Grocery List', icon: Icons.shopping_cart_checkout_rounded,
                onTap: () => Navigator.of(context).pushNamed('/grocery-list')),
          ]),
        ),
      ),
    );
  }

  void _replaceSlot(BuildContext context, String slot) {
    pulseSheet(context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: 'Choose for $slot'),
        for (final m in PulseData.savedMeals)
          ListTile(
            leading: const Icon(Icons.restaurant_rounded),
            title: Text(m.name),
            subtitle: Text('${m.kcal.toStringAsFixed(0)} kcal'),
            onTap: () {
              setState(() => plan['Tue 29']![slot] = m.name);
              Navigator.pop(ctx);
              pulseSnack(context, '$slot set to ${m.name}', icon: Icons.event_available_rounded);
            },
          ),
        const SizedBox(height: PulseSpacing.s),
      ]),
    ));
  }
}

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});
  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  late final Map<String, List<({String item, bool done})>> _list = {
    for (final e in PulseData.groceryCategories.entries) e.key: [...e.value],
  };

  @override
  Widget build(BuildContext context) {
    final total = _list.values.expand((v) => v).length;
    final done = _list.values.expand((v) => v).where((x) => x.done).length;
    return PulseScaffold(
      title: 'Grocery List',
      subtitle: '$done of $total items checked · from Week of Sep 28',
      actions: [
        IconButton3(icon: Icons.share_rounded, tooltip: 'Share', onTap: () => pulseSnack(context, 'Shared as a plain-text list — no account needed for your partner.', icon: Icons.share_rounded)),
        IconButton3(icon: Icons.ios_share_rounded, tooltip: 'Export', onTap: () => pulseSnack(context, 'Exported to Notes / email.', icon: Icons.download_rounded)),
      ],
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        PulseBar(value: total == 0 ? 0 : done / total, color: PulseColors.success, height: 8),
        const SizedBox(height: PulseSpacing.l),
        for (final cat in _list.keys) ...[
          SectionHeader(title: cat),
          for (var i = 0; i < _list[cat]!.length; i++)
            CheckboxListTile(
              value: _list[cat]![i].done,
              onChanged: (v) => setState(() => _list[cat]![i] = (item: _list[cat]![i].item, done: v ?? false)),
              title: Text(_list[cat]![i].item,
                  style: TextStyle(decoration: _list[cat]![i].done ? TextDecoration.lineThrough : null,
                      color: _list[cat]![i].done ? Theme.of(context).colorScheme.onSurface.withOpacity(0.45) : null, fontSize: 15.5)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
        const SizedBox(height: PulseSpacing.m),
        SecondaryButton(label: 'Clear Completed', icon: Icons.cleaning_services_rounded, onTap: () {
          setState(() {
            for (final cat in _list.keys) {
              _list[cat] = _list[cat]!.where((x) => !x.done).toList();
            }
          });
          pulseSnack(context, 'Completed items cleared.');
        }),
      ]),
    );
  }
}

// ── §28-bis Nutrition Details (§ screen 28 inventory) ──────────────
class NutritionDetailsScreen extends StatelessWidget {
  const NutritionDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = PulseStore.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Nutrition',
      subtitle: 'Tuesday, Sep 29 · ${s.foodKcal.toStringAsFixed(0)} kcal logged',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        // Macro donut with textual explanation (a11y: charts always labelled)
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Row(children: [
            PulseDonut(size: 120, stroke: 18, segments: [
              (value: s.protein * 4, color: PulseColors.protein),
              (value: s.carbs * 4, color: PulseColors.carbs),
              (value: s.fat * 9, color: PulseColors.fat),
            ], center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${s.foodKcal.toStringAsFixed(0)}', style: PulseTypography.metricMedium.copyWith(color: scheme.onSurface)),
              Text('kcal', style: Theme.of(context).textTheme.labelSmall),
            ])),
            const SizedBox(width: PulseSpacing.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _legend(context, 'Protein', PulseColors.protein, Icons.bolt_rounded, '${(s.protein * 4 / (s.foodKcal == 0 ? 1 : s.foodKcal) * 100).round()}% of calories'),
                _legend(context, 'Carbs', PulseColors.carbs, Icons.grain_rounded, '${(s.carbs * 4 / (s.foodKcal == 0 ? 1 : s.foodKcal) * 100).round()}% of calories'),
                _legend(context, 'Fat', PulseColors.fat, Icons.water_drop_rounded, '${(s.fat * 9 / (s.foodKcal == 0 ? 1 : s.foodKcal) * 100).round()}% of calories'),
                Text('Distribution of the ${s.foodKcal.toStringAsFixed(0)} calories you\'ve logged today.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Goals vs actual'),
        PulseCard(
          child: Column(children: [
            MacroRow(label: 'Protein', current: s.protein, goal: s.goals.proteinGoal, color: PulseColors.protein, iconData: Icons.bolt_rounded),
            MacroRow(label: 'Carbohydrates', current: s.carbs, goal: s.goals.carbGoal, color: PulseColors.carbs, iconData: Icons.grain_rounded),
            MacroRow(label: 'Fat', current: s.fat, goal: s.goals.fatGoal, color: PulseColors.fat, iconData: Icons.water_drop_rounded),
            MacroRow(label: 'Fiber', current: 21, goal: 30, color: PulseColors.fiber, iconData: Icons.eco_rounded),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Micronutrients', actionLabel: 'Pro', onAction: () => ensurePremium(context, 'Micronutrient breakdown')),
        PulseCard(
          child: Column(children: [
            for (final m in const [('Sodium', '1,840 / 2,300 mg'), ('Potassium', '2,610 / 3,400 mg'), ('Calcium', '780 / 1,000 mg'), ('Iron', '11 / 18 mg')])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(m.$1, style: Theme.of(context).textTheme.bodyLarge)),
                  Text(m.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        const HealthDisclaimer(),
      ]),
    );
  }

  Widget _legend(BuildContext c, String label, Color col, IconData icon, String pct) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 15, color: col),
          const SizedBox(width: 6),
          Text('$label · $pct', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Theme.of(c).colorScheme.onSurface)),
        ]),
      );
}
