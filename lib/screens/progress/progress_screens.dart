import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 10 — Progress & Analytics (§41–§51). Flow E:
/// Progress → Weight → Date range → Chart → Insight.
/// Every chart carries a textual explanation (accessibility rule §70).
/// ═══════════════════════════════════════════════════════════════════

// ── §41 Progress Home ──────────────────────────────────────────────
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _range = 1; // 30 days default
  static const _ranges = ['7 Days', '30 Days', '3 Months', '6 Months', '1 Year', 'All'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PulseStore>();
    if (!store.hasAnyData) {
      return SafeArea(
        child: EmptyState(
            icon: Icons.insights_rounded,
            title: 'Your progress starts here',
            body: 'Log your weight, meals or workouts and your trends will appear over time.',
            actionLabel: 'Add First Entry',
            onAction: () => openQuickLog(context)),
      );
    }
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 120), children: [
        Row(children: [
          Expanded(child: Text('Your Progress', style: Theme.of(context).textTheme.headlineMedium)),
          IconButton3(icon: Icons.calendar_month_rounded, tooltip: 'History calendar',
              onTap: () => pulseSheet(context, builder: (_) => const _ProgressCalendar())),
        ]),
        const SizedBox(height: PulseSpacing.m),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < _ranges.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: PulseSpacing.s),
                child: ChoiceChip(label: Text(_ranges[i]), selected: _range == i, onSelected: (_) => setState(() => _range = i)),
              ),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        // High-level overview tiles
        PulseCard(
          onTap: () => Navigator.of(context).pushNamed('/weight-progress'),
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Weight', style: Theme.of(context).textTheme.titleMedium)),
              TrendIndicator(changeKg: -0.8, goodWhenNegative: true, label: 'this month'),
            ]),
            const SizedBox(height: PulseSpacing.s),
            Text('${store.currentWeightKg.toStringAsFixed(1)} kg', style: PulseTypography.metricLarge.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            Text('Goal ${store.goals.targetWeightKg.toStringAsFixed(0)} kg · ${(store.currentWeightKg - store.goals.targetWeightKg).toStringAsFixed(1)} kg remaining',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: PulseSpacing.s),
            PulseBar(value: ((84.5 - store.currentWeightKg) / (84.5 - store.goals.targetWeightKg)).clamp(0, 1), color: PulseColors.success, height: 8),
          ]),
        ),
        const SizedBox(height: PulseSpacing.m),
        Row(children: [
          Expanded(
            child: _tile(context, 'Nutrition', '2,084 kcal avg\n7-day', Icons.restaurant_rounded, PulseColors.accent, () => Navigator.of(context).pushNamed('/nutrition-progress')),
          ),
          const SizedBox(width: PulseSpacing.s),
          Expanded(
            child: _tile(context, 'Activity', '6,932 steps avg\n7-day', Icons.directions_walk_rounded, PulseColors.steps, () => Navigator.of(context).pushNamed('/activity-progress')),
          ),
        ]),
        const SizedBox(height: PulseSpacing.m),
        Row(children: [
          Expanded(
            child: _tile(context, 'Workouts', '4 completed\nthis week', Icons.fitness_center_rounded, PulseColors.exercise, () => Navigator.of(context).pushNamed('/activity-detail')),
          ),
          const SizedBox(width: PulseSpacing.s),
          Expanded(
            child: _tile(context, 'Measurements', 'Waist 88 cm\n−3 cm', Icons.straighten_rounded, PulseColors.fiber, () => Navigator.of(context).pushNamed('/measurements')),
          ),
        ]),
        const SizedBox(height: PulseSpacing.m),
        SecondaryButton(label: 'Progress Photos', icon: Icons.photo_library_rounded,
            onTap: () => Navigator.of(context).pushNamed('/progress-photos')),
        const SizedBox(height: PulseSpacing.s),
        SecondaryButton(label: 'Weekly Report', icon: Icons.newspaper_rounded,
            onTap: () => Navigator.of(context).pushNamed('/weekly-report')),
        const SizedBox(height: PulseSpacing.s),
        SecondaryButton(label: 'Insights', icon: Icons.lightbulb_rounded,
            onTap: () => Navigator.of(context).pushNamed('/insights')),
      ]),
    );
  }

  Widget _tile(BuildContext c, String title, String value, IconData icon, Color color, VoidCallback onTap) => PulseCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: PulseSpacing.sm),
          Text(title, style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(c).textTheme.bodySmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
        ]),
      );
}

