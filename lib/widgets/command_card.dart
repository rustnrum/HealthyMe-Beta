import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class CommandCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final BorderRadius? borderRadius;

  const CommandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(22);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? AppTheme.glassGradient : null,
        borderRadius: radius,
        border: border ?? Border.all(color: AppTheme.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withValues(alpha: 0.035),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}
