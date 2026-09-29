import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 09 — Workout Experience (§32–§38). Flow D:
/// Train → Library → Detail → Start → Exercise → Sets → Complete.
/// ═══════════════════════════════════════════════════════════════════

// ── §32 Train Home ─────────────────────────────────────────────────
class TrainScreen extends StatelessWidget {
  const TrainScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 120), children: [
        Row(children: [
          Expanded(child: Text('Ready to move, ${store.userFirstName}?', style: Theme.of(context).textTheme.headlineMedium)),
          IconButton3(icon: Icons.search_rounded, onTap: () => Navigator.of(context).pushNamed('/search')),
        ]),
        const SizedBox(height: PulseSpacing.l),
        // Today's workout hero — Card/WorkoutHero
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TODAY\'S WORKOUT', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 4),
            Text('Upper Body Strength', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: PulseSpacing.xs),
            const Row(children: [
              Icon(Icons.schedule_rounded, size: 16), SizedBox(width: 4), Text('45 min', style: TextStyle(fontSize: 15)),
              SizedBox(width: PulseSpacing.m),
              Icon(Icons.leaderboard_rounded, size: 16), SizedBox(width: 4), Text('Intermediate', style: TextStyle(fontSize: 15)),
              SizedBox(width: PulseSpacing.m),
              Icon(Icons.bolt_rounded, size: 16), SizedBox(width: 4), Text('8 exercises', style: TextStyle(fontSize: 15)),
            ]),
            const SizedBox(height: PulseSpacing.m),
            PrimaryButton(label: 'Start Workout', icon: Icons.play_arrow_rounded, onTap: () {
              store.track('workout_started');
              Navigator.of(context).pushNamed('/active-workout');
            }),
            const SizedBox(height: PulseSpacing.s),
            Center(child: Text('Planned for 6:30 PM · you can start any time', style: Theme.of(context).textTheme.labelSmall)),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Recommended for You', actionLabel: 'See all', onAction: () => Navigator.of(context).pushNamed('/workout-library')),
        SizedBox(
          height: 150,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final w in PulseData.workoutLibrary.take(4))
              Padding(
                padding: const EdgeInsets.only(right: PulseSpacing.s),
                child: _recCard(context, w),
              ),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Browse by type'),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: PulseSpacing.s, crossAxisSpacing: PulseSpacing.s, childAspectRatio: 2.1,
          children: [
            for (final c in const [('Quick Workouts', Icons.bolt_rounded, PulseColors.accent), ('Strength', Icons.fitness_center_rounded, PulseColors.exercise), ('Cardio', Icons.favorite_rounded, PulseColors.heart), ('Mobility', Icons.accessibility_new_rounded, PulseColors.steps), ('Yoga', Icons.self_improvement_rounded, PulseColors.sleep), ('HIIT', Icons.local_fire_department_rounded, PulseColors.warning)])
              _catTile(context, c.$1, c.$2, c.$3),
          ],
        ),
        const SizedBox(height: PulseSpacing.l),
        SecondaryButton(label: 'Workout History', icon: Icons.history_rounded, onTap: () => Navigator.of(context).pushNamed('/activity-detail')),
      ]),
    );
  }

  Widget _recCard(BuildContext c, ({String name, int minutes, String level, String category, int exercises, int kcal, List<String> equipment}) w) => SizedBox(
        width: 190,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(c).pushNamed('/workout-detail', arguments: w.name),
            child: Column(children: [
              Expanded(flex: 2,
                  child: Container(width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(colors: [PulseColors.primary.withOpacity(0.7), PulseColors.secondary.withOpacity(0.8)])),
                      child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.fitness_center_rounded, color: Colors.white54, size: 30)))),
              Expanded(flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(PulseSpacing.sm),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.name, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontSize: 14.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text('${w.minutes} min • ${w.level}', style: Theme.of(c).textTheme.labelSmall),
                    ]),
                  )),
            ]),
          ),
        ),
      );

  Widget _catTile(BuildContext c, String label, IconData icon, Color color) => Card(
        child: InkWell(borderRadius: BorderRadius.circular(PulseRadius.l),
            onTap: () => Navigator.of(c).pushNamed('/workout-library', arguments: label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.sm),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(PulseRadius.s)),
                    child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(c).colorScheme.onSurface))),
              ]),
            )),
      );
}