// ── §42 Weight Progress ────────────────────────────────────────────
class WeightProgressScreen extends StatelessWidget {
  const WeightProgressScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<PulseStore>();
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Weight',
      subtitle: 'Trend view — daily fluctuation is noise, direction is signal',
      actions: [IconButton3(icon: Icons.add_rounded, selected: true, tooltip: 'Log weight',
          onTap: () => Navigator.of(context).pushNamed('/log-weight'))],
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Row(children: [
            _stat(context, 'Starting', '84.5 kg'),
            _stat(context, 'Current', '${store.currentWeightKg.toStringAsFixed(1)} kg'),
            _stat(context, 'Goal', '${store.goals.targetWeightKg.toStringAsFixed(0)} kg'),
          ]),
        ),
        const SizedBox(height: PulseSpacing.s),
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Row(children: [
            _stat(context, 'Change', '−4.7 kg'),
            _stat(context, 'Remaining', '4.8 kg'),
            Expanded(child: TrendIndicator(changeKg: -4.7, goodWhenNegative: true, label: 'since start')),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Trend', actionLabel: '30D ▾', onAction: () => pulseSnack(context, 'Range picker: 7D / 30D / 3M / 1Y.')),
        PulseCard(
          child: Column(children: [
            Semantics(
              label: 'Weight trend line from 84.5 kilograms down to 79.8 kilograms over the last weeks, goal 75 kilograms.',
              child: PulseLineChart(points: store.weightSeries, height: 190, color: scheme.primary, goalY: store.goals.targetWeightKg),
            ),
            const SizedBox(height: PulseSpacing.s),
            Row(children: [
              Container(width: 14, height: 3, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Your weight trend', style: scheme.textTheme.labelMedium),
              const SizedBox(width: PulseSpacing.l),
              Container(width: 14, height: 0, decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.primary.withOpacity(0.4), width: 1.4)))),
              const SizedBox(width: 6),
              Text('Goal 75 kg', style: scheme.textTheme.labelMedium),
            ]),
          ]),
        ),
        const SizedBox(height: PulseSpacing.m),
        Container(
          padding: const EdgeInsets.all(PulseSpacing.m),
          decoration: BoxDecoration(color: PulseColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m)),
          child: Row(children: [
            const Icon(Icons.trending_down_rounded, color: PulseColors.success, size: 22),
            const SizedBox(width: PulseSpacing.sm),
            Expanded(child: Text('Your overall trend is moving toward your goal.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface))),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Entries'),
        for (final e in store.weights.reversed.take(6))
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            leading: CircleAvatar(radius: 16, backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(Icons.monitor_weight_rounded, size: 16, color: scheme.onSurface.withOpacity(0.6))),
            title: Text('${e.weightKg.toStringAsFixed(1)} kg', style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface, fontSize: 16)),
            subtitle: Text(_fmtDate(e.date)),
            trailing: IconButton3(icon: Icons.delete_outline_rounded, size: 38, tooltip: 'Delete entry',
                onTap: () async {
                  final ok = await pulseConfirm(context,
                      title: 'Delete this weigh-in?',
                      body: 'The ${e.weightKg.toStringAsFixed(1)} kg entry from ${_fmtDate(e.date)} will be removed from your trend.',
                      confirmLabel: 'Delete', destructive: true);
                  if (ok && context.mounted) {
                    store.deleteWeight(e.date);
                    pulseSnack(context, 'Entry deleted', undoLabel: 'Undo', onUndo: () => store.logWeight(e.weightKg, date: e.date));
                  }
                }),
          ),
        const HealthDisclaimer(),
      ]),
    );
  }

  Widget _stat(BuildContext c, String l, String v) => Expanded(
      child: Column(children: [
        Text(v, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
        Text(l, style: Theme.of(c).textTheme.labelSmall),
      ]));

  static String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Log Weight screen (§75 validation demo) ────────────────────────
class LogWeightScreen extends StatefulWidget {
  const LogWeightScreen({super.key});
  @override
  State<LogWeightScreen> createState() => _LogWeightScreenState();
}

class _LogWeightScreenState extends State<LogWeightScreen> {
  final _value = TextEditingController();
  String? _error;

  @override
  void dispose() { _value.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.read<PulseStore>();
    return PulseScaffold(
      title: 'Log Weight',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.xl), children: [
        Text('Today\'s number is just one point.', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: PulseSpacing.s),
        Text('We\'ll add it to your trend — the direction over weeks matters far more than any single day.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.xl),
        TextField(
          controller: _value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() => _error = null),
          decoration: InputDecoration(
              labelText: 'Weight', suffixText: store.unitsWeight == 'kg' ? 'kg' : 'lb',
              errorText: _error),
        ),
        const SizedBox(height: PulseSpacing.m),
        PrimaryButton(label: 'Save', icon: Icons.check_rounded, onTap: () {
          final v = double.tryParse(_value.text.replaceAll(',', '.'));
          if (v == null || v < 25 || v > 300) {
            setState(() => _error = 'Enter a valid weight');
            return;
          }
          store.logWeight(v);
          store.track('weight_logged');
          Navigator.pop(context);
          pulseSnack(context, 'Logged ${v.toStringAsFixed(1)} kg', icon: Icons.monitor_weight_rounded);
        }),
      ]),
    );
  }
}

