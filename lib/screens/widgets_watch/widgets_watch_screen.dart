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
    return PulseScaffold(
      title: 'Widgets & Watch',
      subtitle: 'At-a-glance status without opening PULSE',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SectionHeader(title: 'Home-screen widgets'),
        // Small widgets row
        Wrap(spacing: PulseSpacing.m, runSpacing: PulseSpacing.m, children: const [
          _WidgetSmall(label: 'Calories', value: '1,340 / 2,050', pct: 0.65, color: PulseColors.accent, icon: Icons.local_fire_department_rounded),
          _WidgetSmall(label: 'Protein', value: '92 / 135 g', pct: 0.68, color: PulseColors.protein, icon: Icons.bolt_rounded),
          _WidgetSmall(label: 'Steps', value: '6,842 / 8,000', pct: 0.86, color: PulseColors.steps, icon: Icons.directions_walk_rounded),
          _WidgetSmall(label: 'Water', value: '1.7 / 2.6 L', pct: 0.65, color: PulseColors.water, icon: Icons.water_drop_rounded),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Medium · progress + quick log'),
        const _WidgetMedium(),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Large · full day at a glance'),
        const _WidgetLarge(),
        const SizedBox(height: PulseSpacing.xl),
        Divider(color: scheme.onSurface.withOpacity(0.12)),
        SectionHeader(title: 'Watch experience'),
        const Wrap(spacing: PulseSpacing.m, runSpacing: PulseSpacing.m, children: [
          _WatchTile(title: 'Calories', lines: ['1,340 kcal', '1,020 left'], ring: 0.65, ringColor: PulseColors.accent),
          _WatchTile(title: 'Macros', lines: ['Protein', '92 / 135 g', '+10 g'], ring: 0.68, ringColor: PulseColors.protein),
          _WatchTile(title: 'Water', lines: ['1.7 / 2.6 L', '+250 ml'], ring: 0.65, ringColor: PulseColors.water),
          _WatchTile(title: 'Steps', lines: ['6,842 / 8,000'], ring: 0.86, ringColor: PulseColors.steps),
          _WatchTile(title: 'Workout', lines: ['Upper Body', 'Set 2 of 4', 'rest 1:30'], ring: 0.4, ringColor: PulseColors.exercise),
          _WatchTile(title: 'Quick Log', lines: ['Food', 'Water', 'Exercise'], ring: null, ringColor: PulseColors.primary),
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
  const _WidgetMedium();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(PulseSpacing.l),
        decoration: BoxDecoration(color: const Color(0xFF1B2A24), borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
            const SizedBox(height: 4),
            const Text('1,020 kcal left', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 10),
            Row(children: [
              _miniMacro('P', 0.68, PulseColors.protein),
              const SizedBox(width: 8),
              _miniMacro('C', 0.66, PulseColors.carbs),
              const SizedBox(width: 8),
              _miniMacro('F', 0.63, PulseColors.fat),
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

  static Widget _miniMacro(String l, double v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: Colors.white12, color: c)),
      ]));

  static Widget _widgetBtn(IconData i) => Container(width: 34, height: 34,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(i, color: Colors.white, size: 18));
}

class _WidgetLarge extends StatelessWidget {
  const _WidgetLarge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(PulseSpacing.l),
        decoration: BoxDecoration(color: const Color(0xFF1B2A24), borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Good morning', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            const PulseRing(value: 0.74, color: PulseColors.primary, size: 34, stroke: 4,
                child: Text('74%', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white))),
          ]),
          const SizedBox(height: 12),
          const Row(children: [
            BigStatWidget('1,020', 'kcal left', PulseColors.accent),
            BigStatWidget('92 g', 'protein', PulseColors.protein),
            BigStatWidget('6,842', 'steps', PulseColors.steps),
            BigStatWidget('1.7 L', 'water', PulseColors.water),
          ]),
          const SizedBox(height: 14),
          Container(height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                SizedBox(width: 10),
                Icon(Icons.fitness_center_rounded, color: Colors.white70, size: 15),
                SizedBox(width: 8),
                Text('Next: Upper Body Strength · 6:30 PM', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ])),
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
