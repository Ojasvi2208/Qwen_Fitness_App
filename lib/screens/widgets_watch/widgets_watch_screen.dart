import 'package:flutter/material.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 16 — Widgets (§81) + Watch experience (§82).
/// Widget art is drawn with the same tokens as the app, so a native
/// widget implementation (Glance / SwiftUI) maps 1:1.
/// ═══════════════════════════════════════════════════════════════════

class WidgetsWatchScreen extends StatelessWidget {
  const WidgetsWatchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.pulseWatch;
    // §3: every tile below carried a literal — "6,842 / 8,000" steps for
    // a user who had taken none. These are previews of the real widgets,
    // so they must preview the real numbers.
    final g = store.goals;
    double pct(double v, double goal) => goal <= 0 ? 0 : (v / goal).clamp(0.0, 1.0);

    return PulseScaffold(
      title: 'Widgets & Watch',
      subtitle: 'At-a-glance status without opening PULSE',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SectionHeader(title: 'Home-screen widgets'),
        // Small widgets row
        Wrap(spacing: PulseSpacing.m, runSpacing: PulseSpacing.m, children: [
          _WidgetSmall(label: 'Calories', value: '${store.foodKcal.round()} / ${g.calorieGoal.round()}', pct: pct(store.foodKcal, g.calorieGoal), color: PulseColors.accent, icon: Icons.local_fire_department_rounded),
          _WidgetSmall(label: 'Protein', value: '${store.protein.round()} / ${g.proteinGoal.round()} g', pct: pct(store.protein, g.proteinGoal), color: PulseColors.protein, icon: Icons.bolt_rounded),
          _WidgetSmall(label: 'Steps', value: '${store.stepsToday.round()} / ${g.stepGoal}', pct: pct(store.stepsToday, g.stepGoal.toDouble()), color: PulseColors.steps, icon: Icons.directions_walk_rounded),
          _WidgetSmall(label: 'Water', value: '${store.waterLogged.toStringAsFixed(1)} / ${g.waterGoalLiters.toStringAsFixed(1)} L', pct: pct(store.waterLogged, g.waterGoalLiters), color: PulseColors.water, icon: Icons.water_drop_rounded),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Medium · progress + quick log'),
        _WidgetMedium(store: store),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Large · full day at a glance'),
        _WidgetLarge(store: store),
        const SizedBox(height: PulseSpacing.xl),
        Divider(color: scheme.onSurface.withOpacity(0.12)),
        SectionHeader(title: 'Watch experience'),
        Wrap(spacing: PulseSpacing.m, runSpacing: PulseSpacing.m, children: [
          _WatchTile(title: 'Calories', lines: ['${store.foodKcal.round()} kcal', '${store.remainingKcal.round()} left'], ring: pct(store.foodKcal, g.calorieGoal), ringColor: PulseColors.accent),
          _WatchTile(title: 'Macros', lines: ['Protein', '${store.protein.round()} / ${g.proteinGoal.round()} g'], ring: pct(store.protein, g.proteinGoal), ringColor: PulseColors.protein),
          _WatchTile(title: 'Water', lines: ['${store.waterLogged.toStringAsFixed(1)} / ${g.waterGoalLiters.toStringAsFixed(1)} L'], ring: pct(store.waterLogged, g.waterGoalLiters), ringColor: PulseColors.water),
          _WatchTile(title: 'Steps', lines: ['${store.stepsToday.round()} / ${g.stepGoal}'], ring: pct(store.stepsToday, g.stepGoal.toDouble()), ringColor: PulseColors.steps),
          const _WatchTile(title: 'Quick Log', lines: ['Food', 'Water', 'Exercise'], ring: null, ringColor: PulseColors.primary),
        ]),
        const SizedBox(height: PulseSpacing.m),
        Text('Watch screens use ≥ 16 pt type, high-contrast fills and the same macro colors as phone. Complications show a single metric ring.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _WidgetSmall extends StatelessWidget {
  const _WidgetSmall({required this.label, required this.value, required this.pct, required this.color, required this.icon});
  final String label, value; final double pct; final Color color; final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 150, height: 150,
        padding: const EdgeInsets.all(PulseSpacing.m),
        decoration: BoxDecoration(color: const Color(0xFF1B2A24), borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color, size: 18), const Spacer(), Text('PULSE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.4)))]),
          const Spacer(),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
          Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Colors.white24, color: color)),
        ]),
      );
}