// ── §43 Calorie Progress + §44 Macro Progress ──────────────────────
class NutritionProgressScreen extends StatelessWidget {
  const NutritionProgressScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Nutrition Progress',
      subtitle: 'Last 7 days',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SectionHeader(title: 'Calories'),
        PulseCard(
          child: Column(children: [
            PulseBarChart(values: const [1980, 2210, 2050, 2340, 1890, 2100, 2080], labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'], goal: 2050, highlightIndex: 6),
            const SizedBox(height: PulseSpacing.s),
            Row(children: [
              Expanded(child: _avg(context, 'Goal average', '2,050 kcal')),
              Expanded(child: _avg(context, '7-day average', '2,084 kcal')),
            ]),
            Text('Bars above the dashed goal line mean surplus days — three of seven were within ±5% of target.',
                style: scheme.textTheme.bodySmall),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Macros · weekly averages'),
        for (final m in const [
          ('Protein', '128 g', '135 g', '5 of 7 days', PulseColors.protein, 0.95),
          ('Carbohydrates', '215 g', '220 g', '6 of 7 days', PulseColors.carbs, 0.98),
          ('Fat', '68 g', '70 g', '5 of 7 days', PulseColors.fat, 0.97),
          ('Fiber', '22 g', '30 g', '2 of 7 days', PulseColors.fiber, 0.73),
        ])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PulseSpacing.m),
              child: Column(children: [
                Row(children: [
                  Icon(TrendIcons.macro(m.$1), color: m.$5, size: 18),
                  const SizedBox(width: PulseSpacing.s),
                  Expanded(child: Text(m.$1, style: Theme.of(context).textTheme.titleMedium)),
                  Text('Avg ${m.$2} · Goal ${m.$3}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5)),
                ]),
                const SizedBox(height: PulseSpacing.sm),
                PulseBar(value: m.$6, color: m.$5),
                const SizedBox(height: PulseSpacing.xs),
                Row(children: [
                  Expanded(child: Text('Goal consistency: ${m.$4}', style: Theme.of(context).textTheme.labelSmall)),
                  Text('${(m.$6 * 100).round()}% of goal', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        Container(
          padding: const EdgeInsets.all(PulseSpacing.m),
          decoration: BoxDecoration(color: PulseColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m)),
          child: Row(children: [
            const Icon(Icons.lightbulb_rounded, color: PulseColors.info, size: 20),
            const SizedBox(width: PulseSpacing.sm),
            Expanded(child: Text('Fiber is your lowest macro at 2 of 7 days. Adding beans, oats or fruit would move it fastest.',
                style: TextStyle(fontSize: 14.5, color: scheme.onSurface, height: 1.4))),
          ]),
        ),
      ]),
    );
  }

  Widget _avg(BuildContext c, String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
        Text(l, style: Theme.of(c).textTheme.labelSmall),
      ]);
}

class TrendIcons {
  TrendIcons._();
  static IconData macro(String name) => switch (name) {
        'Protein' => Icons.bolt_rounded,
        'Carbohydrates' => Icons.grain_rounded,
        'Fat' => Icons.water_drop_rounded,
        _ => Icons.eco_rounded,
      };
}

// ── §47 Activity Progress ──────────────────────────────────────────
class ActivityProgressScreen extends StatelessWidget {
  const ActivityProgressScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Activity Progress',
      subtitle: 'Steps · burn · workouts — last 7 days',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        PulseCard(
          child: Column(children: [
            PulseBarChart(values: const [5760, 7600, 4880, 8000, 7040, 3600, 6842], labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'], goal: 8000),
            const SizedBox(height: PulseSpacing.s),
            Text('You hit your step goal on 2 of 7 days. Weekends dip most — a Sunday walk habit could fix that.',
                style: TextStyle(fontSize: 14.5, height: 1.4, color: scheme.onSurface)),
          ]),
        ),
        const SizedBox(height: PulseSpacing.m),
        Row(children: [
          Expanded(child: _mini(context, 'Daily average', '6,932', 'steps')),
          const SizedBox(width: PulseSpacing.s),
          Expanded(child: _mini(context, 'Active calories', '2,140', 'kcal burned')),
          const SizedBox(width: PulseSpacing.s),
          Expanded(child: _mini(context, 'Workouts', '4', 'completed')),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'This month vs last'),
        PulseCard(
          child: Column(children: [
            _compare(context, 'Steps', 0.12, '+12%'),
            _compare(context, 'Workout minutes', 0.08, '+8%'),
            _compare(context, 'Active calories', -0.02, '−2%'),
            Text('Comparison bars show this month relative to last month at the same point in the cycle.',
                style: scheme.textTheme.bodySmall),
          ]),
        ),
        SecondaryButton(label: 'View workout history', icon: Icons.history_rounded,
            onTap: () => Navigator.of(context).pushNamed('/activity-detail')),
      ]),
    );
  }

  Widget _mini(BuildContext c, String l, String v, String unit) => PulseCard(
        child: Column(children: [
          Text(v, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
          Text(l, style: Theme.of(c).textTheme.labelSmall),
          Text(unit, style: Theme.of(c).textTheme.labelSmall),
        ]),
      );

  Widget _compare(BuildContext c, String label, double delta, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
        child: Row(children: [
          Expanded(child: Text(label, style: Theme.of(c).textTheme.bodyLarge)),
          SizedBox(width: 90,
              child: ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: (delta.abs() * 4).clamp(0.05, 1), minHeight: 8,
                      backgroundColor: c.dividerColor, color: delta >= 0 ? PulseColors.success : PulseColors.warning))),
          const SizedBox(width: PulseSpacing.sm),
          TrendIndicator(changePct: delta, label: ''),
        ]),
      );
}

