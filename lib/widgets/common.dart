import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/pulse_store.dart';
import '../theme/tokens.dart';
import '../widgets/pulse_components.dart';

/// App-wide provider access + shared UI helpers used by all screens.
extension PulseCtx on BuildContext {
  PulseStore get pulse => read<PulseStore>();
  void vibrate() => HapticFeedback.lightImpact();
}

void pulseSnack(BuildContext context, String message, {String? undoLabel, VoidCallback? onUndo, IconData? icon}) =>
    PulseToast.show(context, message, undoLabel: undoLabel, onUndo: onUndo, icon: icon);

/// Nav/Top — standard screen scaffold with back button & actions.
class PulseScaffold extends StatelessWidget {
  const PulseScaffold({super.key, required this.title, required this.body, this.actions, this.bottomBar, this.floatingAction, this.onBack, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? floatingAction;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
        ]),
        leading: onBack != null || Navigator.of(context).canPop()
            ? IconButton(
                onPressed: onBack ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                tooltip: 'Back')
            : null,
        actions: actions,
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingAction,
    );
  }
}

/// Bottom sheet helper — Modal/Sheet standard presentation.
Future<T?> pulseSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder, bool tall = false}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: tall ? MediaQuery.sizeOf(context).height * 0.92 : MediaQuery.sizeOf(context).height * 0.65),
      builder: builder,
    );

/// Sheet drag handle + grabber look.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(PulseSpacing.l, PulseSpacing.sm, PulseSpacing.l, PulseSpacing.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: PulseSpacing.m),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      );
}

/// Quick Log modal (§20 / Modal/QuickLog) — reachable from every tab.
/// Priority order per §89: Food → Water → Exercise → Weight.
Future<void> openQuickLog(BuildContext context) async {
  context.pulse.track('quick_log_opened');
  await pulseSheet<void>(context, builder: (ctx) => const _QuickLogSheet());
}

class _QuickLogSheet extends StatelessWidget {
  const _QuickLogSheet();
  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, Color color, String label, String hint, VoidCallback onTap})>[
      (icon: Icons.restaurant_rounded, color: PulseColors.primary, label: 'Log Food', hint: 'Search or pick a recent meal',
          onTap: () { Navigator.pop(context); context.pulse.track('food_search_started'); _go(context, '/food-search'); }),
      (icon: Icons.qr_code_scanner_rounded, color: PulseColors.secondary, label: 'Scan Barcode', hint: 'Pro feature preview',
          onTap: () { Navigator.pop(context); context.pulse.track('barcode_scan_started'); _go(context, '/barcode'); }),
      (icon: Icons.photo_camera_rounded, color: PulseColors.accent, label: 'Scan Meal', hint: 'AI estimates — you confirm',
          onTap: () { Navigator.pop(context); context.pulse.track('meal_scan_started'); _go(context, '/meal-scan'); }),
      (icon: Icons.mic_rounded, color: PulseColors.fat, label: 'Voice Log', hint: '“Two eggs and toast…”',
          onTap: () { Navigator.pop(context); _go(context, '/voice-log'); }),
      (icon: Icons.water_drop_rounded, color: PulseColors.water, label: 'Log Water', hint: '+250 ml in one tap',
          onTap: () { Navigator.pop(context); _go(context, '/water'); }),
      (icon: Icons.fitness_center_rounded, color: PulseColors.exercise, label: 'Log Exercise', hint: 'Cardio or strength',
          onTap: () { Navigator.pop(context); _go(context, '/log-exercise'); }),
      (icon: Icons.monitor_weight_rounded, color: PulseColors.steps, label: 'Log Weight', hint: 'Trend matters more than today',
          onTap: () { Navigator.pop(context); _go(context, '/log-weight'); }),
      (icon: Icons.straighten_rounded, color: PulseColors.fiber, label: 'Log Measurement', hint: 'Waist, arms, hips…',
          onTap: () { Navigator.pop(context); _go(context, '/measurements'); }),
    ];
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHeader(title: 'What would you like to log?', subtitle: 'The fastest actions are always one tap away.'),
        ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(PulseSpacing.l, 0, PulseSpacing.l, PulseSpacing.l),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: PulseSpacing.s),
          itemBuilder: (_, i) {
            final it = items[i];
            return InkWell(
              borderRadius: BorderRadius.circular(PulseRadius.m),
              onTap: it.onTap,
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: 13),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(PulseRadius.m)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: it.color.withOpacity(0.14), borderRadius: BorderRadius.circular(PulseRadius.s)),
                      child: Icon(it.icon, color: it.color, size: 22)),
                  const SizedBox(width: PulseSpacing.sm),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.label, style: Theme.of(context).textTheme.titleMedium),
                    Text(it.hint, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  static void _go(BuildContext ctx, String route) => Navigator.of(ctx).pushNamed(route);
}

/// Confirmation dialog with explicit consequence copy (§74/§76).
Future<bool> pulseConfirm(BuildContext context,
    {required String title, required String body, String confirmLabel = 'Confirm', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: PulseColors.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

/// Premium-locked gate (§61/§62): never blocks core logging, only Pro extras.
bool ensurePremium(BuildContext context, String featureName) {
  if (context.pulse.premium) return true;
  context.pulse.track('paywall_viewed', {'feature': featureName});
  pulseSheet(context, tall: true, builder: (_) => PaywallSheet(featureName: featureName));
  return false;
}

/// Compact avatar used in headers/profile.
class PulseAvatar extends StatelessWidget {
  const PulseAvatar({super.key, this.radius = 20});
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text('AM',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
                color: Theme.of(context).colorScheme.primary)),
      );
}
