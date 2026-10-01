import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/monetization.dart';
import '../data/pulse_store.dart';
import '../theme/tokens.dart';
import '../widgets/pulse_components.dart';
import '../screens/profile/premium_screens.dart';

/// App-wide provider access + shared UI helpers used by all screens.
extension PulseCtx on BuildContext {
  PulseStore get pulse => PulseStore.of(this);
  void vibrate() => HapticFeedback.lightImpact();
}

/// Theme-aware divider helper (ColorScheme lacks dividerColor in Flutter 3.24).
extension PulseDividerX on BuildContext {
  Color get dividerColor => Theme.of(this).colorScheme.onSurface.withOpacity(0.12);
}

String fmtKg(double kg, String unit) => unit == 'lb'
    ? '${(kg * 2.20462).toStringAsFixed(1)} lb'
    : '${kg.toStringAsFixed(1)} kg';

String fmtKm(double km, String unit) => unit == 'mi'
    ? '${(km * 0.621371).toStringAsFixed(2)} mi'
    : '${km.toStringAsFixed(1)} km';

String fmtMl(double ml, String unit) => unit == 'oz'
    ? '${(ml / 29.5735).toStringAsFixed(0)} oz'
    : '${ml.toStringAsFixed(0)} ml';

// ── Date formatting (C1) ───────────────────────────────────────────
// Every screen that needed a date carried its own literal — the greeting
// read 'Tuesday, September 29' forever and the diary's whole date axis was
// three hard-coded strings. No intl dependency in this project, so the
// names live here; `now` is injectable so a test can pin the day (§75).

const kWeekdayNames = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const kMonthNames = <String>['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
const kMonthAbbrev = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 'Tuesday, September 29' — the dashboard greeting line (§16).
String fmtLongDate(DateTime d) => '${kWeekdayNames[d.weekday - 1]}, ${kMonthNames[d.month - 1]} ${d.day}';

/// 'Tuesday, Sep 29' — the diary and detail headers, where space is tighter.
String fmtMediumDate(DateTime d) => '${kWeekdayNames[d.weekday - 1]}, ${kMonthAbbrev[d.month - 1]} ${d.day}';

/// 'Sep 29' — chips and ranges.
String fmtShortDate(DateTime d) => '${kMonthAbbrev[d.month - 1]} ${d.day}';

/// '8:10 AM' — timestamps on individual logged entries (§3), where the
/// water screen previously printed invented times.
String fmtClockTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// 'Good morning' / 'Good afternoon' / 'Good evening' (§16). The greeting said
/// morning at every hour, which is a small falsehood of the same kind.
String fmtGreeting(DateTime d) =>
    d.hour < 12 ? 'Good morning' : d.hour < 17 ? 'Good afternoon' : 'Good evening';

void pulseTapHaptic() => HapticFeedback.selectionClick();


void pulseSnack(BuildContext context, String message, {String? undoLabel, VoidCallback? onUndo, IconData? icon}) =>
    PulseToast.show(context, message, undoLabel: undoLabel, onUndo: onUndo, icon: icon);

/// Nav/Top — standard screen scaffold with back button & actions.
class PulseScaffold extends StatelessWidget {
  const PulseScaffold({super.key, required this.title, required this.body, this.actions, this.bottomBar,
      this.floatingAction, this.floatingActionButton, this.onBack, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? floatingAction;
  final VoidCallback? onBack;
  /// Alias accepted for ergonomic parity with Scaffold.floatingActionButton.
  final Widget? floatingActionButton;
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
      floatingActionButton: floatingAction ?? floatingActionButton,
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
  // D3: eight items could not fit the default 65% cap and overflowed by 176 px
  // on a 360×800 screen. tall: true raises the cap; the body scrolls (below).
  await pulseSheet<void>(context, builder: (ctx) => const _QuickLogSheet(), tall: true);
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
        // D3: shrinkWrap sized the list to its content, so the sheet overflowed
        // once the items exceeded its cap — and at a large textScale it still
        // would. Flexible plus a scrolling list keeps every item reachable.
        Flexible(child: ListView.separated(
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
        )),
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

/// ═════════ PHASE 4 — AD SLOT + TRIAL BANNER WIDGETS ═════════
/// Ad policy (§61/§62): ads appear ONLY for free users, ONLY in the
/// three approved footer slots, NEVER inside camera/scanner surfaces or
/// mid-logging flows, and are always labelled "Advertisement". When a
/// real SDK is wired, [AdBanner] renders its view instead of the honest
/// placeholder; layout height stays stable so content never jumps.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key, this.slot = AdSlot.homeFooter});
  final AdSlot slot;

  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    // Entitlement check lives HERE, not at call sites — impossible to
    // forget hiding ads for Pro users.
    if (!store.adsAllowed || !AdPolicy.allowedSlots.contains(slot)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.s),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(PulseRadius.m),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.smart_display_outlined, size: 22, color: scheme.onSurface.withOpacity(0.35)),
              const SizedBox(height: 4),
              Text('Your ad could be here', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.4))),
            ]),
          ),
          Positioned(
            top: 6, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Advertisement',
                  semanticsLabel: 'Advertisement',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4,
                      color: scheme.onSurface.withOpacity(0.55))),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Honest trial-status banner shown on Today while a Pro trial is active.