// ── §45 Body Measurements ──────────────────────────────────────────
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});
  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  final Map<String, ({String value, String change})> _data = {
    'Weight': (value: '79.8 kg', change: '−4.7 kg'),
    'Body Fat %': (value: '21.4 %', change: '−2.1 %'),
    'Waist': (value: '88 cm', change: '−3 cm'),
    'Chest': (value: '101 cm', change: '−1 cm'),
    'Hips': (value: '99 cm', change: '−2 cm'),
    'Arms': (value: '33 cm', change: '+0.5 cm'),
    'Thighs': (value: '56 cm', change: '−1 cm'),
    'Neck': (value: '38 cm', change: '±0 cm'),
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () => mounted ? setState(() => _loading = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SafeArea(child: DashboardSkeleton());
    return PulseScaffold(
      title: 'Measurements',
      actions: [IconButton3(icon: Icons.add_rounded, selected: true, tooltip: 'Add measurement',
          onTap: () => _addMeasurement(context))],
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final e in _data.entries)
          Card(
            child: ListTile(
              leading: CircleAvatar(radius: 17, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.straighten_rounded, size: 17, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              title: Text(e.value, style: PulseTypography.metricSmall.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 17)),
              subtitle: Text(e.key),
              trailing: TrendIndicator(changeKg: double.tryParse(e.value.change.replaceAll(RegExp('[^0-9.\\-+]'), '')) ?? 0,
                  goodWhenNegative: e.key != 'Arms', label: e.value.change),
              onTap: () => _editMeasurement(context, e.key),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        TertiaryButton(label: '+ Add custom measurement', onTap: () => _addMeasurement(context)),
        const SizedBox(height: PulseSpacing.s),
        Text('Measurements are private to your account and excluded from any shared report unless you choose it.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  void _addMeasurement(BuildContext context) {
    final name = TextEditingController();
    final val = TextEditingController();
    pulseSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
      padding: const EdgeInsets.all(PulseSpacing.l),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetHeader(title: 'New measurement'),
        TextField(controller: name, decoration: InputDecoration(labelText: 'Name', errorText: name.text.isEmpty && val.text.isNotEmpty ? 'Give it a name' : null), onChanged: (_) => set(() {})),
        const SizedBox(height: PulseSpacing.m),
        TextField(controller: val, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Value', suffixText: 'cm',
                errorText: val.text.isNotEmpty && double.tryParse(val.text) == null ? 'Enter a valid number' : null),
            onChanged: (_) => set(() {})),
        const SizedBox(height: PulseSpacing.m),
        PrimaryButton(label: 'Save', onTap: () {
          final v = double.tryParse(val.text);
          if (name.text.trim().isEmpty || v == null) {
            set(() {});
            return;
          }
          ctx.pulse.track('measurement_logged');
          Navigator.pop(ctx);
          pulseSnack(context, '${name.text} saved at $v cm', icon: Icons.straighten_rounded);
        }),
      ]),
    )));
  }

  void _editMeasurement(BuildContext context, String key) {
    pulseSheet(context, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(PulseSpacing.l),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: 'Update $key', subtitle: 'Adds a new dated entry — history is kept.'),
        PrimaryButton(label: 'Enter new value', onTap: () { Navigator.pop(ctx); _addMeasurement(context); }),
      ]),
    ));
  }
}

