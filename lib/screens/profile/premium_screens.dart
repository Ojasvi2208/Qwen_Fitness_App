import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 13 — Premium. Paywall sheet (§62) + Subscription screen (§61).
/// No deceptive countdowns; free path always visible.
/// ═══════════════════════════════════════════════════════════════════

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key, this.featureName});
  final String? featureName;
  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  int _plan = 1; // default yearly (better value, honestly labelled)
  static const _benefits = <({IconData icon, String title, String body})>[
    (icon: Icons.insights_rounded, title: 'Advanced nutrition insights', body: 'Macro trends, nutrient breakdowns and pattern detection.'),
    (icon: Icons.qr_code_scanner_rounded, title: 'Barcode scanning', body: 'Log packaged foods in seconds from a huge product database.'),
    (icon: Icons.photo_camera_rounded, title: 'AI meal recognition', body: 'Photograph a plate — review the estimate, then log.'),
    (icon: Icons.mic_rounded, title: 'Voice logging', body: '“Two eggs and toast” becomes a logged breakfast.'),
    (icon: Icons.query_stats_rounded, title: 'Advanced progress reports', body: 'Weekly deep-dives on nutrition, activity and weight.'),
    (icon: Icons.tune_rounded, title: 'Custom macro goals', body: 'Set protein, carb and fat targets exactly how you like.'),
    (icon: Icons.fitness_center_rounded, title: 'Workout programs', body: 'Structured multi-week plans that adapt to you.'),
    (icon: Icons.auto_awesome_rounded, title: 'AI coaching', body: 'Pulse Coach with personalised, data-grounded answers.'),
    (icon: Icons.block_rounded, title: 'Ad-free experience', body: 'Nothing between you and your day.'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PulseStore>();
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(PulseSpacing.l, PulseSpacing.sm, PulseSpacing.l, PulseSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: PulseSpacing.xl),
          if (widget.featureName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.sm),
              decoration: BoxDecoration(color: scheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.m)),
              child: Row(children: [
                Icon(Icons.lock_open_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: PulseSpacing.s),
                Expanded(child: Text('$widget.featureName is part of PULSE Pro. Everything else stays free.',
                    style: TextStyle(fontSize: 14, color: scheme.primary, fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: PulseSpacing.l),
          ],
          Text('Go further with PULSE Pro', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: PulseSpacing.s),
          Text('Keep the habits you\'ve built — and get deeper insight, faster logging and adaptive training.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: PulseSpacing.xl),
          // Plan toggle — honest pricing, no countdown timers.
          PulseSegmented(options: const ['Monthly', 'Yearly · save 40%'], index: _plan, onChanged: (i) => setState(() => _plan = i)),
          const SizedBox(height: PulseSpacing.m),
          AnimatedSwitcher(
            duration: PulseDuration.fast,
            child: _plan == 0
                ? _priceCard(key: const ValueKey('m'), price: '\$9.99 / month', note: 'Cancel anytime')
                : _priceCard(key: const ValueKey('y'), price: '\$59.99 / year', note: '≈ \$4.99/month · Cancel anytime'),
          ),
          const SizedBox(height: PulseSpacing.l),
          for (final b in _benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: scheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(PulseRadius.s)),
                    child: Icon(b.icon, size: 18, color: scheme.primary)),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(b.body, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5)),
                ])),
              ]),
            ),
          const SizedBox(height: PulseSpacing.m),
          PrimaryButton(
              label: 'Start Free Trial',
              icon: Icons.rocket_launch_rounded,
              onTap: () {
                store.togglePremium();
                store.track('trial_started');
                Navigator.pop(context);
                pulseSnack(context, 'PULSE Pro unlocked — 14-day trial, we\'ll remind you before it ends.', icon: Icons.verified_rounded);
              }),
          const SizedBox(height: PulseSpacing.s),
          Center(
            child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  pulseSnack(context, 'No pressure. The free plan keeps all core logging.');
                },
                child: const Text('Continue with Free')),
          ),
          Center(
            child: Text('Recurring billing · Cancel anytime in Settings → Subscription',
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ]),
      ),
    );
  }

  Widget _priceCard({super.key, required String price, required String note}) => PulseCard(
        child: Row(children: [
          const ProBadge(label: 'PRO+'),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(child: Text(price, style: PulseTypography.metricSmall.copyWith(color: Theme.of(context).colorScheme.onSurface))),
          Text(note, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
        ]),
      );
}

/// Screen 61 — Subscription management.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<PulseStore>();
    final scheme = Theme.of(context).colorScheme;
    return PulseScaffold(
      title: 'Subscription',
      body: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.m, 0, PulseSpacing.m, PulseSpacing.huge), children: [
        PulseCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(store.premium ? 'PULSE Pro' : 'PULSE Free', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: PulseSpacing.s),
              if (store.premium) const ProBadge(),
            ]),
            const SizedBox(height: 2),
            Text(store.premium
                ? 'Trial ends Oct 13, 2026 · Renews at \$59.99/year\nManage or cancel anytime below.'
                : 'Core logging, diary, progress and workouts are free forever.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: PulseSpacing.m),
            if (!store.premium)
              PrimaryButton(label: 'Upgrade to PULSE Pro', onTap: () => pulseSheet(context, tall: true, builder: (_) => const PaywallSheet())),
          ]),
        ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'What Pro unlocks'),
        for (final f in const ['AI meal recognition', 'Voice logging', 'Advanced progress reports', 'Custom macro goals', 'Workout programs', 'Pulse Coach AI'])
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s),
            leading: Icon(store.premium ? Icons.check_circle_rounded : Icons.lock_rounded,
                color: store.premium ? PulseColors.success : scheme.onSurface.withOpacity(0.4), size: 20),
            title: Text(f),
            trailing: store.premium ? null : const ProBadge(),
          ),
        const SizedBox(height: PulseSpacing.l),
        SectionHeader(title: 'PULSE Pro+ (coming soon)'),
        PulseCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Personalized meal plans · Adaptive workout programs · Grocery planning · Recovery insights',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: PulseSpacing.s),
            Text('Higher tier above Pro — clearly separated, optional, not required for any core feature.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        if (store.premium) ...[
          const SizedBox(height: PulseSpacing.l),
          SecondaryButton(label: 'Manage subscription', icon: Icons.receipt_long_rounded, onTap: () => pulseSnack(context, 'Opens the App Store / Play Store subscription manager.')),
          const SizedBox(height: PulseSpacing.s),
          TertiaryButton(label: 'Cancel plan', onTap: () async {
            final ok = await pulseConfirm(context,
                title: 'Cancel PULSE Pro?',
                body: 'You keep Pro until Oct 13, 2026, then move back to the free plan. Your logs and history are never deleted.',
                confirmLabel: 'Cancel subscription', destructive: true);
            if (ok && context.mounted) {
              store.togglePremium();
              pulseSnack(context, 'Subscription will end Oct 13, 2026. Your data stays safe.');
            }
          }),
        ],
      ]),
    );
  }
}
