import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../data/energy_plan.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 03 — Personalized Onboarding (§14/§15). Premium multi-step
/// flow with visible progress. Flow A: Goals → Motivation → Details →
/// Weight Target → Activity → Frequency → Exercise types → Diet →
/// Plan → Permissions → Dashboard.
/// ═══════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.step});
  final int step; // 0..10 (10 = permissions)
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int _step = widget.step;
  final Set<String> goals = {'Lose weight', 'Eat healthier'};
  final Set<String> motivations = {'Better nutrition', 'More energy'};
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _weightFocus = FocusNode();
  String _sex = 'Male';
  double _targetWeight = 70;
  int _pace = 1; // Recommended
  int _activity = 2;
  int _exerciseFreq = 2;
  final Set<String> exerciseTypes = {'Walking', 'Gym', 'Strength training'};
  String _diet = 'No preference';

  static const _steps = 9;

  void _next() {
    HapticFeedback.lightImpact();
    _releaseFocus();
    if (_step == 8) {
      _commitProfile();
      context.pulse.track('onboarding_completed');
    }
    setState(() => _step = (_step + 1).clamp(0, _steps));
    if (_step == _steps) context.pulse.track('permissions_step_reached');
  }

  void _back() {
    _releaseFocus();
    setState(() => _step = (_step - 1).clamp(0, _steps));
  }

  /// Hands focus back to the platform before the step subtree is replaced.
  void _releaseFocus() {
    for (final f in [_nameFocus, _ageFocus, _heightFocus, _weightFocus]) {
      f.unfocus();
    }
  }

  void _commitProfile() {
    final store = context.pulse;
    final weight = double.tryParse(_weight.text);
    store.setProfile(
      name: _name.text,
      age: int.tryParse(_age.text),
      heightCm: double.tryParse(_height.text),
      startWeightKg: weight,
    );
    // N3: setTargets could only ever write calories and protein — there
    // were no carb or fat parameters — so the store's defaults survived
    // onboarding and the comment above them claiming otherwise was false.
    // updateGoals is the only path that writes all of them.
    final plan = _plan;
    store.updateGoals((g) {
      g.calorieGoal = plan.calorieGoal;
      g.proteinGoal = plan.proteinGoal;
      g.carbGoal = plan.carbGoal;
      g.fatGoal = plan.fatGoal;
      g.waterGoalLiters = plan.waterGoalLiters;
      g.stepGoal = plan.stepGoal;
      g.targetWeightKg = _targetWeight;
    });
    // First weigh-in: seeds the trend from the user's own entry.
    if (weight != null) store.logWeight(weight);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_step >= _steps) return _PermissionsFlow(onFinish: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Progress header — StepIndicator/Onboarding
          Padding(
            padding: const EdgeInsets.fromLTRB(PulseSpacing.l, PulseSpacing.m, PulseSpacing.l, 0),
            child: Row(children: [
              IconButton3(icon: Icons.close_rounded, onTap: _step == 0 ? () => Navigator.of(context).pop() : _back),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PulseRadius.full),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: _step / _steps, end: (_step + 1) / _steps),
                    duration: PulseDuration.normal,
                    builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                  ),
                ),
              ),
              const SizedBox(width: PulseSpacing.sm),
              Text('Step ${_step + 1} of $_steps', style: Theme.of(context).textTheme.labelMedium),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('onboarding_step_$_step'),
              padding: const EdgeInsets.all(PulseSpacing.xl),
              child: _body(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(PulseSpacing.xl, 0, PulseSpacing.xl, PulseSpacing.l),
            child: PrimaryButton(label: _step == 8 ? 'Start My Plan' : 'Continue', onTap: _next),
          ),
        ]),
      ),
    );
  }

  Widget _body(BuildContext context) => switch (_step) {
        0 => _goalsPage(context),
        1 => _motivationPage(context),
        2 => _detailsPage(context),
        3 => _targetPage(context),
        4 => _activityPage(context),
        5 => _frequencyPage(context),
        6 => _exercisePage(context),
        7 => _dietPage(context),
        _ => _planPage(context),
      };

  Widget _heading(BuildContext c, String title, [String? sub]) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(c).textTheme.displaySmall),
        if (sub != null) ...[const SizedBox(height: PulseSpacing.s), Text(sub, style: Theme.of(c).textTheme.bodySmall)],
        const SizedBox(height: PulseSpacing.xl),
      ]);

  Widget _goalsPage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'What would you like to achieve?', 'Pick as many as apply — your plan adapts to all of them.'),
        for (final g in const [('Lose weight', Icons.trending_down_rounded), ('Maintain weight', Icons.balance_rounded), ('Gain weight', Icons.arrow_upward_rounded), ('Build muscle', Icons.fitness_center_rounded), ('Improve fitness', Icons.favorite_rounded), ('Eat healthier', Icons.restaurant_rounded), ('Increase daily activity', Icons.directions_walk_rounded)])
          OptionTile(
              title: g.$1, icon: g.$2, selected: goals.contains(g.$1),
              onTap: () => setState(() => goals.contains(g.$1) ? goals.remove(g.$1) : goals.add(g.$1))),
      ]);

  Widget _motivationPage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'What matters most to you?', 'This shapes how PULSE encourages you — never how it judges you.'),
        for (final m in const ['Better nutrition', 'More energy', 'Looking better', 'Feeling stronger', 'Better fitness', 'Building healthy habits', 'Managing my weight'])
          OptionTile(title: m, selected: motivations.contains(m),
              onTap: () => setState(() => motivations.contains(m) ? motivations.remove(m) : motivations.add(m))),
      ]);

  Widget _detailsPage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'Tell us about yourself',
            'We use age, sex, height and weight only to estimate your metabolic needs. You can change or delete this anytime in Profile → Privacy.'),
        TextField(controller: _name, focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _ageFocus.requestFocus(),
          decoration: const InputDecoration(labelText: 'Your name', hintText: 'What should we call you?')),
        const SizedBox(height: PulseSpacing.m),
        TextField(controller: _age, focusNode: _ageFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _heightFocus.requestFocus(),
          decoration: const InputDecoration(labelText: 'Age', suffixText: 'years')),
        const SizedBox(height: PulseSpacing.m),
        Text('Biological sex for metabolic calculations', style: Theme.of(c).textTheme.titleMedium),
        const SizedBox(height: PulseSpacing.s),
        PulseSegmented(options: const ['Male', 'Female'], index: _sex == 'Male' ? 0 : 1, onChanged: (i) => setState(() => _sex = i == 0 ? 'Male' : 'Female')),
        const SizedBox(height: PulseSpacing.m),
        TextField(controller: _height, focusNode: _heightFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _weightFocus.requestFocus(),
          decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm')),
        const SizedBox(height: PulseSpacing.m),
        TextField(controller: _weight, focusNode: _weightFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _releaseFocus(),
          // Redraw so the validity hint tracks what has been typed.
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText: 'Current weight', suffixText: 'kg',
              errorText: double.tryParse(_weight.text) == null && _weight.text.isNotEmpty ? 'Enter a valid weight' : null)),
      ]);

  Widget _targetPage(BuildContext c) {
    final current = double.tryParse(_weight.text) ?? 0;
    final diff = current - _targetWeight;
    final weeks = (diff / (0.25 + _pace * 0.35)).ceil();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(c, 'What\'s your target?'),
      PulseCard(child: Row(children: [
        Expanded(child: MetricStat(label: 'Current weight', value: '${current.toStringAsFixed(1)} kg')),
        Icon(Icons.arrow_forward_rounded, color: Theme.of(c).colorScheme.primary),
        Expanded(child: MetricStat(label: 'Target weight', value: '${_targetWeight.toStringAsFixed(1)} kg')),
      ])),
      const SizedBox(height: PulseSpacing.l),
      Text('Target weight', style: Theme.of(c).textTheme.titleMedium),
      Slider(value: _targetWeight, min: 55, max: 100, divisions: 90, label: '${_targetWeight.toStringAsFixed(1)} kg',
          onChanged: (v) => setState(() => _targetWeight = (v * 2).roundToDouble() / 2)),
      const SizedBox(height: PulseSpacing.s),
      Text('Desired pace', style: Theme.of(c).textTheme.titleMedium),
      const SizedBox(height: PulseSpacing.s),
      for (var i = 0; i < 3; i++)
        OptionTile(
            title: const ['Slow & steady', 'Recommended', 'Faster'][i],
            subtitle: const ['≈ 0.25 kg/week · gentlest on energy levels', '≈ 0.5 kg/week · sustainable for most people', '≈ 0.7 kg/week · only sensible short-term'][i],
            selected: _pace == i,
            onTap: () => setState(() => _pace = i)),
      const SizedBox(height: PulseSpacing.m),
      Container(
        padding: const EdgeInsets.all(PulseSpacing.m),
        decoration: BoxDecoration(color: Theme.of(c).colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(PulseRadius.m)),
        child: Row(children: [
          Icon(Icons.bolt_rounded, color: Theme.of(c).colorScheme.primary, size: 20),
          const SizedBox(width: PulseSpacing.s),
          Expanded(child: Text(
              diff <= 0
                  ? 'A maintenance or gain target — we\'ll set calories accordingly.'
                  : 'At this pace you\'d reach ${_targetWeight.toStringAsFixed(1)} kg in about $weeks weeks. We recommend the “Recommended” pace — faster loss often costs muscle and energy.',
              style: TextStyle(fontSize: 14.5, color: Theme.of(c).colorScheme.onSurface, height: 1.4))),
        ]),
      ),
    ]);
  }

  Widget _activityPage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'How active are you normally?', 'Think about a typical week — work, commuting, standing.'),
        for (var i = 0; i < 4; i++)
          OptionTile(
              title: const ['Sedentary', 'Lightly active', 'Active', 'Very active'][i],
              subtitle: const ['Mostly sitting, little deliberate movement', 'Some walking or standing through the day', 'On my feet often, or regular exercise', 'Physical job or daily intense training'][i],
              selected: _activity == i, onTap: () => setState(() => _activity = i)),
      ]);

  Widget _frequencyPage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'How often do you exercise?'),
        for (var i = 0; i < 5; i++)
          OptionTile(
              title: const ['Never', '1–2 days/week', '3–4 days/week', '5–6 days/week', 'Daily'][i],
              selected: _exerciseFreq == i, onTap: () => setState(() => _exerciseFreq = i)),
      ]);

  Widget _exercisePage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'What kind of exercise do you enjoy?', 'Choose everything you\'d genuinely look forward to — recommendations follow your picks.'),
        Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
          for (final e in const ['Walking', 'Running', 'Gym', 'Strength training', 'Cycling', 'Yoga', 'Swimming', 'HIIT', 'Sports', 'Home workouts'])
            FilterChip(
                label: Text(e),
                selected: exerciseTypes.contains(e),
                onSelected: (v) => setState(() => v ? exerciseTypes.add(e) : exerciseTypes.remove(e)),
                showCheckmark: true),
        ]),
      ]);

  Widget _dietPage(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(c, 'How do you usually eat?', 'You can add allergies and detailed preferences later in Profile → Nutrition.'),
        for (final d in const ['No preference', 'Vegetarian', 'Vegan', 'High protein', 'Low carb', 'Keto', 'Mediterranean', 'Pescatarian'])
          OptionTile(title: d, selected: _diet == d, onTap: () => setState(() => _diet = d)),
      ]);

  /// N3: the plan page used to show 2,050 kcal and its macros as literals
  /// while claiming "Built from your answers". Both the page and the
  /// commit now read this, so what the user is shown is what is stored.
  PulseEnergyPlan get _plan => PulseEnergyPlan.from(
        sex: _sex == 'Male' ? BiologicalSex.male : BiologicalSex.female,
        ageYears: int.tryParse(_age.text) ?? 30,
        heightCm: double.tryParse(_height.text) ?? 170,
        weightKg: double.tryParse(_weight.text) ?? 70,
        activity: ActivityLevel.values[_activity.clamp(0, 3)],
        pace: WeightPace.values[_pace.clamp(0, 2)],
        targetWeightKg: _targetWeight,
      );

  Widget _planPage(BuildContext c) {
    final plan = _plan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(c, 'Your daily plan is ready',
          'Built from your answers — ${goals.join(", ").toLowerCase()}. Every number below stays editable in My Goals.'),
      PulseCard(
        padding: const EdgeInsets.all(PulseSpacing.l),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Daily Calories', style: Theme.of(c).textTheme.titleMedium),
            Text('${plan.calorieGoal.toStringAsFixed(0)} kcal', style: PulseTypography.metricMedium.copyWith(color: Theme.of(c).colorScheme.primary)),
          ]),
          const Divider(height: PulseSpacing.xl),
          for (final m in [
            ('Protein', '${plan.proteinGoal.toStringAsFixed(0)} g', PulseColors.protein, Icons.bolt_rounded),
            ('Carbs', '${plan.carbGoal.toStringAsFixed(0)} g', PulseColors.carbs, Icons.grain_rounded),
            ('Fat', '${plan.fatGoal.toStringAsFixed(0)} g', PulseColors.fat, Icons.water_drop_rounded),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
              child: Row(children: [
                Icon(m.$4, size: 18, color: m.$3), const SizedBox(width: PulseSpacing.s),
                Expanded(child: Text('${m.$1} ', style: Theme.of(c).textTheme.bodyLarge)),
                Text(m.$2, style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
              ]),
            ),
          const Divider(height: PulseSpacing.xl),
          Row(children: [
            const Icon(Icons.water_drop_rounded, size: 18, color: PulseColors.water),
            const SizedBox(width: PulseSpacing.s),
            Expanded(child: Text('Water', style: Theme.of(c).textTheme.bodyLarge)),
            Text('${plan.waterGoalLiters.toStringAsFixed(1)} L', style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
          ]),
          const SizedBox(height: PulseSpacing.sm),
          Row(children: [
            const Icon(Icons.directions_walk_rounded, size: 18, color: PulseColors.steps),
            const SizedBox(width: PulseSpacing.s),
            Expanded(child: Text('Steps', style: Theme.of(c).textTheme.bodyLarge)),
            Text('${plan.stepGoal}', style: PulseTypography.metricSmall.copyWith(color: Theme.of(c).colorScheme.onSurface)),
          ]),
        ]),
      ),
      // The pace the user picked could not be met safely, so say so
      // rather than showing a capped number as if it were what they chose.
      if (plan.floorNote != null) ...[
        const SizedBox(height: PulseSpacing.m),
        Container(
          padding: const EdgeInsets.all(PulseSpacing.m),
          decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(PulseRadius.m)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(c).colorScheme.primary),
            const SizedBox(width: PulseSpacing.s),
            Expanded(child: Text(plan.floorNote!, style: Theme.of(c).textTheme.bodySmall?.copyWith(fontSize: 13.5, height: 1.45))),
          ]),
        ),
      ],
      const SizedBox(height: PulseSpacing.l),
      SecondaryButton(label: 'Adjust Goals', icon: Icons.tune_rounded, onTap: () => Navigator.of(c).pushNamed('/goals')),
      const SizedBox(height: PulseSpacing.s),
      const HealthDisclaimer(),
      TertiaryButton(label: 'Why these numbers?', onTap: () => showDialog(context: c, builder: (_) => AlertDialog(
        title: const Text('How PULSE calculated your plan'),
        content: const Text(
            'We estimated your daily energy needs from age, sex, height, weight and activity level, then adjusted for your goal and pace. Protein was set to support muscle during weight change. These are starting estimates — your real trend over 2–3 weeks matters more than any single number.',
            style: TextStyle(height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Got it'))],
      ))),
    ]);
  }
}