// ── §33 Workout Library with filters ───────────────────────────────
class WorkoutLibraryScreen extends StatefulWidget {
  const WorkoutLibraryScreen({super.key, this.initialCategory});
  final String? initialCategory;
  @override
  State<WorkoutLibraryScreen> createState() => _WorkoutLibraryScreenState();
}

class _WorkoutLibraryScreenState extends State<WorkoutLibraryScreen> {
  late String? category = widget.initialCategory;
  String difficulty = 'All';
  String duration = 'Any';
  String equipment = 'Any';

  List get _results => PulseData.workoutLibrary
      .where((w) => category == null || w.category == category)
      .where((w) => difficulty == 'All' || w.level == difficulty)
      .where((w) => duration == 'Any' || (duration == '< 20 min' ? w.minutes < 20 : duration == '20–40 min' ? w.minutes >= 20 && w.minutes <= 40 : w.minutes > 40))
      .where((w) => equipment == 'Any' || w.equipment.contains(equipment))
      .toList();

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Workout Library',
      subtitle: category ?? 'All workouts',
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.s),
          child: Row(children: [
            _filterChip(context, 'Difficulty: $difficulty', () => _pick(context, 'Filter by difficulty', ['All', 'Beginner', 'Intermediate', 'Advanced'], difficulty, (v) => setState(() => difficulty = v))),
            _filterChip(context, 'Duration: $duration', () => _pick(context, 'Filter by duration', ['Any', '< 20 min', '20–40 min', '> 40 min'], duration, (v) => setState(() => duration = v))),
            _filterChip(context, 'Equipment: $equipment', () => _pick(context, 'Filter by equipment', ['Any', 'None', 'Mat', 'Dumbbells', 'Barbell', 'Bench'], equipment, (v) => setState(() => equipment = v))),
            if (category != null)
              ActionChip(label: Text('Type: $category'), avatar: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => setState(() => category = null)),
          ]),
        ),
        Expanded(
          child: _results.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No workouts match those filters',
                  body: 'Try widening the duration or removing an equipment filter.',
                  actionLabel: 'Clear Filters',
                  onAction: () => setState(() { difficulty = 'All'; duration = 'Any'; equipment = 'Any'; }))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 100),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final w = _results[i] as ({String name, int minutes, String level, String category, int exercises, int kcal, List<String> equipment});
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: 6),
                        leading: CircleAvatar(
                            backgroundColor: _catColor(w.category).withOpacity(0.14),
                            child: Icon(_catIcon(w.category), color: _catColor(w.category), size: 20)),
                        title: Text(w.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text('${w.minutes} min • ${w.level} • ${w.exercises} exercises • ~${w.kcal} kcal'),
                        trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
                        onTap: () => Navigator.of(context).pushNamed('/workout-detail', arguments: w.name),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _filterChip(BuildContext c, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: PulseSpacing.s),
        child: ActionChip(label: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            avatar: const Icon(Icons.tune_rounded, size: 16), onPressed: onTap),
      );

  void _pick(BuildContext c, String title, List<String> options, String current, ValueChanged<String> onPick) {
    pulseSheet(c, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: title),
        for (final o in options)
          RadioListTile<String>(
              value: o, groupValue: current, title: Text(o),
              onChanged: (v) { Navigator.pop(ctx); onPick(v!); }),
      ]),
    ));
  }

  static Color _catColor(String cat) => switch (cat) {
        'Strength' => PulseColors.exercise,
        'Cardio' => PulseColors.heart,
        'HIIT' => PulseColors.warning,
        'Yoga' => PulseColors.sleep,
        'Mobility' => PulseColors.steps,
        _ => PulseColors.primary,
      };
  static IconData _catIcon(String cat) => switch (cat) {
        'Strength' => Icons.fitness_center_rounded,
        'Cardio' => Icons.favorite_rounded,
        'HIIT' => Icons.local_fire_department_rounded,
        'Yoga' => Icons.self_improvement_rounded,
        'Mobility' => Icons.accessibility_new_rounded,
        _ => Icons.bolt_rounded,
      };
}

