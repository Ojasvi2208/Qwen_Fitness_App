import 'package:flutter/material.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 12 — Profile & Settings (§56–§60, §64, §69, §70).
/// ═══════════════════════════════════════════════════════════════════

// ── §56 Profile home ───────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 120), children: [
        // Header
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          onTap: () => Navigator.of(context).pushNamed('/personal-details'),
          child: Row(children: [
            Stack(alignment: Alignment.bottomRight, children: [
              const PulseAvatar(radius: 30, initials: 'AM', showPhoto: false),
              Container(width: 20, height: 20, decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle, border: Border.all(color: scheme.surface)),
                  child: Icon(Icons.edit_rounded, size: 11, color: scheme.onSurface.withOpacity(0.6))),
            ]),
            const SizedBox(width: PulseSpacing.m),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alex Morgan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 21)),
              Text('Member since March 2026', style: Theme.of(context).textTheme.bodySmall),
              if (store.premium)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: PulseColors.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(PulseRadius.full)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.workspace_premium_rounded, size: 13, color: PulseColors.secondaryDark),
                        SizedBox(width: 4),
                        Text('PULSE Pro', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: PulseColors.secondaryDark)),
                      ])),
                ),
            ])),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.35)),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        for (final row in <({String title, IconData icon, String? route, String detail})>[
          (title: 'Goals', icon: Icons.flag_rounded, route: '/goals', detail: 'Calories · macros · water · steps'),
          (title: 'Nutrition', icon: Icons.restaurant_rounded, route: '/nutrition-prefs', detail: 'Diet style · allergies · meal times'),
          (title: 'Workout Preferences', icon: Icons.fitness_center_rounded, route: '/workout-prefs', detail: 'Equipment · types · reminders'),
          (title: 'Measurements', icon: Icons.straighten_rounded, route: '/measurements', detail: 'Weight · body fat · circumferences'),
          (title: 'Connected Apps & Devices', icon: Icons.devices_other_rounded, route: '/connected-apps', detail: 'Apple Health · Watch · Oura'),
          (title: 'Notifications', icon: Icons.notifications_rounded, route: '/notification-settings', detail: 'Reminders by category and time'),
          (title: 'Appearance', icon: Icons.dark_mode_rounded, detail: 'Theme · larger text'),
          (title: 'Privacy', icon: Icons.lock_rounded, route: '/privacy', detail: 'Your data, your control'),
          (title: 'Subscription', icon: Icons.workspace_premium_rounded, route: '/subscription', detail: store.premium ? 'PULSE Pro · yearly' : 'Free plan'),
          (title: 'Help & Support', icon: Icons.help_outline_rounded, route: '/help', detail: 'FAQs · contact · about'),
          (title: 'Account', icon: Icons.person_outline_rounded, route: '/personal-details', detail: 'Email · units · sign out'),
        ])
          Card(
            child: ListTile(
              leading: Icon(row.icon, color: scheme.onSurface.withOpacity(0.6)),
              title: Text(row.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(row.detail ?? '', style: Theme.of(context).textTheme.bodySmall),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.3)),
              onTap: () => row.route != null
                  ? Navigator.of(context).pushNamed(row.route!)
                  : _appearanceSheet(context, store),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        OutlinedButton.icon(onPressed: () async {
          final ok = await pulseConfirm(context,
              title: 'Log out of PULSE?',
              body: 'Your data stays safe on your device and in your account. You can log back in any time.',
              confirmLabel: 'Log Out');
          if (ok && context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (r) => false);
        }, icon: const Icon(Icons.logout_rounded, size: 18), label: const Text('Log Out')),
      ]),
    );
  }

  void _appearanceSheet(BuildContext context, PulseStore store) {
    pulseSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PulseSpacing.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHeader(title: 'Appearance'),
          Text('Theme', style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: PulseSpacing.s),
          PulseSegmented(
              options: const ['System', 'Light', 'Dark'],
              index: switch (store.themeMode) { ThemeMode.system => 0, ThemeMode.light => 1, _ => 2 },
              onChanged: (i) => set(() => store.setThemeMode([ThemeMode.system, ThemeMode.light, ThemeMode.dark][i]))),
          const SizedBox(height: PulseSpacing.l),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: store.largeText,
              onChanged: (v) => set(() => store.setLargeText(v)),
              title: const Text('Larger Text', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Scales all type up to ~28% while keeping layout intact')),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: store.highContrast,
              onChanged: (v) => set(() => store.setHighContrast(v)),
              title: const Text('High Contrast', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Stronger text and borders, simplified chart fills')),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: store.reduceMotion,
              onChanged: (v) => set(() => store.setReduceMotion(v)),
              title: const Text('Reduce Motion', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Disables ring fills, pulses and sheet springs')),
        ]),
      ),
    )));
  }
}

