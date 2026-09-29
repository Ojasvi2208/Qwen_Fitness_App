import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 11 — Pulse Coach (§52/§53) + §54 Global Search + §55 Notifications.
/// ═══════════════════════════════════════════════════════════════════

class _Msg { final bool mine; final String text; final List<({String name, String detail})>? options; final String? note;
  _Msg(this.mine, this.text, {this.options, this.note}); }

// ── §52 Coach home + conversation (screens 54 & 55) ───────────────
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  late final List<_Msg> _thread = [
    _Msg(false, 'Hi Alex. What can I help you with today?'),
  ];
  final _input = TextEditingController();
  bool _typing = false;

  static const _prompts = [
    'What should I eat for dinner?',
    'How can I reach my protein target?',
    'Build me a 30-minute workout.',
    'How did I do this week?',
    'Why was my calorie intake higher yesterday?',
  ];

  @override
  void dispose() { _input.dispose(); super.dispose(); }

  void _ask(String q) {
    setState(() {
      _thread.add(_Msg(true, q));
      _typing = true;
    });
    context.read<PulseStore>().track('coach_prompt_used');
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _thread.add(_answer(q, context.read<PulseStore>()));
      });
    });
  }

  _Msg _answer(String q, PulseStore s) {
    if (q.contains('protein')) {
      final short = (s.goals.proteinGoal - s.protein).toStringAsFixed(0);
      return _Msg(false, 'You\'re $short g short of your protein target today.', options: const [
        (name: 'Greek yogurt + berries', detail: '~20 g protein · 160 kcal'),
        (name: 'Egg omelette', detail: '~24 g protein · 280 kcal'),
        (name: 'Paneer bowl', detail: '~28 g protein · 340 kcal'),
      ], note: 'Approximate nutrition');
    }
    if (q.contains('dinner')) {
      return _Msg(false, 'You have ${s.remainingKcal.toStringAsFixed(0)} kcal left today. A chicken and vegetable stir-fry with rice fits well and covers about ${((s.goals.proteinGoal - s.protein) * 0.9).toStringAsFixed(0)} g of your remaining protein.', options: const [
        (name: 'Chicken stir-fry + rice', detail: '~520 kcal · 42 g protein'),
        (name: 'Salmon, potatoes & greens', detail: '~560 kcal · 38 g protein'),
        (name: 'High-protein pasta bake', detail: '~610 kcal · 45 g protein'),
      ], note: 'Approximate nutrition');
    }
    if (q.contains('workout') || q.contains('30-minute')) {
      return _Msg(false, 'Here\'s a 30-minute option using your dumbbells:', options: const [
        (name: 'Goblet Squat', detail: '3 × 12'),
        (name: 'One-Arm Row', detail: '3 × 12 each'),
        (name: 'Shoulder Press', detail: '3 × 10'),
        (name: 'Plank', detail: '3 × 40 sec'),
      ], note: 'Rest 60–90 s between sets · estimated 190 kcal');
    }
    if (q.contains('week')) {
      return _Msg(false, 'Your week in brief: average 2,075 kcal against a 2,050 goal, protein hit on 5 of 7 days, 58,420 steps and four workouts completed — your best week this month. Biggest win: consistency on evenings, where three of four misses used to happen.');
    }
    if (q.contains('higher yesterday')) {
      return _Msg(false, 'Yesterday totalled 2,340 kcal — about 290 above goal. The difference sits almost entirely in the evening: a 500 kcal snack after dinner, logged at 9:40 PM. Late-evening snacking is worth watching, but one day doesn\'t change your trend — you averaged 2,084 across the week.');
    }
    return _Msg(false, 'Happy to help with that. Using what you\'ve logged so far, the most useful next step is usually a small one — want me to suggest options?');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: PulseSpacing.m,
        title: Row(children: [
          CircleAvatar(radius: 17, backgroundColor: scheme.primary.withOpacity(0.14),
              child: Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary)),
          const SizedBox(width: PulseSpacing.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pulse Coach', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
            Text('Uses only your logged data', style: Theme.of(context).textTheme.labelSmall),
          ]),
        ]),
        actions: [IconButton3(icon: Icons.info_outline_rounded, tooltip: 'About Pulse Coach',
            onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text('About Pulse Coach'),
              content: const Text('Pulse Coach answers using your own logs, goals and history. It gives general fitness and nutrition guidance, clearly labels estimates, and never diagnoses medical conditions. For health concerns, talk to a qualified professional.',
                  style: TextStyle(height: 1.5)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            )))],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(PulseSpacing.m),
              itemCount: _thread.length + (_typing ? 1 : 0) + (_thread.length == 1 ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _thread.length) {
                  // typing indicator / suggestions block
                  if (_typing) return const Padding(
                    padding: EdgeInsets.symmetric(vertical: PulseSpacing.s),
                    child: Row(children: [
                      SizedBox(width: 44),
                      _TypingDots(),
                    ]),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(top: PulseSpacing.l),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Try asking', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: PulseSpacing.s),
                      Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s,
                          children: [for (final p in _prompts) ActionChip(label: Text(p, style: const TextStyle(fontSize: 13.5)), avatar: const Icon(Icons.search_rounded, size: 15), onPressed: () => _ask(p))]),
                    ]),
                  );
                }
                final m = _thread[i];
                return _bubble(m, scheme);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.m),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) { if (v.trim().isNotEmpty) { _ask(v.trim()); _input.clear(); } },
                  decoration: const InputDecoration(hintText: 'Ask about food, workouts or progress…'),
                ),
              ),
              const SizedBox(width: PulseSpacing.s),
              IconButton.filled(
                  onPressed: () {
                    final v = _input.text.trim();
                    if (v.isNotEmpty) { _ask(v); _input.clear(); }
                  },
                  icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(_Msg m, ColorScheme scheme) => Align(
        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: PulseSpacing.xs),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
          padding: const EdgeInsets.all(PulseSpacing.m),
          decoration: BoxDecoration(
              color: m.mine ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(PulseRadius.l), topRight: const Radius.circular(PulseRadius.l),
                  bottomLeft: Radius.circular(m.mine ? PulseRadius.l : PulseRadius.xs),
                  bottomRight: Radius.circular(m.mine ? PulseRadius.xs : PulseRadius.l))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.text, style: TextStyle(fontSize: 15.5, height: 1.45, color: m.mine ? Colors.white : scheme.onSurface)),
            if (m.options != null) ...[
              const SizedBox(height: PulseSpacing.sm),
              for (final o in m.options!)
                Material(
                  color: scheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(PulseRadius.m),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PulseRadius.m),
                    onTap: () => pulseSnack(context, '${o.name} added to Dinner · ${o.detail}', undoLabel: 'Undo', icon: Icons.add_rounded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.sm, vertical: 9),
                      child: Row(children: [
                        Icon(Icons.add_circle_outline_rounded, size: 17, color: scheme.primary),
                        const SizedBox(width: PulseSpacing.sm),
                        Expanded(child: Text(o.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface))),
                        Text(o.detail, style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withOpacity(0.6))),
                      ]),
                    ),
                  ),
                ),
            ],
            if (m.note != null) ...[
              const SizedBox(height: PulseSpacing.xs),
              Text(m.note!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface.withOpacity(0.55))),
            ],
            if (m.options != null && m.options!.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: PulseSpacing.xs),
                child: TextButton(onPressed: () => _ask('Find more options'), child: const Text('Find more options')),
              ),
          ]),
        ),
      );
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25 + 0.5 * ((_c.value * 3 + i) % 1)))),
          ),
      ]));
}

