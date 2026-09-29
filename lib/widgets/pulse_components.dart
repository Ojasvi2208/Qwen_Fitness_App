import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PULSE COMPONENT LIBRARY (§9). Every component uses token names in
/// its doc header, e.g. Button/Primary/Large, Card/NutritionSummary.
/// All components implement states: Default / Pressed / Focused /
/// Loading / Success / Error / Empty / Disabled (+ Locked where used).
/// ═══════════════════════════════════════════════════════════════════

// ── Buttons ────────────────────────────────────────────────────────
// Button/Primary/Large · Button/Secondary/Medium · Button/Tertiary
// Button/Destructive · Button/Icon · Button/FAB
/// Button/Primary/Large — states: Default · Pressed (InkWell) · Loading
/// (spinner) · Disabled (muted fill, absorbs taps).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.loading = false, this.large = true, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool large;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (onTap == null && !loading) {
      // Disabled state
      return AbsorbPointer(
        child: Container(
          height: large ? 54 : 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.l),
          decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.12),
              borderRadius: BorderRadius.circular(PulseRadius.m)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.38))),
        ),
      );
    }
    return FilledButton(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(
          minimumSize: Size(double.infinity, large ? 54 : 48),
          backgroundColor: theme.colorScheme.primary),
      child: loading
          ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: PulseSpacing.s)],
              Text(label),
            ]),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onTap, this.icon, this.fullWidth = true});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool fullWidth;
  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(minimumSize: Size(fullWidth ? double.infinity : 0, 52)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: PulseSpacing.s)],
        Text(label),
      ]));
}

class TertiaryButton extends StatelessWidget {
  const TertiaryButton({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary)));
}

class DestructiveButton extends StatelessWidget {
  const DestructiveButton({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD64545), minimumSize: const Size(double.infinity, 52)),
        child: Text(label),
      );
}

class IconButton3 extends StatelessWidget {
  const IconButton3({super.key, required this.icon, this.onTap, this.size = 44, this.selected = false});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(PulseRadius.full),
      onTap: onTap ?? () {},
      child: Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withOpacity(0.12) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: selected ? scheme.primary : scheme.onSurface.withOpacity(0.72)),
      ),
    );
  }
}

// ── Cards — Card/Base ──────────────────────────────────────────────
class PulseCard extends StatelessWidget {
  const PulseCard({super.key, required this.child, this.padding = const EdgeInsets.all(PulseSpacing.m), this.tapColor, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? tapColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? PulseColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(PulseRadius.l),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PulseRadius.l),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PulseRadius.l),
            border: Border.all(color: theme.dividerColor, width: PulseStroke.hairline),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Section/Card header with optional trailing action. Component: Label/SectionHeader
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
            if (actionLabel != null)
              TextButton(onPressed: onAction ?? () {}, child: Text(actionLabel!)),
          ],
        ),
      );
}

// ── Progress Ring — Chart/RingProgress ─────────────────────────────
class PulseRing extends StatelessWidget {
  const PulseRing({
    super.key, required this.value, required this.color, this.size = 64, this.stroke = 8,
    this.trackColor, this.child, this.animate = true, this.backgroundColor,
  });
  final double value; // 0..1+ (clamped visually at 1, over-target shown by child text)
  final Color color;
  final double size;
  final double stroke;
  final Color? trackColor;
  final Widget? child;
  final bool animate;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : value.clamp(0.0, 1.0), end: value.clamp(0.0, 1.0)),
      duration: PulseDuration.ringFill,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size, height: size,
        child: CustomPaint(
          painter: _RingPainter(progress: v, color: color,
              track: trackColor ?? (isDark ? PulseColors.darkElevated : PulseColors.lightSurfaceAlt),
              stroke: stroke, bg: backgroundColor),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track, required this.stroke, this.bg});
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  final Color? bg;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    if (bg != null) {
      canvas.drawCircle(center, radius + stroke / 2, Paint()..color = bg!);
    }
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(center.asRectWithRadius(radius), -math.pi / 2, 2 * math.pi * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

extension on Offset {
  Rect asRectWithRadius(double r) => Rect.fromCircle(center: this, radius: r);
}

// ── Horizontal bar — Chart/ProgressBar ─────────────────────────────
class PulseBar extends StatelessWidget {
  const PulseBar({super.key, required this.value, required this.color, this.height = 10, this.background});
  final double value;
  final Color color;
  final double height;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PulseRadius.full),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: PulseDuration.ringFill,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v, minHeight: height,
          backgroundColor: background ?? (isDark ? PulseColors.darkElevated : PulseColors.lightSurfaceAlt),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

// ── Macro row — Card/MacroProgress (bar + text always paired) ─────
class MacroRow extends StatelessWidget {
  const MacroRow({super.key, required this.label, required this.current, required this.goal, required this.color, required this.iconData, this.unit = 'g'});
  final String label;
  final double current;
  final double goal;
  final Color color;
  final IconData iconData;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(iconData, size: 16, color: color),
          const SizedBox(width: PulseSpacing.s),
          Text(label, style: theme.textTheme.titleMedium),
          const Spacer(),
          Text('${current.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: PulseSpacing.s),
        Semantics(
          label: '$label: ${current.toStringAsFixed(0)} of ${goal.toStringAsFixed(0)} $unit',
          child: PulseBar(value: current / goal, color: color, height: 8),
        ),
      ]),
    );
  }
}