// ── Personal details + Units (§59) ─────────────────────────────────
class PersonalDetailsScreen extends StatelessWidget {
  const PersonalDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.pulse;
    return PulseScaffold(
      title: 'Personal Details',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        const TextField(controller: TextEditingController(text: 'Alex Morgan'), decoration: InputDecoration(labelText: 'Full name')),
        const SizedBox(height: PulseSpacing.m),
        const TextField(controller: TextEditingController(text: 'alex.morgan@email.com'), decoration: InputDecoration(labelText: 'Email', helperText: 'Changing this sends a verification link.')),
        const SizedBox(height: PulseSpacing.m),
        const TextField(controller: TextEditingController(text: 'March 2026'), decoration: InputDecoration(labelText: 'Member since', enabled: false)),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Units (§59)'),
        PulseCard(
          child: Column(children: [
            _unitRow(context, 'Weight', ['kg', 'lb'], store.unitsWeight, store.setUnitsWeight),
            _unitRow(context, 'Height', ['cm', 'ft + in'], store.unitsHeight, store.setUnitsHeight),
            _unitRow(context, 'Volume', ['ml', 'oz'], store.unitsVolume, store.setUnitsVolume),
            _unitRow(context, 'Distance', ['km', 'miles'], store.unitsDistance, store.setUnitsDistance),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SecondaryButton(label: 'Change Password', icon: Icons.lock_reset_rounded,
            onTap: () => pulseSnack(context, 'A secure password-reset link was sent to alex.morgan@email.com.', icon: Icons.mark_email_read_rounded)),
        const SizedBox(height: PulseSpacing.s),
        OutlinedButton(onPressed: () async {
          final ok = await pulseConfirm(context,
              title: 'Delete account and all data?',
              body: 'This permanently removes your logs, measurements, photos and subscription from this device and the cloud. Export first via Privacy → Download My Data. This cannot be undone.',
              confirmLabel: 'Delete Everything', destructive: true);
          if (ok && context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (r) => false);
        }, style: OutlinedButton.styleFrom(foregroundColor: scheme_err(context)), child: const Text('Delete Account')),
      ]),
    );
  }

  Color scheme_err(BuildContext c) => Theme.of(c).colorScheme.error;

  Widget _unitRow(BuildContext c, String label, List<String> opts, String current, ValueChanged<String> set) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: PulseSpacing.sm),
        child: Row(children: [
          Expanded(child: Text(label, style: Theme.of(c).textTheme.bodyLarge)),
          SegmentedButton<String>(
            segments: [for (final o in opts) ButtonSegment(value: o, label: Text(o))],
            selected: {current},
            onSelectionChanged: (s) => set(s.first),
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ]),
      );
}

// ── Nutrition / Workout preference screens ─────────────────────────
class NutritionPrefsScreen extends StatefulWidget {
  const NutritionPrefsScreen({super.key});
  @override
  State<NutritionPrefsScreen> createState() => _NutritionPrefsScreenState();
}

