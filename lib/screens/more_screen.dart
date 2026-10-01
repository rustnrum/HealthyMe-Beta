import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import 'goals_screen.dart';
import 'photos_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'sources_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final plan = PlanService.build(app);
    final sourceCount = SourceNameService.uniqueRawByFriendly(
      app.health.availableSources.values.expand((sources) => sources),
    ).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        HmSectionHeader(
          title: 'Data Sources',
          action: 'Manage',
          onAction: () => _push(context, const SourcesScreen()),
        ),
        const SizedBox(height: 10),
        CommandCard(
          onTap: () => _push(context, const SourcesScreen()),
          child: Row(
            children: [
              const HmIconBadge(
                icon: Icons.health_and_safety_rounded,
                color: AppTheme.cyan,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health Connect',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.health.authorized
                          ? '${_lastRefresh(app)} • $sourceCount source${sourceCount == 1 ? '' : 's'} available'
                          : 'Connect once, then choose one simple source per metric.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        HmSectionHeader(
          title: 'Your Plan',
          action: 'See all',
          onAction: () => _push(context, const PlanScreen()),
        ),
        const SizedBox(height: 10),
        for (final item in plan.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanRow(
              item: item,
              onTap: () => _push(context, const PlanScreen()),
            ),
          ),
        const SizedBox(height: 14),
        const HmSectionHeader(title: 'More tools'),
        const SizedBox(height: 10),
        CommandCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          child: Column(
            children: [
              _ToolRow(
                icon: Icons.health_and_safety_rounded,
                color: AppTheme.purple,
                title: 'Health',
                subtitle: 'Vitals and bloodwork in one section',
                onTap: () => Navigator.of(context).pushNamed('/health'),
              ),
              const Divider(height: 1),
              _ToolRow(
                icon: Icons.track_changes_rounded,
                color: AppTheme.mint,
                title: 'Goals & Progress',
                subtitle: 'Weight, steps, sleep and workout goals',
                onTap: () => _push(context, const GoalsScreen()),
              ),
              const Divider(height: 1),
              _ToolRow(
                icon: Icons.photo_camera_back_rounded,
                color: AppTheme.purple,
                title: 'Progress Photos',
                subtitle: 'Front, side and back history',
                onTap: () => _push(context, const PhotosScreen()),
              ),
              const Divider(height: 1),
              _ToolRow(
                icon: Icons.person_rounded,
                color: AppTheme.cyan,
                title: 'Profile & Settings',
                subtitle: 'Personal information and preferences',
                onTap: () => _push(context, const ProfileScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _lastRefresh(HealthyMeState app) {
    final sync = app.health.lastSync;
    if (sync == null) return 'Not refreshed yet';
    final now = DateTime.now();
    final sameDay = sync.year == now.year &&
        sync.month == now.month &&
        sync.day == now.day;
    if (sameDay) {
      final hour = sync.hour % 12 == 0 ? 12 : sync.hour % 12;
      final minute = sync.minute.toString().padLeft(2, '0');
      final suffix = sync.hour >= 12 ? 'PM' : 'AM';
      return 'Refreshed today $hour:$minute $suffix';
    }
    return 'Refreshed ${sync.month}/${sync.day}/${sync.year}';
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _PlanRow extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onTap;

  const _PlanRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _color(item.category);
    final icon = _icon(item.category);
    return CommandCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(icon: icon, color: color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMuted,
            size: 22,
          ),
        ],
      ),
    );
  }

  Color _color(String category) => switch (category) {
        'Sleep' => AppTheme.purple,
        'Activity' => AppTheme.cyan,
        'Body' => AppTheme.mint,
        'Recovery' => AppTheme.amber,
        _ => AppTheme.cyan,
      };

  IconData _icon(String category) => switch (category) {
        'Sleep' => Icons.bedtime_rounded,
        'Activity' => Icons.directions_walk_rounded,
        'Body' => Icons.monitor_weight_outlined,
        'Recovery' => Icons.bolt_rounded,
        _ => Icons.track_changes_rounded,
      };
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            HmIconBadge(icon: icon, color: color, size: 42),
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