// ── Donut chart — Chart/MacroDonut ─────────────────────────────────
class PulseDonut extends StatelessWidget {
  const PulseDonut({super.key, required this.segments, this.size = 120, this.stroke = 16, this.center});
  final List<({double value, Color color})> segments;
  final double size;
  final double stroke;
  final Widget? center;
  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, x) => s + x.value);
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(painter: _DonutPainter(segments, total, stroke,
            Theme.of(context).dividerColor), size: Size.square(size)),
        if (center != null) center!,
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.total, this.stroke, this.track);
  final List<({double value, Color color})> segments;
  final double total;
  final double stroke;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    double start = -math.pi / 2;
    for (final s in segments) {
      final sweep = 2 * math.pi * (s.value / (total == 0 ? 1 : total));
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start + 0.03, math.max(sweep - 0.06, 0.01),
          false, Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = stroke
            ..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.total != total;
}

// ── Line/Area chart — Chart/WeightTrend ────────────────────────────
class PulseLineChart extends StatelessWidget {
  const PulseLineChart({super.key, required this.points, this.goalY, this.color, this.area = true, this.height = 180, this.labels});
  final List<double> points;
  final double? goalY;
  final Color? color;
  final bool area;
  final double height;
  final List<String>? labels;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(points: points, color: c, goalY: goalY, area: area)),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.points, required this.color, this.goalY, this.area = true});
  final List<double> points;
  final Color color;
  final double? goalY;
  final bool area;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = (goalY != null ? math.min(points.reduce(math.min), goalY!) : points.reduce(math.min));
    final maxV = (goalY != null ? math.max(points.reduce(math.max), goalY!) : points.reduce(math.max));
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    Offset pt(int i) => Offset(
        size.width * i / (points.length - 1),
        size.height - ((points[i] - minV) / range) * (size.height - 16) - 8);
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = pt(i - 1), p1 = pt(i);
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    if (area) {
      final fill = Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(fill, Paint()
        ..shader = LinearGradient(colors: [color.withOpacity(0.22), color.withOpacity(0.02)])
            .createShader(Offset.zero & size));
    }
    if (goalY != null) {
      final y = size.height - ((goalY! - minV) / range) * (size.height - 16) - 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()
        ..color = color.withOpacity(0.4)
        ..strokeWidth = 1.4);
    }
    canvas.drawPath(line, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = color);
    final last = pt(points.length - 1);
    canvas.drawCircle(last, 5.5, Paint()..color = color);
    canvas.drawCircle(last, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points;
}