// ── §15 Permissions — requested contextually, one at a time ────────
class _PermissionsFlow extends StatelessWidget {
  const _PermissionsFlow({required this.onFinish});
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(PulseSpacing.xl), children: [
          Text('Connect what matters', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: PulseSpacing.s),
          Text('Enable only what helps you. Each permission can be changed or revoked anytime in Settings.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: PulseSpacing.xl),
          _perm(context, Icons.health_and_safety_rounded, PulseColors.success, 'Connect your health data',
              'Automatically bring your steps, workouts and other activity into PULSE.', 'Connect Apple Health', 'Connect Health Connect'),
          _perm(context, Icons.notifications_rounded, PulseColors.info, 'Daily reminders',
              'Water nudges and workout reminders — encouraging, never guilt-based. You choose every time.', 'Enable Notifications'),
          _perm(context, Icons.photo_camera_rounded, PulseColors.accent, 'Camera',
              'Only used when you scan a barcode or photograph a meal. Photos aren\'t stored unless you log them.', 'Allow Camera'),
          _perm(context, Icons.location_on_rounded, PulseColors.fat, 'Location (optional)',
              'Used only for mapping outdoor runs and rides while tracking. Never tracked in the background.', 'Allow While Using App'),
          const SizedBox(height: PulseSpacing.l),
          PrimaryButton(label: 'Done — take me to my dashboard', onTap: onFinish),
          const SizedBox(height: PulseSpacing.s),
          Center(child: TextButton(onPressed: onFinish, child: const Text('Maybe Later'))),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.06),
          Center(child: Text('Skip anything — the app works fully without it.', style: Theme.of(context).textTheme.labelMedium)),
        ]),
      ),
    );
  }

  Widget _perm(BuildContext c, IconData icon, Color color, String title, String body, String primaryLabel, [String? androidLabel]) =>
      Padding(
        padding: const EdgeInsets.only(bottom: PulseSpacing.m),
        child: PulseCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(PulseRadius.s)),
                child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: PulseSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(c).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(c).textTheme.bodySmall?.copyWith(fontSize: 14)),
                const SizedBox(height: PulseSpacing.sm),
                Wrap(spacing: PulseSpacing.s, children: [
                  FilledButton.tonal(
                      onPressed: () => pulseSnack(c, 'System permission dialog would appear here.'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      child: Text(androidLabel != null ? '$primaryLabel · $androidLabel' : primaryLabel)),
                  TextButton(onPressed: () {}, child: const Text('Maybe Later')),
                ]),
              ]),
            ),
          ]),
        ),
      );
}