class _WidgetMedium extends StatelessWidget {
  const _WidgetMedium({required this.store});
  final PulseStore store;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(PulseSpacing.l),
        decoration: BoxDecoration(color: const Color(0xFF1B2A24), borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
            const SizedBox(height: 4),
            Text('${store.remainingKcal.round()} kcal left', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 10),
            Row(children: [
              _miniMacro('P', _pct(store.protein, store.goals.proteinGoal), PulseColors.protein),
              const SizedBox(width: 8),
              _miniMacro('C', _pct(store.carbs, store.goals.carbGoal), PulseColors.carbs),
              const SizedBox(width: 8),
              _miniMacro('F', _pct(store.fat, store.goals.fatGoal), PulseColors.fat),
            ]),
          ])),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _widgetBtn(Icons.add_rounded),
            const SizedBox(height: 8),
            _widgetBtn(Icons.water_drop_rounded),
            const SizedBox(height: 8),
            _widgetBtn(Icons.qr_code_scanner_rounded),
          ]),
        ]),
      );

  static double _pct(double v, double goal) => goal <= 0 ? 0 : (v / goal).clamp(0.0, 1.0);

  static Widget _miniMacro(String l, double v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: Colors.white12, color: c)),
      ]));

  static Widget _widgetBtn(IconData i) => Container(width: 34, height: 34,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(i, color: Colors.white, size: 18));
}

class _WidgetLarge extends StatelessWidget {
  const _WidgetLarge({required this.store});
  final PulseStore store;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(PulseSpacing.l),
        decoration: BoxDecoration(color: const Color(0xFF1B2A24), borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(fmtGreeting(DateTime.now()), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            PulseRing(value: store.dailyScore, color: PulseColors.primary, size: 34, stroke: 4,
                child: Text('${(store.dailyScore * 100).round()}%', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            BigStatWidget('${store.remainingKcal.round()}', 'kcal left', PulseColors.accent),
            BigStatWidget('${store.protein.round()} g', 'protein', PulseColors.protein),
            BigStatWidget('${store.stepsToday.round()}', 'steps', PulseColors.steps),
            BigStatWidget('${store.waterLogged.toStringAsFixed(1)} L', 'water', PulseColors.water),
          ]),
        ]),
      );

}

// Rebuild big stats via helper to keep constructor simple.
class BigStatWidget extends StatelessWidget {
  const BigStatWidget(this.v, this.l, this.c);
  final String v, l; final Color c;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: c)),
        Text(l, style: const TextStyle(fontSize: 10.5, color: Colors.white60, fontWeight: FontWeight.w600)),
      ]));
}

// ── §82 Watch tiles ────────────────────────────────────────────────
class _WatchTile extends StatelessWidget {
  const _WatchTile({required this.title, required this.lines, required this.ring, required this.ringColor});
  final String title; final List<String> lines; final double? ring; final Color ringColor;
  @override
  Widget build(BuildContext context) => Container(
        width: 150, height: 170,
        padding: const EdgeInsets.all(PulseSpacing.m),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white70)),
            const Spacer(),
            if (ring != null)
              SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, value: ring!, color: ringColor, backgroundColor: Colors.white12)),
          ]),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(l, style: TextStyle(fontSize: l.startsWith('+') ? 13 : 15, fontWeight: l.startsWith('+') ? FontWeight.w600 : FontWeight.w800,
                  color: l.startsWith('+') ? ringColor : Colors.white)),
            ),
        ]),
      );
}