// ── Bar chart — Chart/CalorieBars ──────────────────────────────────
class PulseBarChart extends StatelessWidget {
  const PulseBarChart({super.key, required this.values, required this.labels, this.goal, this.height = 160, this.highlightIndex});
  final List<double> values;
  final List<String> labels;
  final double? goal;
  final double height;
  final int? highlightIndex;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
          painter: _BarPainter(values: values, goal: goal, color: c, highlight: highlightIndex)),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.values, this.goal, required this.color, this.highlight});
  final List<double> values;
  final double? goal;
  final Color color;
  final int? highlight;
  @override
  void paint(Canvas canvas, Size size) {
    final maxV = goal != null ? math.max(values.reduce(math.max), goal!) : values.reduce(math.max);
    final bw = size.width / values.length * 0.55;
    final gap = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final h = (values[i] / maxV) * (size.height - 10);
      final x = gap * i + (gap - bw) / 2;
      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - h, bw, h),
        topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
      );
      canvas.drawRRect(rrect, Paint()
        ..color = (highlight == i) ? color : color.withOpacity(0.35));
    }
    if (goal != null) {
      final y = size.height - (goal! / maxV) * (size.height - 10);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()
        ..color = PulseColors.accent
        ..strokeWidth = 1.6);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.values != values;
}

// ── Calendar heatmap — Chart/CalendarHeatmap ───────────────────────
class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({super.key, required this.levels, this.weekdayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S']});
  final List<double> levels; // 0..1 per day, last N days ending today
  final List<String> weekdayLabels;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final days = levels.length;
    return Wrap(
      spacing: PulseSpacing.s,
      runSpacing: PulseSpacing.s,
      children: [
        for (var i = 0; i < days; i++)
          Semantics(
            label: 'Day ${days - i}: ${(levels[i] * 100).round()}% of logging goal',
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: levels[i] <= 0
                    ? primary.withOpacity(0.07)
                    : primary.withOpacity(0.15 + 0.85 * levels[i]),
                borderRadius: BorderRadius.circular(PulseRadius.s),
              ),
              child: Center(
                  child: Text('${days - i}',
                      style: TextStyle(fontSize: 10.5, color: levels[i] > 0.55 ? Colors.white : null))),
            ),
          ),
      ],
    );
  }
}

// ── Trend indicator — Label/Trend ──────────────────────────────────
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.text, required this.up, this.invertColors = false});
  final String text;
  final bool up;
  final bool invertColors; // e.g. weight going down is good
  @override
  Widget build(BuildContext context) {
    final good = invertColors ? !up : up;
    final c = good ? PulseColors.success : PulseColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.s, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(PulseRadius.full)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

// ── Toast / Snackbar with Undo — Feedback/Snackbar ────────────────
class PulseToast {
  PulseToast._();
  static void show(BuildContext context, String message, {String? undoLabel, VoidCallback? onUndo, IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon ?? Icons.check_circle_rounded, color: PulseColors.success, size: 20),
          const SizedBox(width: PulseSpacing.s),
          Expanded(child: Text(message)),
        ]),
        action: undoLabel != null
            ? SnackBarAction(label: undoLabel, onPressed: onUndo ?? () {})
            : null,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.m)),
        backgroundColor: scheme.brightness == Brightness.dark ? PulseColors.darkElevated : const Color(0xFF22302C),
      ));
  }
}

// ── Skeleton loaders — Feedback/Skeleton ───────────────────────────
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = PulseRadius.s});
  final double height;
  final double? width;
  final double radius;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? PulseColors.darkSurfaceAlt : PulseColors.lightSurfaceAlt;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height, width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(colors: [base, base.withOpacity(0.45), base],
              begin: Alignment(-1 + 2 * _c.value, 0), end: Alignment(1 - 2 * _c.value, 0)),
        ),
      ),
    );
  }
}

/// Dashboard skeleton composition used while loading.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(PulseSpacing.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonBox(height: 26, width: 220),
          SizedBox(height: PulseSpacing.xl),
          SkeletonBox(height: 150, radius: PulseRadius.l),
          SizedBox(height: PulseSpacing.m),
          SkeletonBox(height: 120, radius: PulseRadius.l),
          SizedBox(height: PulseSpacing.m),
          SkeletonBox(height: 90, radius: PulseRadius.l),
        ]),
      );
}