// ── §54 Global Search ──────────────────────────────────────────────
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _q = TextEditingController();
  int _tab = 0;
  static const _recent = ['Greek Yogurt', 'Upper Body Strength', 'Banana', 'Olive oil', 'Sleep'];

  @override
  void dispose() { _q.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final query = _q.text.trim().toLowerCase();
    final foods = PulseData.foods.where((f) => query.isEmpty || f.name.toLowerCase().contains(query)).take(6).toList();
    final workouts = PulseData.workoutLibrary.where((w) => w.name.toLowerCase().contains(query)).toList();
    final exercises = PulseData.upperBodyExercises.where((e) => e.name.toLowerCase().contains(query)).toList();
    final recipes = PulseData.recipes.where((r) => r.name.toLowerCase().contains(query)).toList();
    final help = query.isEmpty ? <String>[] : ['How do I connect Apple Health?', 'Editing goals', 'Deleting an entry'].where((h) => h.toLowerCase().contains(query.split(' ').first)).toList();

    return PulseScaffold(
      title: 'Search',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.s),
          child: TextField(
            controller: _q, autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                hintText: 'Search PULSE', prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _q.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(_q.clear)) : null),
          ),
        ),
        DefaultTabController(
          length: 5,
          child: Column(children: [
            TabBar(isScrollable: true, tabs: const ['Foods', 'Workouts', 'Recipes', 'Help', 'Recent'].map((t) => Tab(text: t)).toList(),
                onTap: (i) => setState(() => _tab = i)),
            Expanded(
              child: switch (_tab) {
                0 => _genList(foods.map((f) => (f.name, '${f.serving} · ${f.kcalPerServing.toStringAsFixed(0)} kcal', Icons.restaurant_rounded)),
                    '/food-detail'),
                1 => _genList(workouts.map((w) => (w.name, '${w.minutes} min • ${w.level}', Icons.fitness_center_rounded)), '/workout-detail'),
                2 => _genList(recipes.map((r) => (r.name, '${r.kcalPerServing.toStringAsFixed(0)} kcal / serving', Icons.menu_book_rounded)), '/recipes'),
                3 => _genList(help.map((h) => (h, 'Help article', Icons.help_outline_rounded)), null),
                _ => _genList(_recent.map((r) => (r, 'Recent search', Icons.history_rounded)), null),
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _genList(Iterable<(String, String, IconData)> items, String? route) => ListView(
        padding: const EdgeInsets.all(PulseSpacing.m),
        children: [
          if (items.isEmpty)
            EmptyState(icon: Icons.search_off_rounded, title: 'No results',
                body: 'Nothing matched “${_q.text}”. Check spelling or try fewer words.'),
          for (final it in items)
            Card(
              child: ListTile(
                leading: Icon(it.$3, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                title: Text(it.$1, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(it.$2),
                trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                onTap: () {
                  if (route == '/food-detail') {
                    final f = PulseData.foods.firstWhere((x) => x.name == it.$1, orElse: () => PulseData.foods[0]);
                    Navigator.of(context).pushNamed(route, arguments: (f, MealType.snacks));
                  } else if (route != null) {
                    Navigator.of(context).pushNamed(route, arguments: it.$1);
                  } else {
                    pulseSnack(context, 'Opening “${it.$1}”', icon: Icons.open_in_new_rounded);
                  }
                },
              ),
            ),
        ],
      );
}

// ── §55 Notification center ────────────────────────────────────────
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Notifications',
      actions: [TextButton(onPressed: () => pulseSnack(context, 'All marked as read.'), child: const Text('Mark all read'))],
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final n in const [
          ('Hydration reminder', 'You\'re 700 ml away from today\'s water goal.', Icons.water_drop_rounded, PulseColors.water, '2:15 PM', true),
          ('Workout reminder', 'Upper Body Strength is planned for 6:30 PM.', Icons.fitness_center_rounded, PulseColors.exercise, '1:00 PM', true),
          ('Weekly summary', 'Your weekly report is ready.', Icons.newspaper_rounded, PulseColors.info, 'Mon 8:00 AM', false),
          ('Goal milestone', 'You\'ve completed 20 workouts.', Icons.emoji_events_rounded, PulseColors.secondary, 'Sun', false),
          ('Insight', 'Protein goal reached on 5 of the last 7 days.', Icons.lightbulb_rounded, PulseColors.accent, 'Sat', false),
        ])
          Card(
            color: n.$6 ? scheme.primary.withOpacity(0.05) : null,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: 6),
              leading: CircleAvatar(backgroundColor: (n.$4 as Color).withOpacity(0.13),
                  child: Icon(n.$3, color: n.$4, size: 19)),
              title: Text(n.$1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: n.$6 ? FontWeight.w700 : FontWeight.w600)),
              subtitle: Text(n.$2, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
              trailing: Text(n.$5, style: scheme.textTheme.labelSmall),
              onTap: () => pulseSnack(context, 'Opened: ${n.$1}', icon: Icons.notifications_active_rounded),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        SecondaryButton(label: 'Notification Settings', icon: Icons.tune_rounded,
            onTap: () => Navigator.of(context).pushNamed('/notification-settings')),
        const SizedBox(height: PulseSpacing.s),
        Text('PULSE reminders are supportive by design — they tell you what\'s left, never what you "failed".',
            style: scheme.textTheme.bodySmall),
      ]),
    );
  }
}
