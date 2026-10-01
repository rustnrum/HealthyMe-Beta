import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/body_status_service.dart';
import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import '../widgets/status_widgets.dart';

class BodyStatusDetailScreen extends ConsumerWidget {
  const BodyStatusDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final report = BodyStatusService.build(app);
    final actions = PlanService.build(app).take(4).toList();
    final color = _overallColor(report.overall);
    final issues = report.changes
        .where((change) => change.level == StatusLevel.fair || change.level == StatusLevel.watch)
        .toList();
    final positives = report.systems.where((system) => system.level == StatusLevel.good).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Body Status')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'lib/assets/images/hero_mountains.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.backgroundDeep.withValues(alpha: 0.48),
                          AppTheme.backgroundDeep.withValues(alpha: 0.78),
                          AppTheme.backgroundDeep.withValues(alpha: 0.93),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 102,
                        height: 102,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: report.overall == 'Limited data' ? 0.35 : 0.82,
                              strokeWidth: 9,
                              strokeCap: StrokeCap.round,
                              color: color,
                              backgroundColor: Colors.white.withValues(alpha: 0.13),
                            ),
                            Icon(Icons.eco_rounded, color: color, size: 42),
                          ],
                        ),
                      ),
                      const SizedBox(width: 17),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overall status',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              report.overall,
                              style: TextStyle(
                                color: color,
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              report.summary,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: "What's affecting your status"),
          const SizedBox(height: 10),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: issues.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No meaningful negative changes are standing out from your current baseline.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < issues.length; i++) ...[
                        _DetailRow(
                          icon: _iconFor(issues[i].title),
                          color: statusColor(issues[i].level),
                          title: issues[i].title,
                          detail: issues[i].detail,
                        ),
                        if (i != issues.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Positive signals'),
          const SizedBox(height: 10),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                if (positives.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Healthy Me is still building enough baseline data to call out strong positive signals.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < positives.length; i++) ...[
                    _DetailRow(
                      icon: statusIcon(positives[i].name),
                      color: AppTheme.mint,
                      title: '${positives[i].name}: ${positives[i].value}',
                      detail: positives[i].detail,
                    ),
                    if (i != positives.length - 1) const Divider(height: 1),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Suggested actions today'),
          const SizedBox(height: 10),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  _DetailRow(
                    icon: _actionIcon(actions[i].category),
                    color: _actionColor(actions[i].category),
                    title: actions[i].title,
                    detail: actions[i].detail,
                  ),
                  if (i != actions.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nutrition is not used to lower or raise Body Status until the Diet section has real meal data. Healthy Me will not guess that a meal was missed.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Color _overallColor(String value) {
    switch (value) {
      case 'Good':
        return AppTheme.mint;
      case 'Fair':
        return AppTheme.purple;
      case 'Watch':
        return AppTheme.rose;
      default:
        return AppTheme.cyan;
    }
  }

  static IconData _iconFor(String title) {
    final value = title.toLowerCase();
    if (value.contains('sleep')) return Icons.bedtime_rounded;
    if (value.contains('activity')) return Icons.directions_run_rounded;
    if (value.contains('heart')) return Icons.favorite_rounded;
    if (value.contains('breathing')) return Icons.air_rounded;
    if (value.contains('weight')) return Icons.monitor_weight_outlined;
    return Icons.insights_rounded;
  }

  static IconData _actionIcon(String category) {
    switch (category) {
      case 'Sleep':
        return Icons.bedtime_rounded;
      case 'Training':
        return Icons.directions_run_rounded;
      case 'Nutrition':
        return Icons.restaurant_rounded;
      case 'Labs':
        return Icons.science_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  static Color _actionColor(String category) {
    switch (category) {
      case 'Sleep':
        return AppTheme.purple;
      case 'Training':
        return AppTheme.mint;
      case 'Nutrition':
        return AppTheme.amber;
      case 'Labs':
        return AppTheme.cyan;
      default:
        return AppTheme.cyan;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  const _DetailRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