/// No fake countdowns — text derived from the persisted clock (§62).
class TrialStatusBanner extends StatelessWidget {
  const TrialStatusBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final store = PulseStore.of(context);
    final text = store.trialBanner;
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PulseSpacing.m, PulseSpacing.s, PulseSpacing.m, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(PulseRadius.m),
          border: Border.all(color: scheme.primary.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(Icons.workspace_premium_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.primary))),
        ]),
      ),
    );
  }
}

/// Up to two initials from a display name (§14). Returns '' when the name holds
/// no letters, so the caller shows a neutral icon rather than inventing any.
String pulseInitials(String name) {
  final letters = name.trim().split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0])
      .where((c) => RegExp(r'[A-Za-z]').hasMatch(c));
  return letters.take(2).join().toUpperCase();
}

/// Compact avatar used in headers/profile.
/// [initials] is required on purpose: the old default of 'AM' outlived the
/// removed sample identity and read 'AM' beside every real name (D1/C4).
/// Empty initials render a neutral person icon — never letters we invented.
class PulseAvatar extends StatelessWidget {
  const PulseAvatar({super.key, this.radius = 20, required this.initials, this.showPhoto = true});
  final double radius;
  final String initials;
  final bool showPhoto;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: initials.isEmpty
            ? Icon(Icons.person_rounded, size: radius, color: Theme.of(context).colorScheme.primary)
            : Text(initials,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: radius * 0.7,
                    color: Theme.of(context).colorScheme.primary)),
      );
}

/// Compact up/down trend chip used by Chart cards (§42/§45).
class TrendIndicator extends StatelessWidget {
  const TrendIndicator({super.key, this.changeKg, this.changePct, this.label = '', this.goodWhenNegative = false});
  final double? changeKg;
  final double? changePct;
  final String label;
  final bool goodWhenNegative;
  @override
  Widget build(BuildContext context) {
    final v = changeKg ?? changePct ?? 0.0;
    final unit = changeKg != null ? ' kg' : '%';
    final positive = v >= 0;
    final good = goodWhenNegative ? v <= 0 : v >= 0;
    final color = good ? PulseColors.success : PulseColors.warning;
    return Semantics(
      label: '${positive ? 'Up' : 'Down'} ${v.abs().toStringAsFixed(1)}$unit $label',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: color),
        const SizedBox(width: 2),
        Text('${positive ? '+' : '−'}${v.abs().toStringAsFixed(1)}$unit${label.isEmpty ? '' : ' $label'}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600).copyWith(color: color)),
      ]),
    );
  }
}