// ── §34 Workout Detail ─────────────────────────────────────────────
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workoutName});
  final String workoutName;
  @override
  Widget build(BuildContext context) {
    final w = PulseData.workoutLibrary.firstWhere((x) => x.name == workoutName, orElse: () => PulseData.workoutLibrary[0]);
    final store = context.pulse;
    return PulseScaffold(
      title: 'Workout',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        Text(w.name, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: PulseSpacing.s),
        Wrap(spacing: PulseSpacing.m, children: [
          _meta(context, Icons.schedule_rounded, '${w.minutes} min'),
          _meta(context, Icons.leaderboard_rounded, w.level),
          _meta(context, Icons.bolt_rounded, 'Estimated ${w.kcal} kcal'),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Equipment'),
        Wrap(spacing: PulseSpacing.s, children: [for (final e in w.equipment) Chip(label: Text(e, style: const TextStyle(fontSize: 14)))]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: '${w.exercises} exercises'),
        for (var i = 0; i < PulseData.upperBodyExercises.length && i < w.exercises; i++)
          Card(
            margin: const EdgeInsets.only(bottom: PulseSpacing.s),
            child: ListTile(
              leading: CircleAvatar(radius: 15, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  child: Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary))),
              title: Text(PulseData.upperBodyExercises[i].name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text('${PulseData.upperBodyExercises[i].sets} · ${PulseData.upperBodyExercises[i].muscle}'),
              trailing: IconButton3(icon: Icons.info_outline_rounded, size: 38,
                  onTap: () => Navigator.of(context).pushNamed('/exercise-instructions', arguments: PulseData.upperBodyExercises[i].name)),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        PrimaryButton(label: 'Start Workout', icon: Icons.play_arrow_rounded, onTap: () {
          store.track('workout_started');
          Navigator.of(context).pushReplacementNamed('/active-workout');
        }),
        const SizedBox(height: PulseSpacing.s),
        SecondaryButton(label: 'Add to Tomorrow\'s Plan', icon: Icons.event_available_rounded,
            onTap: () => pulseSnack(context, 'Scheduled for Wednesday. We\'ll remind you at your usual time.')),
      ]),
    );
  }

  Widget _meta(BuildContext c, IconData i, String t) => Row(children: [
        Icon(i, size: 17, color: Theme.of(c).colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 4),
        Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(c).colorScheme.onSurface)),
      ]);
}