class _NutritionPrefsScreenState extends State<NutritionPrefsScreen> {
  String _diet = 'No preference';
  final Set<String> _allergies = {'Nuts'};
  TimeOfDay? _lunch = const TimeOfDay(hour: 12, minute: 30);

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Nutrition Preferences',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SectionHeader(title: 'Eating style'),
        for (final d in const ['No preference', 'Vegetarian', 'Vegan', 'High protein', 'Low carb', 'Keto', 'Mediterranean', 'Pescatarian'])
          OptionTile(title: d, selected: _diet == d, onTap: () => setState(() => _diet = d)),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Allergies & intolerances'),
        Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
          for (final a in const ['Nuts', 'Peanuts', 'Gluten', 'Dairy', 'Eggs', 'Shellfish', 'Soy', 'Sesame'])
            FilterChip(label: Text(a), selected: _allergies.contains(a),
                onSelected: (v) => setState(() => v ? _allergies.add(a) : _allergies.remove(a))),
        ]),
        Text('Allergy flags warn you during food search and recipe suggestions.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Usual meal times'),
        for (final slot in const [('Breakfast', '7:15 AM'), ('Lunch', '12:30 PM'), ('Dinner', '7:00 PM')])
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            title: Text(slot.$1, style: Theme.of(context).textTheme.titleMedium),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(slot.$2, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              const Icon(Icons.access_time_rounded, size: 18),
            ]),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _lunch ?? TimeOfDay.now(),
                  helpText: 'Pick ${slot.$1.toLowerCase()} time');
              if (t != null) setState(() => _lunch = t);
            },
          ),
      ]),
    );
  }
}

class WorkoutPrefsScreen extends StatefulWidget {
  const WorkoutPrefsScreen({super.key});
  @override
  State<WorkoutPrefsScreen> createState() => _WorkoutPrefsScreenState();
}

class _WorkoutPrefsScreenState extends State<WorkoutPrefsScreen> {
  final Set<String> _types = {'Gym', 'Strength training', 'Walking'};
  final Set<String> _equipment = {'Dumbbells', 'Bench'};

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Workout Preferences',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SectionHeader(title: 'Exercise I enjoy'),
        Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
          for (final t in const ['Walking', 'Running', 'Gym', 'Strength training', 'Cycling', 'Yoga', 'Swimming', 'HIIT', 'Sports', 'Home workouts'])
            FilterChip(label: Text(t), selected: _types.contains(t), onSelected: (v) => setState(() => v ? _types.add(t) : _types.remove(t))),
        ]),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Available equipment'),
        Wrap(spacing: PulseSpacing.s, runSpacing: PulseSpacing.s, children: [
          for (final e in const ['None', 'Mat', 'Dumbbells', 'Barbell', 'Bench', 'Bands', 'Pull-up bar', 'Gym access'])
            FilterChip(label: Text(e), selected: _equipment.contains(e), onSelected: (v) => setState(() => v ? _equipment.add(e) : _equipment.remove(e))),
        ]),
        Text('Library filters and Coach suggestions default to these.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Weekly target'),
        Row(children: [
          Expanded(child: Text('Workouts per week: ${_weekTarget}', style: Theme.of(context).textTheme.titleMedium)),
        ]),
        Slider(value: _weekTarget.toDouble(), min: 1, max: 7, divisions: 6, label: '$_weekTarget/week',
            onChanged: (v) => setState(() => _weekTarget = v.round())),
      ]),
    );
  }

  int _weekTarget = 4;
}

