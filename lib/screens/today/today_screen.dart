import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../data/monetization.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 04 — Today / Home Dashboard (§16–§20, §27, §39, §40, §80).
/// Purpose: instant understanding of calories/macros + fastest logging.
/// Modules are reorderable via "Customize Today" (§80).
/// ═══════════════════════════════════════════════════════════════════

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _loading = true; // demonstrates skeleton state on first build (§72)
  late List<String> modules = ['score', 'calories', 'macros', 'meals', 'water', 'steps', 'habits', 'insights'];

  @override
  void initState() {
    super.initState();
    // Inherited widgets are not reachable from initState, so the view event
    // waits for the first frame rather than throwing on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pulse.track('today_viewed');
    });
    Future.delayed(const Duration(milliseconds: 900), () => mounted ? setState(() => _loading = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    if (_loading) return const SafeArea(child: DashboardSkeleton());
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          // v1: there is no health integration, so a refresh re-reads what
          // is already on this device. It must not claim a sync that no
          // code performs (§3 honesty rule).
          await Future.delayed(const Duration(milliseconds: 300));
          store.rolloverIfNeeded();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, 120),
          children: [
            _greeting(context, store),
            if (store.offlineMode) OfflineBanner(onRetry: () => store.setOffline(false)),
            const TrialStatusBanner(),
            for (final m in modules) ..._module(context, store, m),
            const AdBanner(slot: AdSlot.homeFooter), // free tier only (§61)
            const HealthDisclaimer(),
          ],
        ),
      ),
    );
  }

  /// C1: the greeting read 'Good morning' and 'Tuesday, September 29' whatever
  /// the actual day or hour was. Both now come from the clock.
  Widget _greeting(BuildContext context, PulseStore store) {
    final now = DateTime.now();
    return Padding(
        padding: const EdgeInsets.fromLTRB(PulseSpacing.xs, PulseSpacing.s, 0, PulseSpacing.l),
        child: Row(children: [
          PulseAvatar(radius: 22, initials: pulseInitials(store.userName)),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmtGreeting(now)}, ${store.userFirstName}', style: Theme.of(context).textTheme.headlineMedium),
              Text(fmtLongDate(now), style: const TextStyle(fontSize: 14)),
            ]),
          ),
          IconButton3(icon: Icons.notifications_none_rounded, selected: false,
              onTap: () => Navigator.of(context).pushNamed('/notifications')),
          IconButton3(icon: Icons.search_rounded, onTap: () => Navigator.of(context).pushNamed('/search')),
        ]),
      );
  }

  List<Widget> _module(BuildContext context, PulseStore s, String id) => switch (id) {
        'score' => [_scoreCard(context, s)],
        'calories' => [_calorieCard(context, s)],
        'macros' => [_macroCard(context, s)],
        'meals' => [_mealsCard(context, s)],
        'water' => [_waterCard(context, s)],
        'steps' => [_stepsCard(context, s)],
        'habits' => [_habitsCard(context, s)],
        'insights' => [_insightStrip(context, s)],
        _ => const [],
      };

  // ── §16 Daily Score — day-progress, explicitly not a medical score
  Widget _scoreCard(BuildContext context, PulseStore s) {
    final scheme = Theme.of(context).colorScheme;
    final score = s.dailyScore;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.m),
      child: PulseCard(
        padding: const EdgeInsets.all(PulseSpacing.l),
        onTap: () => Navigator.of(context).pushNamed('/progress'),
        child: Row(children: [
          PulseRing(value: score / 100, color: scheme.primary, size: 72, stroke: 9,
              child: Text('${score.toStringAsFixed(0)}%', style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface))),
          const SizedBox(width: PulseSpacing.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today\'s Progress', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(score >= 70 ? 'You\'re building a strong day.' : 'Small consistent steps move the needle.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('A simple snapshot of your logging habits — not a medical health score.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5)),
            ]),
          ),
          IconButton3(icon: Icons.drag_handle_rounded, onTap: () => _customize(context, s)),
        ]),
      ),
    );
  }

  // ── §17 Calorie summary — visual equation Goal − Food + Activity
  Widget _calorieCard(BuildContext context, PulseStore s) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.m),
      child: Semantics(
        label: 'Calories: goal ${s.goals.calorieGoal.round()}, food ${s.foodKcal.round()} eaten, activity ${s.activityCaloriesBurned.round()} burned, ${s.remainingKcal.round()} remaining',
        child: PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          onTap: () => Navigator.of(context).pushNamed('/nutrition-details'),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Calories', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(s.remainingKcal.toStringAsFixed(0),
                      style: PulseTypography.metricLarge.copyWith(color: scheme.primary)),
                  Text('kcal remaining', style: Theme.of(context).textTheme.labelMedium),
                ]),
              ),
              PulseRing(
                  value: s.foodKcal / s.goals.calorieGoal,
                  color: s.remainingKcal < 0 ? PulseColors.warning : scheme.primary,
                  size: 76, stroke: 9,
                  child: Text('${((s.foodKcal / s.goals.calorieGoal) * 100).round()}%',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: PulseSpacing.l),
            // The intuitive equation: 1,340 eaten + 310 activity = 1,020 remaining
            Container(
              padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm, horizontal: PulseSpacing.s),
              decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(PulseRadius.m)),
              child: Row(children: [
                _eq(context, 'Goal', s.goals.calorieGoal.toStringAsFixed(0), scheme.onSurface.withOpacity(0.7)),
                _op(context, ''),
                _eq(context, 'Food', s.foodKcal.toStringAsFixed(0), PulseColors.accent),
                _op(context, '+'),
                _eq(context, 'Activity', s.activityCaloriesBurned.toStringAsFixed(0), PulseColors.steps),
                _op(context, '='),
                _eq(context, 'Remaining', s.remainingKcal.toStringAsFixed(0), scheme.primary, bold: true),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _eq(BuildContext c, String label, String v, Color color, {bool bold = false}) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 16.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: color)),
          Text(label, style: Theme.of(c).textTheme.labelSmall),
        ]),
      );
  Widget _op(BuildContext c, String o) => o.isEmpty
      ? const SizedBox(width: 4)
      : Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(o, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(c).colorScheme.onSurface.withOpacity(0.4))));

  // ── §18 Macro tracker
  Widget _macroCard(BuildContext context, PulseStore s) => Padding(
        padding: const EdgeInsets.only(bottom: PulseSpacing.m),
        child: PulseCard(
          onTap: () => Navigator.of(context).pushNamed('/nutrition-details'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Macros', style: Theme.of(context).textTheme.titleMedium)),
              Flexible(
                  child: Text('View nutrition',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary))),
              Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
            ]),
            MacroRow(label: 'Protein', current: s.protein, goal: s.goals.proteinGoal, color: PulseColors.protein, iconData: Icons.bolt_rounded),
            MacroRow(label: 'Carbohydrates', current: s.carbs, goal: s.goals.carbGoal, color: PulseColors.carbs, iconData: Icons.grain_rounded),
            MacroRow(label: 'Fat', current: s.fat, goal: s.goals.fatGoal, color: PulseColors.fat, iconData: Icons.water_drop_rounded),
            const SizedBox(height: PulseSpacing.xs),
            Text('You\'re ${(s.goals.proteinGoal - s.protein).toStringAsFixed(0)} g away from today\'s protein goal.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ── §19 Meals
  Widget _mealsCard(BuildContext context, PulseStore s) => Padding(
        padding: const EdgeInsets.only(bottom: PulseSpacing.m),
        child: PulseCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Meals', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => Navigator.of(context).pushNamed('/diary'), child: const Text('Open diary')),
            ]),
            for (final m in MealType.values)
              InkWell(
                borderRadius: BorderRadius.circular(PulseRadius.m),
                onTap: () => Navigator.of(context).pushNamed('/food-search', arguments: m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: PulseSpacing.xs),
                  child: Row(children: [
                    Icon(_mealIcon(m), size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                    const SizedBox(width: PulseSpacing.sm),
                    Expanded(child: Text(m.label, style: Theme.of(context).textTheme.bodyLarge)),
                    Text(s.kcalFor(m) > 0 ? '${s.kcalFor(m).toStringAsFixed(0)} kcal' : '+ Add Food',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: s.kcalFor(m) > 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: PulseSpacing.s),
                    Icon(Icons.add_circle_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  ]),
                ),
              ),
          ]),
        ),
      );

  static IconData _mealIcon(MealType m) => switch (m) {
        MealType.breakfast => Icons.free_breakfast_rounded,
        MealType.lunch => Icons.local_dining_rounded,
        MealType.dinner => Icons.restaurant_rounded,
        MealType.snacks => Icons.cookie_rounded,
      };

  // ── §27 Water card (full screen at /water)
  Widget _waterCard(BuildContext context, PulseStore s) {
    final pct = s.waterLogged / s.goals.waterGoalLiters;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.m),
      child: PulseCard(
        onTap: () => Navigator.of(context).pushNamed('/water'),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.water_drop_rounded, color: PulseColors.water, size: 20),
                const SizedBox(width: PulseSpacing.s),
                Text('Water', style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 2),
              Text('${s.waterLogged.toStringAsFixed(1)} / ${s.goals.waterGoalLiters.toStringAsFixed(1)} L',
                  style: PulseTypography.metricSmall.copyWith(color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: PulseSpacing.s),
              PulseBar(value: pct, color: PulseColors.water, height: 10),
              const SizedBox(height: PulseSpacing.s),
              Text(pct >= 1 ? 'Hydration goal complete. Nicely done.' : 'A glass now keeps you on pace.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
            ]),
          ),
          const SizedBox(width: PulseSpacing.m),
          FilledButton.tonalIcon(
              onPressed: () {
                s.addWater(0.25);
                HapticFeedback.mediumImpact();
                pulseSnack(context, '250 ml added', undoLabel: 'Undo', onUndo: () => s.addWater(-0.25), icon: Icons.water_drop_rounded);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+250 ml')),
        ]),
      ),
    );
  }

  // ── §39 Steps card w/ 7-day mini chart
  Widget _stepsCard(BuildContext context, PulseStore s) {
    final pct = s.stepsToday / s.goals.stepGoal;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.m),
      child: PulseCard(
        onTap: () => Navigator.of(context).pushNamed('/steps'),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.directions_walk_rounded, color: PulseColors.steps, size: 20),
                const SizedBox(width: PulseSpacing.s),
                Text('Steps', style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 2),
              Text('${s.stepsToday.toStringAsFixed(0)} / ${s.goals.stepGoal}',
                  style: PulseTypography.metricSmall.copyWith(color: Theme.of(context).colorScheme.onSurface)),
              Text('${(pct * 100).round()}% · Distance ${(s.stepsToday * 0.000715).toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5)),
              const SizedBox(height: PulseSpacing.s),
              Text('A 10-minute walk would put you close to today\'s step target.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
            ]),
          ),
          // C1: this was a seven-bar chart drawn from a const list, presented
          // as the user's week. Nothing records step history — the store holds
          // only stepsToday — so the week cannot be drawn honestly. Today's
          // ring is real; the fabricated week is gone rather than invented.
          Expanded(
            flex: 2,
            child: Semantics(
              label: 'Steps today: ${(pct * 100).round()} percent of goal',
              child: Align(
                alignment: Alignment.centerRight,
                child: PulseRing(value: pct, size: 56, stroke: 6, color: PulseColors.steps),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── §40 Healthy habits strip
  Widget _habitsCard(BuildContext context, PulseStore s) => Padding(
        padding: const EdgeInsets.only(bottom: PulseSpacing.m),
        child: PulseCard(
          onTap: () => Navigator.of(context).pushNamed('/habits'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Healthy Habits', style: Theme.of(context).textTheme.titleMedium)),
              Text('Customize', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
            ]),
            const SizedBox(height: PulseSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                // C1: each habit's `progress` was a literal ('1.7 / 2.6 L',
                // '6,842 / 8,000') that no store field feeds. The chip now
                // names the habit it tracks and nothing more.
                for (final h in PulseData.habits.where((h) => h.on))
                  Padding(
                    padding: const EdgeInsets.only(right: PulseSpacing.s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.sm, vertical: PulseSpacing.s),
                      decoration: BoxDecoration(
                          color: h.color.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m),
                          border: Border.all(color: h.color.withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(h.icon, size: 16, color: h.color),
                        const SizedBox(width: 6),
                        Text(h.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      );

  // ── Actionable insight teaser (§47)
  /// C1: this read 'You reached at least 90% of your protein goal on 5 of the
  /// last 7 days' on a fresh install, where nothing had been logged at all.
  /// The strip now stays hidden until there is data to say something about.
  Widget _insightStrip(BuildContext context, PulseStore s) {
    if (!s.hasAnyData) return const SizedBox.shrink();
    final ins = PulseData.insights[0];
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.m),
      child: PulseCard(
        onTap: () => Navigator.of(context).pushNamed('/insights'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ins.color.withOpacity(0.12), borderRadius: BorderRadius.circular(PulseRadius.s)),
              child: Icon(ins.icon, size: 18, color: ins.color)),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Insight · ${ins.title}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5)),
            const SizedBox(height: 2),
            Text(ins.body, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
          ])),
          Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
        ]),
      ),
    );
  }

  // ── §80 Customize Today — module reordering sheet
  void _customize(BuildContext context, PulseStore s) {
    pulseSheet(context, tall: true, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHeader(title: 'Customize Today', subtitle: 'Drag to reorder · toggle what matters to you.'),
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: modules.length,
              onReorder: (oldI, newI) => setSheet(() {
                final item = modules.removeAt(oldI);
                modules.insert(newI > oldI ? newI - 1 : newI, item);
              }),
              itemBuilder: (_, i) => ListTile(
                key: ValueKey(modules[i]),
                leading: Icon(_moduleIcon(modules[i])),
                title: Text(_moduleLabel(modules[i])),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(value: true, onChanged: (v) => setSheet(() { if (!v) modules.removeAt(i); })),
                  const Icon(Icons.drag_handle_rounded),
                ]),
              ),
            ),
          ),
          const Padding(padding: EdgeInsets.all(PulseSpacing.m), child: PrimaryButton(label: 'Done')),
        ]),
      ),
    ));
  }

  static IconData _moduleIcon(String m) => switch (m) {
        'score' => Icons.speed_rounded,
        'calories' => Icons.local_fire_department_rounded,
        'macros' => Icons.pie_chart_outline_rounded,
        'meals' => Icons.restaurant_rounded,
        'water' => Icons.water_drop_outlined,
        'steps' => Icons.directions_walk_rounded,
        'habits' => Icons.eco_rounded,
        _ => Icons.lightbulb_outline_rounded,
      };
  static String _moduleLabel(String m) => switch (m) {
        'score' => 'Daily Score',
        'calories' => 'Calories',
        'macros' => 'Macros',
        'meals' => 'Meals',
        'water' => 'Water',
        'steps' => 'Steps',
        'habits' => 'Habits',
        _ => 'Insights',
      };
}

