import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class HmSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const HmSectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: AppTheme.section,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.45,
            ),
          ),
        ),
        if (action != null)
          onAction == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(action!, style: const TextStyle(color: AppTheme.cyan, fontSize: 14, fontWeight: FontWeight.w700)),
                )
              : TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class HmTabs extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;

  const HmTabs({super.key, required this.labels, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected == label
                        ? const LinearGradient(colors: [Color(0xFF153240), Color(0xFF203E4B)])
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    border: selected == label ? Border.all(color: AppTheme.cyan.withValues(alpha: 0.45)) : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected == label ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HmMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final String? detail;
  final IconData? icon;

  const HmMetricCard({super.key, required this.label, required this.value, required this.accent, this.detail, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(height: 9),
          ],
          Text(label, maxLines: 2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(detail!, maxLines: 3, softWrap: true, style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class HmIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const HmIconBadge({super.key, required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 14)],
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class HmStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const HmStatusPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
    );
  }
}

class HmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const HmEmptyState({super.key, required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          HmIconBadge(icon: icon, color: AppTheme.cyan, size: 48),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4)),
        ],
      ),
    );
  }
}