// ── §57 Connected apps & devices ───────────────────────────────────
class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});
  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  late final Map<String, ({bool connected, String detail, IconData icon})> _apps = {
    'Apple Health': (connected: true, detail: 'Steps, workouts, weight · synced 4 min ago', icon: Icons.health_and_safety_rounded),
    'Apple Watch': (connected: true, detail: 'Heart rate, workout sessions', icon: Icons.watch_rounded),
    'Health Connect': (connected: false, detail: 'Android health data (steps, sleep)', icon: Icons.monitor_heart_rounded),
    'Fitbit': (connected: false, detail: 'Steps, sleep, cardio sessions', icon: Icons.show_chart_rounded),
    'Garmin': (connected: false, detail: 'Runs, rides, training load', icon: Icons.hiking_rounded),
    'Oura': (connected: false, detail: 'Sleep and readiness', icon: Icons.bedtime_rounded),
    'Strava': (connected: false, detail: 'Outdoor runs and rides', icon: Icons.directions_bike_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Apps & Devices',
      subtitle: 'Data flows one way in — PULSE never writes without asking',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final e in _apps.entries)
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: e.value.connected ? PulseColors.success.withOpacity(0.13) : scheme.surfaceContainerHighest,
                  child: Icon(e.value.icon, size: 20, color: e.value.connected ? PulseColors.success : scheme.onSurface.withOpacity(0.5))),
              title: Text(e.key, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(e.value.detail),
              trailing: e.value.connected
                  ? OutlinedButton(onPressed: () => _toggle(e.key), style: OutlinedButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size(0, 40)), child: const Text('Disconnect'))
                  : FilledButton.tonal(onPressed: () => _toggle(e.key), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), child: const Text('Connect')),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        Text('Integration cards are generic representations; each provider\'s own branding appears at connection time.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  void _toggle(String name) async {
    final wasConnected = _apps[name]!.connected;
    if (wasConnected) {
      final ok = await pulseConfirm(context,
          title: 'Disconnect $name?',
          body: 'Already-imported history stays in PULSE. New data stops syncing until you reconnect.',
          confirmLabel: 'Disconnect');
      if (!ok || !mounted) return;
    } else {
      context.pulse.track('integration_connected');
    }
    setState(() => _apps[name] = (connected: !wasConnected, detail: _apps[name]!.detail, icon: _apps[name]!.icon));
    pulseSnack(context, wasConnected ? '$name disconnected' : '$name connected — initial sync started',
        icon: wasConnected ? Icons.link_off_rounded : Icons.link_rounded);
  }
}