// ── §46 Progress Photos (private by design) ────────────────────────
class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({super.key});
  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  double _slider = 0.5;
  String _angle = 'Front';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Progress Photos',
      actions: [IconButton3(icon: Icons.add_a_photo_rounded, tooltip: 'Take photo',
          onTap: () => pulseSnack(context, 'Camera opens. Photos save privately — never uploaded or shared automatically.', icon: Icons.lock_rounded))],
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        // Explicit privacy banner (§46 requirement)
        Container(
          padding: const EdgeInsets.all(PulseSpacing.m),
          decoration: BoxDecoration(color: PulseColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m),
              border: Border.all(color: PulseColors.success.withOpacity(0.4))),
          child: Row(children: [
            const Icon(Icons.visibility_off_rounded, color: PulseColors.success, size: 20),
            const SizedBox(width: PulseSpacing.s),
            Expanded(child: Text('Private — visible only to you',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface))),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        Row(children: [for (final a in const ['Front', 'Side', 'Back'])
          Expanded(child: Padding(padding: EdgeInsets.only(right: a == 'Back' ? 0 : PulseSpacing.s),
              child: ChoiceChip(label: Text(a, style: const TextStyle(fontSize: 13.5)), selected: _angle == a, onSelected: (_) => setState(() => _angle = a))))]),
        const SizedBox(height: PulseSpacing.l),
        // Comparison slider between two dated captures
        PulseCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SizedBox(height: 300,
              child: Stack(fit: StackFit.expand, children: [
                ClipRect(child: FractionallySizedBox(widthFactor: _slider, alignment: Alignment.centerLeft,
                    child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB9C6C1), Color(0xFF8FA39C))])))),
                Positioned.fill(child: Opacity(opacity: 0.0, child: Container(color: Colors.grey))),
                ClipRect(child: FractionallySizedBox(widthFactor: 1 - _slider, alignment: Alignment.centerRight,
                    child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7E938B), Color(0xFF5F7A70)]))))),
                Positioned(left: MediaQuery.sizeOf(context).width * _slider - 40, bottom: 12,
                    child: Text('Aug 1 · 84.5 kg', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]))),
                Positioned(right: 12, bottom: 12,
                    child: Text('Sep 29 · 79.8 kg', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]))),
                Positioned(left: MediaQuery.sizeOf(context).width * _slider - 1.5, top: 0, bottom: 0,
                    child: Container(width: 3, color: Colors.white,
                        child: Align(alignment: Alignment.center, child: Transform.translate(offset: const Offset(-13, 0),
                            child: CircleAvatar(radius: 15, backgroundColor: Colors.white, child: const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.black87))))),
                ),
              ])),
            Slider(value: _slider, onChanged: (v) => setState(() => _slider = v),
                semanticFormatterCallback: (v) => 'Comparison position ${(v * 100).round()} percent'),
          ]),
        ),
        const SizedBox(height: PulseSpacing.m),
        SectionHeader(title: 'Gallery · $_angle'),
        GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: PulseSpacing.s, crossAxisSpacing: PulseSpacing.s, childAspectRatio: 0.75,
            children: [
              for (final d in const ['Aug 1', 'Aug 15', 'Sep 1', 'Sep 15', 'Sep 29'])
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(alignment: Alignment.bottomLeft, children: [
                    Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF9DB4AB), const Color(0xFF6E8880)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ]),
                ),
            ]),
        const SizedBox(height: PulseSpacing.m),
        Text('Tip: use the same lighting, angle and time of day for the most honest comparisons.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

// ── §48 Weekly Report ──────────────────────────────────────────────
class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Your Week',
      subtitle: 'Sep 21–27 · delivered every Monday morning',
      actions: [IconButton3(icon: Icons.share_rounded, tooltip: 'Share report',
          onTap: () => pulseSnack(context, 'Shared as an image — only the metrics you ticked.', icon: Icons.image_rounded))],
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        Container(
          padding: const EdgeInsets.all(PulseSpacing.l),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary.withOpacity(0.16), scheme.primary.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(PulseRadius.l)),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded, color: PulseColors.secondary, size: 30),
            const SizedBox(width: PulseSpacing.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Biggest win', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('You completed four workouts this week.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ])),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        for (final sec in <({String title, IconData icon, List<({String l, String v, String sub})> rows})>[
          (title: 'Nutrition', icon: Icons.restaurant_rounded, rows: [
            (l: 'Average calories', v: '2,075', sub: 'goal 2,050 · +1%'),
            (l: 'Protein goal reached', v: '5 / 7', sub: 'days at ≥ 90% target'),
          ]),
          (title: 'Activity', icon: Icons.directions_walk_rounded, rows: [
            (l: 'Steps', v: '58,420', sub: 'daily avg 8,345'),
            (l: 'Active calories', v: '2,140', sub: '+12% vs last month'),
          ]),
          (title: 'Weight', icon: Icons.monitor_weight_rounded, rows: [
            (l: 'Trend change', v: '−0.8 kg', sub: 'moving toward 75 kg goal'),
          ]),
          (title: 'Workouts', icon: Icons.fitness_center_rounded, rows: [
            (l: 'Completed', v: '4', sub: 'strength 2 · cardio 1 · yoga 1'),
          ]),
          (title: 'Hydration', icon: Icons.water_drop_rounded, rows: [
            (l: 'Water goal reached', v: '6 / 7', sub: 'Thursday was the miss'),
          ]),
        ]) ...[
          SectionHeader(title: sec.title),
          PulseCard(
            child: Column(children: [
              for (final r in sec.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.l, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15.5)),
                      Text(r.sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                    ])),
                    Text(r.v, style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface, fontSize: 19)),
                  ]),
                ),
            ]),
          ),
        ],
        const SizedBox(height: PulseSpacing.m),
        Container(
          padding: const EdgeInsets.all(PulseSpacing.m),
          decoration: BoxDecoration(color: PulseColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m)),
          child: Row(children: [
            const Icon(Icons.flag_rounded, color: PulseColors.info, size: 20),
            const SizedBox(width: PulseSpacing.sm),
            Expanded(child: Text('Next week focus: keep protein above 130 g on weekend days — that\'s where the misses cluster.',
                style: TextStyle(fontSize: 14.5, height: 1.4, color: scheme.onSurface))),
          ]),
        ),
      ]),
    );
  }
}

