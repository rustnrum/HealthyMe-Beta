import 'package:flutter/material.dart';
import '../theme.dart';

class SCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  const SCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.borderColor,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [C.cardTop, C.card],
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? C.border, width: 1),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

/// Icon + title row with a trailing chevron, used at the top of most cards.
class CardHeader extends StatelessWidget {
  final Widget icon;
  final String title;
  final bool chevron;
  final Widget? trailing;
  const CardHeader({super.key, required this.icon, required this.title, this.chevron = true, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      icon,
      const SizedBox(width: 8),
      Text(title, style: ts(15, w: 500)),
      if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      const Spacer(),
      if (chevron) const Icon(Icons.chevron_right_rounded, color: C.sub, size: 22),
    ]);
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool filled;
  const IconBadge(this.icon, this.color, {super.key, this.size = 22, this.filled = false});
  @override
  Widget build(BuildContext context) {
    if (!filled) return Icon(icon, color: color, size: size);
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .18)),
      child: Icon(icon, color: color, size: size * .75),
    );
  }
}

class Delta extends StatelessWidget {
  final bool up;
  final String text;
  const Delta({super.key, required this.up, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(up ? '↑ ' : '↓ ', style: ts(12, w: 600, color: C.green)),
      Flexible(child: Text(text, style: ts(12, color: C.sub), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

/// A "value + unit" line like 7h 48m or 54 bpm.
class BigValue extends StatelessWidget {
  final List<List<String>> parts; // [text, 'big'|'unit']
  final double big;
  final double unit;
  const BigValue({super.key, required this.parts, this.big = 34, this.unit = 17});
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        for (final p in parts)
          TextSpan(
            text: p[0],
            style: p[1] == 'big' ? ts(big, w: 600, h: 1.1) : ts(unit, w: 400, color: Colors.white.withValues(alpha: .85), h: 1.1),
          ),
      ]),
    );
  }
}

/// Plot image with y-axis labels on the left and x-axis labels underneath.
/// [yFrac] are label positions as a 0..1 fraction of the plot height (0 = top).
class ChartPanel extends StatelessWidget {
  final String asset;
  final double aspect;
  final List<String> yLabels;
  final List<double> yFrac;
  final List<String> xLabels;
  final String? badge;
  final double badgeX; // 0..1 across the plot
  final double badgeY; // 0..1 down the plot
  final Color badgeColor;
  const ChartPanel({
    super.key,
    required this.asset,
    required this.aspect,
    required this.yLabels,
    required this.yFrac,
    required this.xLabels,
    this.badge,
    this.badgeX = 0.93,
    this.badgeY = 0.2,
    this.badgeColor = C.green,
  });

  @override
  Widget build(BuildContext context) {
    const labelW = 34.0;
    return LayoutBuilder(builder: (context, c) {
      final plotW = c.maxWidth - labelW;
      final plotH = plotW / aspect;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: plotH,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: labelW, top: 0, width: plotW, height: plotH,
              child: Image.asset(asset, fit: BoxFit.fill, filterQuality: FilterQuality.high),
            ),
            for (var i = 0; i < yLabels.length; i++)
              Positioned(
                left: 0, width: labelW - 6, top: yFrac[i] * plotH - 7,
                child: Text(yLabels[i], textAlign: TextAlign.right, style: ts(11, color: C.sub)),
              ),
            if (badge != null)
              Positioned(
                left: labelW + badgeX * plotW - 22,
                top: badgeY * plotH - 34,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: .7)),
                  ),
                  child: Text(badge!, style: ts(11, w: 600)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          const SizedBox(width: labelW),
          for (final l in xLabels)
            Expanded(child: Center(child: Text(l, style: ts(11, color: C.sub)))),
        ]),
      ]);
    });
  }
}
