import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/body_status_service.dart';

Color statusColor(StatusLevel level) {
  switch (level) {
    case StatusLevel.good:
      return AppTheme.mint;
    case StatusLevel.fair:
      return AppTheme.purple;
    case StatusLevel.watch:
      return AppTheme.rose;
    case StatusLevel.noData:
      return AppTheme.textMuted;
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
      return Icons.favorite_rounded;
    case 'Sleep':
      return Icons.bedtime_rounded;
    case 'Activity':
      return Icons.directions_run_rounded;
    case 'Cardio':
      return Icons.favorite_rounded;
    case 'Body':
      return Icons.monitor_weight_outlined;
    case 'Labs':
      return Icons.science_rounded;
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon(system.name), size: 17, color: color),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                system.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                system.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                system.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 8.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