// ── §35 Active Workout — sets, rest timer, navigation ──────────────
class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});
  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> with SingleTickerProviderStateMixin {
  int _exerciseIndex = 0;
  int _set = 2; // Set 2 of 4 per brief
  static const _totalSets = 4;
  final Map<int, ({int reps, double weight})> _last = {
    0: (reps: 10, weight: 20),
  };
  int _reps = 10;
  double _weightKg = 20;
  bool _resting = false;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  Timer? _restTimer;
  int _restLeft = 90;
  final List<MapEntry<String, int>> _completedSets = [];

  Duration get _elapsed => const Duration(minutes: 12) + Duration(seconds: _tick.elapsed.inSeconds.remainder(3600));
  static final Stopwatch _tick = Stopwatch()..start();

  void _completeSet() {
    HapticFeedback.mediumImpact();
    final ex = PulseData.upperBodyExercises[_exerciseIndex];
    _completedSets.add(MapEntry(ex.name, _reps));
    if (_set < _totalSets) {
      setState(() { _set++; _resting = true; _restLeft = 90; });
      _restTimer?.cancel();
      _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() {
          if (_restLeft > 0) { _restLeft--; } else { _resting = false; t.cancel(); }
        });
      });
    } else {
      _nextExercise();
    }
  }

  void _nextExercise() {
    _restTimer?.cancel();
    setState(() {
      _exerciseIndex = (_exerciseIndex + 1) % PulseData.upperBodyExercises.length;
      _set = 1;
      _resting = false;
      _last.putIfAbsent(_exerciseIndex, () => (reps: 10, weight: 20));
    });
  }

  @override
  void dispose() { _restTimer?.cancel(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = PulseData.upperBodyExercises[_exerciseIndex];
    final prev = _last[_exerciseIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Upper Body Strength · $_elapsed'.replaceAll('0:12', '12'), style: const TextStyle(fontSize: 16)),
        leading: IconButton(
            tooltip: 'End workout',
            icon: const Icon(Icons.stop_rounded),
            onPressed: () async {
              final ok = await pulseConfirm(context,
                  title: 'End workout early?',
                  body: 'We\'ll save the ${_completedSets.length} completed sets so far. Nothing is lost.',
                  confirmLabel: 'End & Save');
              if (ok && context.mounted) Navigator.of(context).pushReplacementNamed('/workout-complete');
            }),
        actions: [
          IconButton3(icon: Icons.more_vert_rounded, onTap: () => pulseSheet(context, builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SheetHeader(title: 'Workout menu'),
              ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: const Text('Replace Exercise'), onTap: () { Navigator.pop(ctx); pulseSnack(context, 'Replacement picker opens the exercise library.'); }),
              ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('View Instructions'), onTap: () { Navigator.pop(ctx); Navigator.of(context).pushNamed('/exercise-instructions', arguments: ex.name); }),
              ListTile(leading: const Icon(Icons.stop_circle_outlined), title: const Text('End Workout', style: TextStyle(color: PulseColors.error)),
                  onTap: () { Navigator.pop(ctx); Navigator.of(context).pushReplacementNamed('/workout-complete'); }),
            ]),
          ))),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Large visible exercise
            Text('Set $_set of $_totalSets', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(ex.name, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: PulseSpacing.xs),
            Text('${ex.muscle} · ${ex.sets}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: PulseSpacing.l),
            if (prev != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.sm),
                decoration: BoxDecoration(color: scheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(PulseRadius.m)),
                child: Text('Previous: ${prev.reps} × ${prev.weight.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.primary)),
              ),
            const SizedBox(height: PulseSpacing.l),
            // Inputs
            Row(children: [
              Expanded(
                child: PulseCard(
                  child: Column(children: [
                    Text('Reps', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: PulseSpacing.s),
                    PulseStepper(value: _reps.toDouble(), min: 1, max: 50, unit: '', onChanged: (v) => setState(() => _reps = v.round())),
                  ]),
                ),
              ),
              const SizedBox(width: PulseSpacing.s),
              Expanded(
                child: PulseCard(
                  child: Column(children: [
                    Text('Weight (kg)', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: PulseSpacing.s),
                    PulseStepper(value: _weightKg, min: 2.5, max: 60, step: 2.5, unit: 'kg', onChanged: (v) => setState(() => _weightKg = v)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: PulseSpacing.m),
            PrimaryButton(label: 'Complete Set', icon: Icons.check_rounded, onTap: _completeSet),
            const SizedBox(height: PulseSpacing.l),
            // Rest timer card
            AnimatedSwitcher(
              duration: PulseDuration.fast,
              child: _resting
                  ? PulseCard(
                      key: const ValueKey('rest'),
                      padding: const EdgeInsets.all(PulseSpacing.l),
                      child: Row(children: [
                        ScaleTransition(scale: Tween(begin: 0.95, end: 1.05).animate(_pulse),
                            child: const Icon(Icons.timer_rounded, color: PulseColors.accent, size: 34)),
                        const SizedBox(width: PulseSpacing.m),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Rest', style: Theme.of(context).textTheme.labelMedium),
                          Text('${(_restLeft ~/ 60).toString().padLeft(2, '0')}:${(_restLeft % 60).toString().padLeft(2, '0')}',
                              style: PulseTypography.metricMedium.copyWith(color: scheme.onSurface)),
                        ])),
                        TextButton(onPressed: () => setState(() { _resting = false; _restTimer?.cancel(); }), child: const Text('Skip')),
                      ]),
                    )
                  : PulseCard(
                      key: const ValueKey('nav'),
                      child: Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _exerciseIndex = (_exerciseIndex - 1) % PulseData.upperBodyExercises.length),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Previous'))),
                        const SizedBox(width: PulseSpacing.s),
                        Expanded(child: FilledButton.tonalIcon(onPressed: _nextExercise,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Next Exercise'))),
                      ]),
                    ),
            ),
            const SizedBox(height: PulseSpacing.l),
            Text('Completed: ${_completedSets.map((e) => '${e.value}×').join(' ')}',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

// ── §36 Exercise Instructions ──────────────────────────────────────
class ExerciseInstructionsScreen extends StatelessWidget {
  const ExerciseInstructionsScreen({super.key, required this.exerciseName});
  final String exerciseName;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: exerciseName,
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        // Animation placeholder (loop icon frame)
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.xl),
          child: Column(children: [
            Container(width: double.infinity, height: 160,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.m)),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(Icons.animation_rounded, size: 56, color: scheme.primary.withOpacity(0.6)),
                  Positioned(bottom: 8, right: 12, child: Text('Animation loop', style: Theme.of(context).textTheme.labelSmall)),
                ])),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Muscles'),
        Wrap(spacing: PulseSpacing.s, children: [
          for (final m in const [('Chest', true), ('Triceps', true), ('Shoulders', false)])
            Chip(label: Text(m.$1), avatar: Icon(m.$1 == 'Chest' ? Icons.person_rounded : Icons.trending_up_rounded, size: 16, color: m.$2 ? PulseColors.protein : scheme.onSurface.withOpacity(0.5)),
                backgroundColor: m.$2 ? PulseColors.protein.withOpacity(0.1) : null),
        ]),
        const SizedBox(height: PulseSpacing.l),
        for (final sec in const [
          ('How to perform', ['Sit back between the dumbbells, feet flat and braced.', 'Press the dumbbells up until your arms are nearly straight.', 'Lower slowly over 2–3 seconds to chest level.', 'Keep elbows at roughly 45° from your torso.']),
          ('Common mistakes', ['Flaring elbows straight out to the sides.', 'Bouncing the weight off the chest.', 'Lifting hips off the bench under load.']),
          ('Tips', ['Breathe out on the press, in on the way down.', 'Stop one or two reps short of failure while learning the pattern.', 'Log every set — PULSE uses it to suggest sensible progress.']),
        ]) ...[
          SectionHeader(title: sec.$1),
          PulseCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final b in sec.$2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6),
                        child: Icon(sec.$1 == 'Common mistakes' ? Icons.remove_rounded : Icons.circle_rounded, size: 7, color: sec.$1 == 'Common mistakes' ? PulseColors.error : scheme.primary)),
                    const SizedBox(width: PulseSpacing.sm),
                    Expanded(child: Text(b, style: Theme.of(context).textTheme.bodyMedium)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: PulseSpacing.m),
        ],
        const HealthDisclaimer(),
      ]),
    );
  }
}

