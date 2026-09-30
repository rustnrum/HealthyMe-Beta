import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import 'goals_screen.dart';
import 'heart_screen.dart';
import 'labs_screen.dart';
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
    final sources = app.health.detectedSources;

    final providers = <_ProviderDisplay>[
      _ProviderDisplay(
        name: 'Health Connect',
        icon: Icons.health_and_safety_rounded,
        color: AppTheme.cyan,
        connected: app.health.authorized,
        subtitle: app.health.authorized
            ? _lastSync(app)
            : 'Android health-data hub',
      ),
      _ProviderDisplay(
        name: 'Samsung Health',
        icon: Icons.directions_run_rounded,
        color: AppTheme.mint,
        connected: SourceNameService.detected(sources, 'Samsung Health'),
        subtitle: SourceNameService.detected(sources, 'Samsung Health')
            ? 'Connected through Health Connect'
            : 'No data detected yet',
      ),
      _ProviderDisplay(
        name: 'Garmin Connect',
        icon: Icons.navigation_rounded,
        color: AppTheme.textPrimary,
        connected: SourceNameService.detected(sources, 'Garmin Connect'),
        subtitle: SourceNameService.detected(sources, 'Garmin Connect')
            ? 'Connected through Health Connect'
            : 'No data detected yet',
      ),
      _ProviderDisplay(
        name: 'Fitbit',
        icon: Icons.watch_rounded,
        color: AppTheme.cyan,
        connected: SourceNameService.detected(sources, 'Fitbit'),
        subtitle: SourceNameService.detected(sources, 'Fitbit')
            ? 'Connected through Health Connect'
            : 'No data detected yet',
      ),
      _ProviderDisplay(
        name: 'Withings Scale',
        icon: Icons.monitor_weight_outlined,
        color: AppTheme.blue,
        connected: SourceNameService.detected(sources, 'Withings Scale'),
        subtitle: SourceNameService.detected(sources, 'Withings Scale')
            ? 'Connected through Health Connect'
            : 'No data detected yet',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        HmSectionHeader(
          title: 'Connected Sources',
          action: 'See all',
          onAction: () => _push(context, const SourcesScreen()),
        ),
        const SizedBox(height: 10),
        CommandCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          child: Column(
            children: [
              for (var i = 0; i < providers.length; i++) ...[
                _SourceRow(
                  provider: providers[i],
                  onTap: () => _push(context, const SourcesScreen()),
                ),
                if (i != providers.length - 1) const Divider(height: 1),
              ],
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
                icon: Icons.favorite_rounded,
                color: AppTheme.rose,
                title: 'Heart Health',
                subtitle: 'Resting HR, HRV, oxygen and respiratory data',
                onTap: () => _push(context, const HeartScreen()),
              ),
              const Divider(height: 1),
              _ToolRow(
                icon: Icons.science_rounded,
                color: AppTheme.amber,
                title: 'Bloodwork',
                subtitle: 'Raw results, history and freshness',
                onTap: () => _push(context, const LabsScreen()),
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

  String _lastSync(HealthyMeState app) {
    final sync = app.health.lastSync;
    if (sync == null) return 'Connected • not synced yet';
    final now = DateTime.now();
    final sameDay = sync.year == now.year &&
        sync.month == now.month &&
        sync.day == now.day;
    if (sameDay) {
      final hour = sync.hour % 12 == 0 ? 12 : sync.hour % 12;
      final minute = sync.minute.toString().padLeft(2, '0');
      final suffix = sync.hour >= 12 ? 'PM' : 'AM';
      return 'Connected • Last sync: Today, $hour:$minute $suffix';
    }
    return 'Connected • Last sync: ${sync.month}/${sync.day}/${sync.year}';
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ProviderDisplay {
  final String name;
  final IconData icon;
  final Color color;
  final bool connected;
  final String subtitle;

  const _ProviderDisplay({
    required this.name,
    required this.icon,
    required this.color,
    required this.connected,
    required this.subtitle,
  });
}

class _SourceRow extends StatelessWidget {
  final _ProviderDisplay provider;
  final VoidCallback onTap;

  const _SourceRow({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            HmIconBadge(icon: provider.icon, color: provider.color, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HmStatusPill(
              text: provider.connected ? 'Connected' : 'Not detected',
              color: provider.connected ? AppTheme.mint : AppTheme.rose,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 22),
          ],
        ),
      ),
    );
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
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 22),
        ],
      ),
    );
  }

  Color _color(String category) {
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

  IconData _icon(String category) {
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
        return Icons.sensors_rounded;
    }
  }
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
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 13),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
