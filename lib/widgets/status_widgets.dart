import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/body_status_service.dart';

Color statusColor(StatusLevel level) {
  switch (level) {
    case StatusLevel.good:
      return AppTheme.mint;
    case StatusLevel.fair:
      return AppTheme.amber;
    case StatusLevel.watch:
      return AppTheme.rose;
    case StatusLevel.noData:
      return const Color(0xFF7895A2);
  }
}

String statusText(StatusLevel level) {
  switch (level) {
    case StatusLevel.good:
      return 'Good';
    case StatusLevel.fair:
      return 'Fair';
    case StatusLevel.watch:
      return 'Watch';
    case StatusLevel.noData:
      return 'No data';
  }
}

IconData statusIcon(String name) {
  switch (name) {
    case 'Recovery':
      return Icons.eco_outlined;
    case 'Sleep':
      return Icons.bedtime_outlined;
    case 'Activity':
      return Icons.directions_run;
    case 'Cardio':
      return Icons.favorite_outline;
    case 'Body':
      return Icons.accessibility_new;
    case 'Labs':
      return Icons.science_outlined;
    default:
      return Icons.monitor_heart_outlined;
  }
}

class SubsystemTile extends StatelessWidget {
  final SubsystemStatus system;
  final VoidCallback? onTap;

  const SubsystemTile({
    super.key,
    required this.system,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(system.level);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon(system.name), size: 19, color: color),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              system.name,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Text(
              system.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              system.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class TinyStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const TinyStatusPill({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