// ── §47 Insights feed ──────────────────────────────────────────────
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Fitness Insights',
      subtitle: 'Patterns from your own data — not generic advice',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final ins in PulseData.insights)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PulseSpacing.m),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ins.color.withOpacity(0.12), borderRadius: BorderRadius.circular(PulseRadius.s)),
                    child: Icon(ins.icon, color: ins.color, size: 20)),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ins.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(ins.body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.45)),
                  Text(ins.action, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ins.color)),
                ])),
              ]),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        const HealthDisclaimer(),
      ]),
    );
  }
}

// ── §49 Streaks (non-punitive framing) ─────────────────────────────
class StreaksScreen extends StatelessWidget {
  const StreaksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Consistency',
      subtitle: 'Streaks celebrate rhythm — they never punish a miss',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final s in const [
          ('Food logging', '7-day streak', Icons.restaurant_rounded, PulseColors.accent, 7, 10),
          ('Hydration', '5-day streak', Icons.water_drop_rounded, PulseColors.water, 5, 10),
          ('Workout consistency', '3-week streak', Icons.fitness_center_rounded, PulseColors.exercise, 3, 8),
        ])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PulseSpacing.m),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: s.$4.withOpacity(0.12), borderRadius: BorderRadius.circular(PulseRadius.s)),
                    child: Icon(s.$3, color: s.$4, size: 20)),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$1, style: Theme.of(context).textTheme.titleMedium),
                  Text(s.$2, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: s.$4)),
                  const SizedBox(height: PulseSpacing.xs),
                  PulseBar(value: s.$5 / s.$6, color: s.$4, height: 6),
                ])),
              ]),
            ),
          ),
        const SizedBox(height: PulseSpacing.l),
        PulseCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('If a streak breaks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: PulseSpacing.xs),
            Text('You logged 18 of the last 21 days. That\'s still meaningful consistency.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
            const SizedBox(height: PulseSpacing.s),
            Text('PULSE keeps long-window stats like this alongside streaks so one quiet day never erases your record.',
                style: scheme.textTheme.bodySmall),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Achievements (§66)'),
        Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
          for (final a in const [('First Workout', Icons.emoji_events_rounded, true), ('10 Workouts', Icons.workspace_premium_rounded, true), ('50 km Walked', Icons.hiking_rounded, true), ('7-Day Logging', Icons.event_available_rounded, true), ('100,000 Steps', Icons.terrain_rounded, false), ('First Recipe', Icons.menu_book_rounded, false)])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.sm),
              decoration: BoxDecoration(
                  color: a.$3 ? PulseColors.secondary.withOpacity(0.12) : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(PulseRadius.full),
                  border: Border.all(color: a.$3 ? PulseColors.secondary.withOpacity(0.5) : scheme.dividerColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(a.$2, size: 17, color: a.$3 ? PulseColors.secondary : scheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 6),
                Text(a.$1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: a.$3 ? scheme.onSurface : scheme.onSurface.withOpacity(0.5))),
              ]),
            ),
        ]),
      ]),
    );
  }
}

