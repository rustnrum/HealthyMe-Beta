import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SalusPaper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  const SalusPaper({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF9F0DE), Color(0xFFF0E0C2)]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75), width: 0.9),
        boxShadow: [BoxShadow(color: AppTheme.backgroundDeep.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15), child: box));
  }
}

class SalusSectionTitle extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;
  const SalusSectionTitle({super.key, required this.title, this.eyebrow, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.1)),
          const SizedBox(height: 3),
        ],
        Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ])),
      if (trailing != null) trailing!,
    ]);
  }
}

class SalusMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  const SalusMetric({super.key, required this.icon, required this.value, required this.label, this.tint = AppTheme.mint});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.16)), child: Icon(icon, color: tint, size: 23)),
    const SizedBox(height: 8),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 2),
    Text(label.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
  ]);
}

class SalusModuleRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String line1;
  final String? line2;
  final VoidCallback? onTap;
  const SalusModuleRow({super.key, required this.icon, required this.tint, required this.title, required this.line1, this.line2, this.onTap});
  @override
  Widget build(BuildContext context) => SalusPaper(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    child: Row(children: [
      Container(width: 54, height: 54, decoration: BoxDecoration(color: tint.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(12), border: Border.all(color: tint.withValues(alpha: 0.30))), child: Icon(icon, color: tint, size: 27)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 21, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(line1, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14.5)),
        if (line2 != null) Text(line2!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
    ]),
  );
}

class SalusStatusDot extends StatelessWidget {
  final Color color;
  final String label;
  const SalusStatusDot({super.key, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 5),
    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
  ]);
}