// ── §58 Notification settings + §64 Reminder creation ──────────────
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final Map<String, bool> _cats = {'Meal reminders': true, 'Water reminders': true, 'Workout reminders': true, 'Weekly reports': true, 'Goal updates': true, 'Product updates': false};
  final Map<String, String> _windows = {'Meal reminders': 'Afternoon', 'Water reminders': 'Morning', 'Workout reminders': 'Evening'};
  final List<({String name, String repeat, String time})> _reminders = [
    (name: 'Drink Water', repeat: 'Every day', time: '10:30 AM'),
    (name: 'Log dinner', repeat: 'Weekdays', time: '7:15 PM'),
  ];

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Notifications',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SectionHeader(title: 'Categories'),
        for (final c in _cats.keys)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            value: _cats[c]!,
            onChanged: (v) => setState(() => _cats[c] = v),
            title: Text(c, style: Theme.of(context).textTheme.titleMedium),
            subtitle: _cats[c]! && _windows.containsKey(c)
                ? Row(children: [
                    Text('${_windows[c]} window · ', style: Theme.of(context).textTheme.bodySmall),
                    GestureDetector(
                        onTap: () => _pickWindow(c),
                        child: Text('change', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline))),
                  ])
                : null,
          ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Custom reminders', actionLabel: '+ Add', onAction: () => _addReminder(context)),
        for (var i = 0; i < _reminders.length; i++)
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm_rounded),
              title: Text(_reminders[i].name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text('Repeat: ${_reminders[i].repeat} · ${_reminders[i].time}'),
              trailing: IconButton(tooltip: 'Delete reminder', icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () => setState(() => _reminders.removeAt(i))),
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        Text('Reminders state what remains, never what you missed. Quiet hours follow your sleep window.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  void _pickWindow(String cat) {
    pulseSheet(context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: '$cat timing'),
        for (final w in const ['Morning', 'Afternoon', 'Evening', 'Custom time…'])
          RadioListTile<String>(value: w, groupValue: _windows[cat], title: Text(w),
              onChanged: (v) { setState(() => _windows[cat] = v!); Navigator.pop(ctx); }),
      ]),
    ));
  }

  void _addReminder(BuildContext context) {
    final name = TextEditingController(text: 'Drink Water');
    String repeat = 'Every day';
    String time = '10:30 AM';
    pulseSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PulseSpacing.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHeader(title: 'New Reminder'),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Reminder name')),
          const SizedBox(height: PulseSpacing.m),
          Text('Repeat', style: Theme.of(ctx).textTheme.labelMedium),
          Wrap(spacing: PulseSpacing.s, children: [
            for (final r in const ['Daily', 'Weekdays', 'Custom'])
              ChoiceChip(label: Text(r), selected: repeat == (r == 'Daily' ? 'Every day' : r), onSelected: (_) => set(() => repeat = r == 'Daily' ? 'Every day' : r)),
          ]),
          const SizedBox(height: PulseSpacing.m),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule_rounded),
              title: Text('Time: $time'),
              trailing: TextButton(onPressed: () async {
                final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 10, minute: 30));
                if (t != null) set(() => time = t.format(ctx));
              }, child: const Text('Pick'))),
          const SizedBox(height: PulseSpacing.s),
          PrimaryButton(label: 'Save Reminder', onTap: () {
            setState(() => _reminders.add((name: name.text.trim().isEmpty ? 'Drink Water' : name.text.trim(), repeat: repeat, time: time)));
            Navigator.pop(ctx);
            pulseSnack(context, 'Reminder created — $time', icon: Icons.alarm_on_rounded);
          }),
        ]),
      ),
    )));
  }
}