// ── §50 Goals + §51 Smart adjustment prompt ────────────────────────
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _showAdjust = true; // demonstrates smart review card

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PulseStore>();
    final scheme = Theme.of(context).colorScheme;
    final goals = <({String label, String value, String route, IconData icon})>[
      (label: 'Goal Weight', value: '${store.goals.targetWeightKg.toStringAsFixed(0)} kg', route: '/goal-editor', icon: Icons.monitor_weight_rounded),
      (label: 'Weekly Weight Goal', value: '−0.4 kg/week', route: '/goal-editor', icon: Icons.trending_down_rounded),
      (label: 'Daily Calories', value: '${store.goals.calorieGoal.toStringAsFixed(0)} kcal', route: '/goal-editor', icon: Icons.local_fire_department_rounded),
      (label: 'Protein', value: '${store.goals.proteinGoal.toStringAsFixed(0)} g', route: '/goal-editor', icon: Icons.bolt_rounded),
      (label: 'Carbs', value: '${store.goals.carbGoal.toStringAsFixed(0)} g', route: '/goal-editor', icon: Icons.grain_rounded),
      (label: 'Fat', value: '${store.goals.fatGoal.toStringAsFixed(0)} g', route: '/goal-editor', icon: Icons.water_drop_rounded),
      (label: 'Water', value: '${store.goals.waterGoalLiters.toStringAsFixed(1)} L', route: '/goal-editor', icon: Icons.water_drop_outlined),
      (label: 'Steps', value: '${store.goals.stepGoal}', route: '/goal-editor', icon: Icons.directions_walk_rounded),
      (label: 'Workouts', value: '4 / week', route: '/goal-editor', icon: Icons.fitness_center_rounded),
    ];
    return PulseScaffold(
      title: 'My Goals',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        if (_showAdjust)
          Card(
            color: scheme.primary.withOpacity(0.07),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.l), side: BorderSide(color: scheme.primary.withOpacity(0.4))),
            child: Padding(
              padding: const EdgeInsets.all(PulseSpacing.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: PulseSpacing.s),
                  Expanded(child: Text('Review your goals?', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton3(icon: Icons.close_rounded, size: 32, onTap: () => setState(() => _showAdjust = false)),
                ]),
                Text('Your weight and activity have changed since your plan was created. We suggest reviewing — your current targets stay exactly as they are until you confirm.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14.5, height: 1.45)),
                const SizedBox(height: PulseSpacing.sm),
                Row(children: [
                  FilledButton(onPressed: () => Navigator.of(context).pushNamed('/goal-editor'), child: const Text('Review Plan')),
                  const SizedBox(width: PulseSpacing.s),
                  TextButton(onPressed: () => setState(() => _showAdjust = false), child: const Text('Keep Current Plan')),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: PulseSpacing.s),
        for (final g in goals)
          Card(
            child: ListTile(
              leading: Icon(g.icon, color: scheme.onSurface.withOpacity(0.6)),
              title: Text(g.label, style: Theme.of(context).textTheme.titleMedium),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(g.value, style: PulseTypography.metricSmall.copyWith(color: scheme.primary, fontSize: 17)),
                const SizedBox(width: PulseSpacing.s),
                Icon(Icons.edit_outlined, size: 18, color: scheme.onSurface.withOpacity(0.4)),
              ]),
              onTap: () {
                store.track('goal_updated_opened');
                Navigator.of(context).pushNamed(g.route, arguments: g.label);
              },
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        Text('PULSE never changes your calorie target silently. Every edit is yours.',
            style: scheme.textTheme.bodySmall),
      ]),
    );
  }
}