// ── §37 Workout Complete ───────────────────────────────────────────
class WorkoutCompleteScreen extends StatefulWidget {
  const WorkoutCompleteScreen({super.key});
  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  int? _rating; // 0 easy 1 just right 2 hard

  @override
  Widget build(BuildContext context) {
    final store = context.pulse;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PulseSpacing.xl),
          child: Column(children: [
            const SizedBox(height: PulseSpacing.xxl),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: PulseDuration.slow,
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(scale: v,
                  child: const PulseRing(value: 1, color: PulseColors.success, size: 110, stroke: 10,
                      child: Icon(Icons.check_rounded, size: 52, color: PulseColors.success))),
            ),
            const SizedBox(height: PulseSpacing.l),
            Text('Workout Complete', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
            Text('Upper Body Strength · Tuesday evening', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: PulseSpacing.xl),
            PulseCard(
              padding: const EdgeInsets.all(PulseSpacing.l),
              child: Row(children: [
                _stat(context, 'Duration', '42 min'),
                _stat(context, 'Exercises', '8'),
                _stat(context, 'Sets', '24'),
              ]),
            ),
            const SizedBox(height: PulseSpacing.s),
            PulseCard(
              child: Row(children: [
                _stat(context, 'Volume', '8,640 kg'),
                _stat(context, 'Est. Calories', '276'),
                _stat(context, 'Avg HR', '131 bpm'),
              ]),
            ),
            const SizedBox(height: PulseSpacing.l),
            Text('Rate this workout', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: PulseSpacing.s),
            Row(children: [
              for (final (i, l) in const ['Too Easy', 'Just Right', 'Too Hard'].indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : PulseSpacing.s),
                    child: ChoiceChip(label: Text(l, style: const TextStyle(fontSize: 13.5)), selected: _rating == i, onSelected: (_) => setState(() => _rating = i)),
                  ),
                ),
            ]),
            const SizedBox(height: PulseSpacing.xl),
            PrimaryButton(label: 'Done', onTap: () {
              store.track('workout_completed');
              store.activityCaloriesBurned += 276;
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
              pulseSnack(context, 'Workout saved', icon: Icons.check_circle_rounded);
            }),
            const SizedBox(height: PulseSpacing.s),
            SecondaryButton(label: 'Share Workout', icon: Icons.ios_share_rounded,
                onTap: () => pulseSnack(context, 'Share sheet opened — image includes only what you chose to show.')),
          ]),
        ),
      ),
    );
  }

  Widget _stat(BuildContext c, String l, String v) => Expanded(
      child: Column(children: [
        Text(v, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
        Text(l, style: Theme.of(c).textTheme.labelSmall),
      ]));
}