// ── Empty state — Feedback/EmptyState ──────────────────────────────
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PulseSpacing.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(PulseSpacing.l),
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: PulseSpacing.l),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: PulseSpacing.s),
          Text(body, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: PulseSpacing.l),
            FilledButton(onPressed: onAction ?? () {}, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

// ── Offline banner — Feedback/Offline ──────────────────────────────
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.s),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.sm),
        decoration: BoxDecoration(
            color: PulseColors.warning.withOpacity(0.14),
            borderRadius: BorderRadius.circular(PulseRadius.m),
            border: Border.all(color: PulseColors.warning.withOpacity(0.5))),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: PulseColors.warning, size: 20),
          const SizedBox(width: PulseSpacing.s),
          Expanded(
            child: RichText(
              text: TextSpan(style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14), children: const [
                TextSpan(text: 'You\'re offline\n', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: 'Some recently viewed content is still available. New entries will sync when you\'re connected.', style: TextStyle(fontSize: 13)),
              ]),
            ),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try Again')),
        ]),
      );
}

// ── Health safety footnote (§86) ───────────────────────────────────
class HealthDisclaimer extends StatelessWidget {
  const HealthDisclaimer({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.l),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: PulseSpacing.s),
          Expanded(
            child: Text(
              'PULSE provides general fitness and nutrition information and is not a substitute for professional medical advice.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.4),
            ),
          ),
        ]),
      );
}

// ── Premium lock pill ──────────────────────────────────────────────
class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.label = 'Pro'});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0E7C6B), Color(0xFF14919B)]),
            borderRadius: BorderRadius.circular(PulseRadius.full)),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
      );
}

// ── Stepper — Input/Stepper ────────────────────────────────────────
class PulseStepper extends StatelessWidget {
  const PulseStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 999, this.step = 1, this.unit = ''});
  final double value;
  final ValueChanged<double> onChanged;
  final double min, max, step;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(PulseRadius.m)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _stepBtn(context, Icons.remove_rounded, () => onChanged((value - step).clamp(min, max))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m),
          child: Text('${value.toStringAsFixed(step < 1 ? 1 : 0)} $unit', style: PulseTypography.metricSmall),
        ),
        _stepBtn(context, Icons.add_rounded, () => onChanged((value + step).clamp(min, max))),
      ]),
    );
  }

  Widget _stepBtn(BuildContext context, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary)),
      );
}

// ── Segmented control — Input/SegmentedControl ─────────────────────
class PulseSegmented extends StatelessWidget {
  const PulseSegmented({super.key, required this.options, required this.index, required this.onChanged});
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.m)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onChanged(i); },
                child: AnimatedContainer(
                  duration: PulseDuration.fast,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: i == index ? (scheme.brightness == Brightness.dark ? PulseColors.darkElevated : Colors.white) : Colors.transparent,
                      borderRadius: BorderRadius.circular(PulseRadius.s),
                      boxShadow: i == index
                          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                          : null),
                  child: Center(
                      child: Text(options[i],
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                              color: i == index ? scheme.primary : scheme.onSurface.withOpacity(0.6)))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Goal option tile — Input/OptionTile (radio-style selection) ───
class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.title, required this.selected, this.subtitle, this.icon, required this.onTap, this.trailing});
  final String title;
  final bool selected;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '$title${subtitle != null ? '. $subtitle' : ''}',
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: AnimatedContainer(
          duration: PulseDuration.fast,
          margin: const EdgeInsets.only(bottom: PulseSpacing.s),
          padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withOpacity(0.08) : scheme.surface,
            borderRadius: BorderRadius.circular(PulseRadius.m),
            border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? PulseStroke.thick : PulseStroke.regular),
          ),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, color: selected ? scheme.primary : scheme.onSurface.withOpacity(0.55)), const SizedBox(width: PulseSpacing.sm)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme_title(context, selected)),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5)),
              ]),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline, size: 22),
          ]),
        ),
      ),
    );
  }

  static TextStyle theme_title(BuildContext c, bool sel) => TextStyle(
      fontSize: 16, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
      color: Theme.of(c).colorScheme.onSurface);
}

// ── Metric chip row used across dashboard cards ────────────────────
class MetricStat extends StatelessWidget {
  const MetricStat({super.key, required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)), const SizedBox(width: 4)],
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
        ]),
        const SizedBox(height: 2),
        Text(value, style: PulseTypography.metricSmall.copyWith(color: Theme.of(context).colorScheme.onSurface)),
      ]);
}