// ── Goal Editor with live preview (Flow F) ─────────────────────────
class GoalEditorScreen extends StatefulWidget {
  const GoalEditorScreen({super.key, this.goalLabel});
  final String? goalLabel;
  @override
  State<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends State<GoalEditorScreen> {
  late double _target = 75;
  late double _pace = 0.4;
  int _previewStep = 0; // 0 edit, 1 review new targets

  @override
  Widget build(BuildContext context) {
    final store = context.read<PulseStore>();
    final scheme = Theme.of(context).colorScheme;
    final newKcal = (2050 + (75 - _target) * 18).round();
    return PulseScaffold(
      title: widget.goalLabel ?? 'Edit Weight Goal',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        if (_previewStep == 0) ...[
          SectionHeader(title: 'Target weight'),
          PulseCard(
            child: Column(children: [
              Text('${_target.toStringAsFixed(1)} kg', style: PulseTypography.metricLarge.copyWith(color: scheme.primary)),
              Slider(value: _target, min: 60, max: 90, divisions: 60, label: '${_target.toStringAsFixed(1)} kg',
                  onChanged: (v) => setState(() => _target = v)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Current: ${store.currentWeightKg.toStringAsFixed(1)} kg', style: scheme.textTheme.bodySmall),
                Text('From 84.5 kg you\'d lose ${(84.5 - _target).toStringAsFixed(1)} kg total', style: scheme.textTheme.bodySmall),
              ]),
            ]),
          ),
          const SizedBox(height: PulseSpacing.l),
          SectionHeader(title: 'Weekly pace'),
          PulseSegmented(options: const ['0.25', '0.4', '0.6'], index: _pace == 0.25 ? 0 : _pace == 0.4 ? 1 : 2,
              onChanged: (i) => setState(() => _pace = [0.25, 0.4, 0.6][i])),
          Text('${_pace} kg/week · ≈ ${((store.currentWeightKg - _target) / _pace).ceil()} weeks to goal',
              style: scheme.textTheme.bodySmall),
          const SizedBox(height: PulseSpacing.l),
          PrimaryButton(label: 'Preview New Targets', onTap: () => setState(() => _previewStep = 1)),
        ] else ...[
          // Review-before-confirm pattern (Flow F terminal state)
          SectionHeader(title: 'Review new targets'),
          PulseCard(
            padding: const EdgeInsets.all(PulseSpacing.l),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Daily Calories', style: Theme.of(context).textTheme.titleMedium),
                Text('$newKcal kcal', style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface)),
              ]),
              const Divider(height: PulseSpacing.xl),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Protein', style: Theme.of(context).textTheme.titleMedium),
                Text('135 g', style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface)),
              ]),
              const Divider(height: PulseSpacing.xl),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Weekly loss', style: Theme.of(context).textTheme.titleMedium),
                Text('−$_pace kg', style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface)),
              ]),
            ]),
          ),
          const SizedBox(height: PulseSpacing.m),
          if (_pace > 0.5)
            Container(
              padding: const EdgeInsets.all(PulseSpacing.m),
              decoration: BoxDecoration(color: PulseColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(PulseRadius.m)),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: PulseColors.warning, size: 20),
                const SizedBox(width: PulseSpacing.s),
                Expanded(child: Text('That pace is faster than we usually recommend. Slower protects muscle and energy.',
                    style: TextStyle(fontSize: 14.5, color: scheme.onSurface, height: 1.4))),
              ]),
            ),
          const SizedBox(height: PulseSpacing.l),
          PrimaryButton(label: 'Confirm Changes', icon: Icons.check_rounded, onTap: () {
            store.setTargets(targetWeightKg: _target);
            store.track('goal_updated');
            Navigator.pop(context);
            pulseSnack(context, 'Goals updated. Old targets remain in your history.', icon: Icons.flag_rounded);
          }),
          const SizedBox(height: PulseSpacing.s),
          TertiaryButton(label: 'Back to editing', onTap: () => setState(() => _previewStep = 0)),
        ],
      ]),
    );
  }
}

// ── §79 mini calendar for progress history ─────────────────────────
class _ProgressCalendar extends StatelessWidget {
  const _ProgressCalendar();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PulseSpacing.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHeader(title: 'September 2026', subtitle: 'Dots: • food logged ◦ workouts ✓ goal days'),
          GridView.count(
            crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var d = 1; d <= 30; d++)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 34, height: 34,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d == 29 ? scheme.primary : d % 7 == 0 ? scheme.primary.withOpacity(0.15) : Colors.transparent),
                        child: Center(child: Text('$d', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: d == 29 ? Colors.white : null)))),
                    Text(d % 3 == 0 ? '◦' : d % 4 == 0 ? '✓' : '', style: TextStyle(fontSize: 9, color: scheme.primary)),
                  ]),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