// ── §38 Cardio Activity detail + Log Exercise ──────────────────────
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Activity',
      subtitle: 'Recent cardio & steps',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        // Morning run summary card
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.directions_run_rounded, color: PulseColors.caloriesBurned),
              const SizedBox(width: PulseSpacing.s),
              Expanded(child: Text('Morning Run', style: Theme.of(context).textTheme.titleLarge)),
              Text('Today · 6:40 AM', style: Theme.of(context).textTheme.labelMedium),
            ]),
            const SizedBox(height: PulseSpacing.m),
            // Route map placeholder (shown only because GPS was enabled)
            Container(height: 130, width: double.infinity,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.m)),
                child: Stack(children: [
                  CustomPaint(size: Size.infinite, painter: _RoutePainter(scheme.primary)),
                  Positioned(left: 10, bottom: 8, child: Text('Route shown because Location was allowed for tracking', style: Theme.of(context).textTheme.labelSmall)),
                ])),
            const SizedBox(height: PulseSpacing.m),
            Row(children: [
              _stat(context, 'Distance', '5.26 km'),
              _stat(context, 'Duration', '31:42'),
              _stat(context, 'Avg Pace', '6:01 / km'),
            ]),
            const SizedBox(height: PulseSpacing.m),
            Row(children: [
              _stat(context, 'Calories', '428'),
              _stat(context, 'Heart Rate', '146 bpm'),
              _stat(context, 'Elevations', '+38 m'),
            ]),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'History'),
        for (final a in const [('Running', 'Mon · 6.1 km · 38:04'), ('Cycling', 'Sat · 21.4 km · 58:12'), ('Walking', 'Fri · 4.2 km · 42:30'), ('Strength', 'Wed · Upper Body · 41 min')])
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: PulseColors.caloriesBurned.withOpacity(0.12),
                  child: Icon(a.$1 == 'Strength' ? Icons.fitness_center_rounded : a.$1 == 'Cycling' ? Icons.two_wheeler_rounded : a.$1 == 'Running' ? Icons.directions_run_rounded : Icons.directions_walk_rounded,
                      size: 20, color: PulseColors.caloriesBurned)),
              title: Text(a.$1, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(a.$2),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.35)),
              onTap: () => pulseSnack(context, 'Open activity summary for ${a.$2.split(' · ').first}.', icon: Icons.timeline_rounded),
            ),
          ),
        SecondaryButton(label: 'Add Manual Cardio Activity', icon: Icons.add_rounded,
            onTap: () => Navigator.of(context).pushNamed('/log-exercise')),
      ]),
    );
  }

  Widget _stat(BuildContext c, String l, String v) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
        Text(l, style: Theme.of(c).textTheme.labelSmall),
      ]));
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.2, size.width * 0.45, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.6, size.width * 0.72, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.74, size.height * 0.05, size.width * 0.88, size.height * 0.3);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.8), 6, Paint()..color = PulseColors.success);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.3), 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Log Exercise quick screen ──────────────────────────────────────
class LogExerciseScreen extends StatefulWidget {
  const LogExerciseScreen({super.key});
  @override
  State<LogExerciseScreen> createState() => _LogExerciseScreenState();
}

class _LogExerciseScreenState extends State<LogExerciseScreen> {
  String _type = 'Running';
  final _minutes = TextEditingController(text: '30');
  final _distance = TextEditingController(text: '5.0');