// ── §60 Privacy Center ─────────────────────────────────────────────
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Privacy Center',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        PulseCard(
          padding: const EdgeInsets.all(PulseSpacing.l),
          child: Column(children: [
            Icon(Icons.lock_person_rounded, size: 40, color: scheme.primary),
            const SizedBox(height: PulseSpacing.s),
            Text('Your health information belongs to you.', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: PulseSpacing.xs),
            Text('Manage how your data is stored, connected and shared.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Data categories (§97 separation)'),
        for (final d in const [
          ('Account data', 'Name, email, plan — needed to run your account', Icons.person_rounded),
          ('Health data', 'Food, weight, measurements, photos — encrypted on device, end-to-end in cloud backup', Icons.favorite_rounded),
          ('Analytics data', 'Feature usage events only — never the contents of your logs', Icons.query_stats_rounded),
          ('Connected-device data', 'What each app/device shares with PULSE', Icons.devices_rounded),
        ])
          Card(
            child: ExpansionTile(
              leading: Icon(d.$3, color: scheme.onSurface.withOpacity(0.6)),
              title: Text(d.$1, style: Theme.of(context).textTheme.titleMedium),
              childrenPadding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.m),
              expandedChildren: [
                Align(alignment: Alignment.centerLeft, child: Text(d.$2, style: Theme.of(context).textTheme.bodyMedium)),
                const SizedBox(height: PulseSpacing.s),
                Align(alignment: Alignment.centerLeft, child: Text('Category isolation is enforced in storage; toggling analytics off stops all event tracking.', style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'Controls'),
        for (final row in const [
          ('Download My Data', 'A full JSON export of every entry you\'ve made'),
          ('Delete My Data', 'Removes all health data; keeps your account'),
          ('Privacy Settings', 'Analytics opt-out, ad personalization (off), third-party sharing (none)'),
          ('Terms', 'The agreement you accepted at signup'),
          ('Privacy Policy', 'Plain-language summary included inside'),
        ])
          Card(
            child: ListTile(
              title: Text(row.$1, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(row.$2, style: Theme.of(context).textTheme.bodySmall),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.3)),
              onTap: () async {
                if (row.$1 == 'Delete My Data') {
                  final ok = await pulseConfirm(context,
                      title: 'Delete all health data?',
                      body: 'Every food diary entry, weigh-in, measurement and progress photo will be permanently removed from this device and the cloud. Your account and subscription remain. Export first if unsure.',
                      confirmLabel: 'Delete Health Data', destructive: true);
                  if (ok && context.mounted) pulseSnack(context, 'Deletion queued — you\'ll get an email confirmation.', icon: Icons.delete_forever_rounded);
                } else {
                  pulseSnack(context, '${row.$1}: opens the documented flow.', icon: Icons.privacy_tip_rounded);
                }
              },
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
          value: PulseStore.of(context).analyticsEnabled,
          onChanged: (v) { context.pulse.setAnalytics(v); },
          title: const Text('Product analytics', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Anonymous feature-usage events. Never log contents.'),
        ),
      ]),
    );
  }
}

// ── §69 Help & About ───────────────────────────────────────────────
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Help & Support',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        for (final f in const [
          ('How do I log food quickly?', 'Tap + Log anywhere, then Search, scan or speak. Frequently logged foods appear first.'),
          ('Why did my remaining calories change?', 'Activity credit adjusts as workouts sync from Apple Health or manual logs.'),
          ('Can I undo a logging mistake?', 'Yes — every confirmation offers Undo, and diary rows support swipe-to-delete.'),
          ('How is my calorie target calculated?', 'Profile → Goals → Why these numbers explains the estimate and its limits.'),
        ])
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(f.$1, style: Theme.of(context).textTheme.titleMedium),
              childrenPadding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.m),
              expandedChildren: [Align(alignment: Alignment.centerLeft, child: Text(f.$2, style: Theme.of(context).textTheme.bodyMedium))],
            ),
          ),
        const SizedBox(height: PulseSpacing.m),
        SecondaryButton(label: 'Contact Support', icon: Icons.mail_outline_rounded,
            onTap: () => pulseSnack(context, 'support@pulseapp.example — replies within one business day.')),
        const SizedBox(height: PulseSpacing.s),
        const TertiaryButton(label: 'About PULSE · version 1.0.0 (build 248)', onTap: null),
        const SizedBox(height: PulseSpacing.l),
        const HealthDisclaimer(),
      ]),
    );
  }
}

// ── §70 Accessibility settings (dedicated screen) ──────────────────
class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    return PulseScaffold(
      title: 'Accessibility',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.m), children: [
        SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            value: store.largeText, onChanged: store.setLargeText,
            title: const Text('Larger Text', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Body copy scales from 16 px up to ~20 px across the app.')),
        SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            value: store.highContrast, onChanged: store.setHighContrast,
            title: const Text('High Contrast', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Meets WCAG AAA for text; status never relies on color alone.')),
        SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            value: store.reduceMotion, onChanged: store.setReduceMotion,
            title: const Text('Reduce Motion', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Charts render instantly; no pulsing, springy sheets or confetti.')),
        const SizedBox(height: PulseSpacing.m),
        const PulseCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Built-in commitments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            SizedBox(height: 6),
            Text('• Every tap target ≥ 44×44 pt\n• All charts carry a written summary for screen readers\n• Icons always paired with labels\n• Forms announce errors as text, not just red outlines',
                style: TextStyle(fontSize: 14.5, height: 1.6)),
          ]),
        ),
        const SizedBox(height: PulseSpacing.m),
        Semantics(
          button: true,
          child: OutlinedButton(onPressed: () {}, child: const Text('Preview screen-reader order of Today dashboard')),
        ),
      ]),
    );
  }
}