// ── §27 Full Water screen ──────────────────────────────────────────
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = PulseStore.of(context);
    final pct = s.waterLogged / s.goals.waterGoalLiters;
    return PulseScaffold(
      title: 'Water',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        // Visual hydration glass
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.xl),
          child: Column(children: [
            SizedBox(
              height: 220, width: 140,
              child: Stack(alignment: Alignment.bottomCenter, children: [
                Container(
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), width: 2)),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
                    duration: PulseDuration.slow,
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(
                        height: 218 * v, width: 138,
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF5EA9E0), PulseColors.water], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                  ),
                ),
                Center(child: Text('${s.waterLogged.toStringAsFixed(1)} L',
                    style: PulseTypography.metricMedium.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 8, color: Colors.black38)]))),
              ]),
            ),
            const SizedBox(height: PulseSpacing.l),
            Text('${s.waterLogged.toStringAsFixed(1)} / ${s.goals.waterGoalLiters.toStringAsFixed(1)} L', style: Theme.of(context).textTheme.headlineSmall),
            Text(pct >= 1 ? 'Goal reached — beautiful consistency.' : 'Steady sips beat big gulps. Keep going.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        Row(children: [
          Expanded(child: _quickWater(context, s, 0.25, '+250 ml')),
          const SizedBox(width: PulseSpacing.s),
          Expanded(child: _quickWater(context, s, 0.5, '+500 ml')),
          const SizedBox(width: PulseSpacing.s),
          Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _customWater(context, s),
                icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Custom')),
          ),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Today\'s sips'),
        // §3: five invented rows sat here, each with a delete button that
        // subtracted a volume belonging to no real entry. These are the
        // drinks actually logged today, newest first.
        if (s.sips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PulseSpacing.m),
            child: Text('Nothing logged yet today.',
                style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          for (final sip in s.sips.reversed.toList(growable: false))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
              leading: const Icon(Icons.water_drop_rounded, color: PulseColors.water, size: 20),
              title: Text('${(sip.liters * 1000).toStringAsFixed(0)} ml'),
              subtitle: Text(fmtClockTime(sip.at)),
              trailing: IconButton(
                  tooltip: 'Remove this entry',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () {
                    s.removeSip(sip);
                    pulseSnack(context, 'Entry removed',
                        undoLabel: 'Undo',
                        onUndo: () => s.logSip(sip.liters, now: sip.at));
                  }),
            ),
      ]),
    );
  }

  Widget _quickWater(BuildContext c, PulseStore s, double l, String label) => FilledButton.tonalIcon(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
      onPressed: () {
        s.addWater(l);
        HapticFeedback.mediumImpact();
        pulseSnack(c, '${(l * 1000).toStringAsFixed(0)} ml added', undoLabel: 'Undo', onUndo: () => s.addWater(-l), icon: Icons.water_drop_rounded);
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label));

  void _customWater(BuildContext c, PulseStore s) {
    final controller = TextEditingController(text: '355');
    pulseSheet(c, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpacing.l),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SheetHeader(title: 'Custom amount'),
              TextField(
                  controller: controller, keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Amount', suffixText: s.unitsVolume == 'ml' ? 'ml' : 'oz',
                      errorText: int.tryParse(controller.text) == null ? 'Enter a valid amount' : null),
                  onChanged: (_) => set(() {})),
              const SizedBox(height: PulseSpacing.m),
              PrimaryButton(label: 'Add', onTap: () {
                final ml = int.tryParse(controller.text);
                if (ml != null && ml > 0) {
                  s.addWater(ml / 1000);
                  Navigator.pop(ctx);
                  pulseSnack(c, '$ml ml added', undoLabel: 'Undo', onUndo: () => s.addWater(-ml / 1000));
                }
              }),
            ]),
          ))));
  }
}