  @override
  void dispose() { _minutes.dispose(); _distance.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.pulse;
    final minsOk = int.tryParse(_minutes.text) != null && int.parse(_minutes.text) > 0;
    return PulseScaffold(
      title: 'Log Exercise',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
          for (final t in const ['Walking', 'Running', 'Cycling', 'Swimming', 'Hiking', 'Rowing', 'Elliptical'])
            ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
        ]),
        const SizedBox(height: PulseSpacing.l),
        TextField(controller: _minutes, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Duration', suffixText: 'min',
                errorText: !minsOk && _minutes.text.isNotEmpty ? 'Enter a valid duration' : null),
            onChanged: (_) => setState(() {})),
        const SizedBox(height: PulseSpacing.m),
        if (_type != 'Strength')
          TextField(controller: _distance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Distance', suffixText: store.unitsDistance == 'km' ? 'km' : 'mi')),
        const SizedBox(height: PulseSpacing.l),
        PrimaryButton(label: 'Save Activity', icon: Icons.check_rounded, onTap: minsOk ? () {
          final kcal = (int.tryParse(_minutes.text) ?? 30) * 9.5;
          store.activityCaloriesBurned += kcal;
          store.track('exercise_logged');
          Navigator.pop(context);
          pulseSnack(context, 'Added to Diary · ${kcal.toStringAsFixed(0)} kcal burned credited', undoLabel: 'Undo',
              onUndo: () => store.activityCaloriesBurned -= kcal);
        } : null),
      ]),
    );
  }
}

// ── §39 Steps full screen ──────────────────────────────────────────
class StepsScreen extends StatelessWidget {
  const StepsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = PulseStore.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pct = s.stepsToday / s.goals.stepGoal;
    return PulseScaffold(
      title: 'Steps',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Row(children: [
            PulseRing(value: pct, color: PulseColors.steps, size: 110, stroke: 12,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(pct * 100).round()}%', style: PulseTypography.metricSmall.copyWith(color: scheme.onSurface)),
                ])),
            const SizedBox(width: PulseSpacing.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.stepsToday.toStringAsFixed(0)} / ${s.goals.stepGoal}', style: PulseTypography.metricMedium.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text('Distance ${(s.stepsToday * 0.000715).toStringAsFixed(1)} km', style: Theme.of(context).textTheme.bodyMedium),
                Text('Estimated activity calories 246', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: PulseSpacing.s),
                Text('A 10-minute walk would put you close to today\'s step target.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.primary)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Last 7 days'),
        PulseCard(
          child: Column(children: [
            PulseBarChart(values: const [5760, 7600, 4880, 8000, 7040, 3600, 6842], labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'], goal: 8000, highlightIndex: 6),
            const SizedBox(height: PulseSpacing.s),
            Row(children: [for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.labelSmall))) ]),
            const SizedBox(height: PulseSpacing.xs),
            Text('Red line marks your 8,000-step daily goal. Bars show each day against it.',
                style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Source'),
        ListTile(
          leading: CircleAvatar(backgroundColor: PulseColors.success.withOpacity(0.14), child: const Icon(Icons.health_and_safety_rounded, color: PulseColors.success, size: 20)),
          title: const Text('Apple Health'),
          subtitle: const Text('Synced 4 minutes ago · steps counted from iPhone + Watch'),
        ),
      ]),
    );
  }
}

// ── §40 Habits customization ───────────────────────────────────────
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});
  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final List<dynamic> _habits = [...PulseData.habits];

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Healthy Habits',
      subtitle: 'Toggle what you want PULSE to track for you',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (var i = 0; i < _habits.length; i++)
          Card(
            child: SwitchListTile(
              value: _habits[i].on,
              onChanged: (v) => setState(() => _habits[i] = (name: _habits[i].name, icon: _habits[i].icon, color: _habits[i].color, progress: _habits[i].progress, on: v)),
              secondary: Icon(_habits[i].icon, color: _habits[i].color),
              title: Text(_habits[i].name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(_habits[i].progress),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        const Text('Habits appear on your Today dashboard. Turning one off never deletes history.',
            style: TextStyle(fontSize: 14)),
      ]),
    );
  }
}
