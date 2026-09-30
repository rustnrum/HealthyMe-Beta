import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
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
    final detected = app.health.detectedSources
        .map(_friendlySourceName)
        .where((name) => name.isNotEmpty && name != 'Health Connect')
        .toSet()
        .toList()
      ..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        HmSectionHeader(
          title: 'Connected Sources',
          action: 'See all',
          onAction: () => _push(context, const SourcesScreen()),
        ),
        const SizedBox(height: 8),
        CommandCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
          child: Column(
            children: [
              _SourceRow(
                name: 'Health Connect',
                subtitle: app.health.authorized
                    ? 'Connected • ${_lastSync(app)}'
                    : 'Android health-data hub',
                icon: Icons.health_and_safety_rounded,
                accent: AppTheme.cyan,
                connected: app.health.authorized,
                onTap: () => _push(context, const SourcesScreen()),
              ),
              for (final source in detected.take(4)) ...[
                const Divider(height: 1),
                _SourceRow(
                  name: source,
                  subtitle: 'Detected through Health Connect',
                  icon: _sourceIcon(source),
                  accent: _sourceColor(source),
                  connected: true,
                  onTap: () => _push(context, const SourcesScreen()),
                ),
              ],
              if (detected.isEmpty) ...[
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      HmIconBadge(
                        icon: Icons.sensors_off_rounded,
                        color: AppTheme.textMuted,
                        size: 34,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No vendor data source has been detected yet. Healthy Me will list real origins as Health Connect records arrive.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: const [
            _SupportChip('Samsung Health'),
            _SupportChip('Fitbit'),
            _SupportChip('Garmin'),
            _SupportChip('Withings'),
          ],
        ),
        const SizedBox(height: 18),
        HmSectionHeader(
          title: 'Your Plan',
          action: 'See all',
          onAction: () => _push(context, const PlanScreen()),
        ),
        const SizedBox(height: 8),
        for (final item in plan.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PlanRow(
              item: item,
              onTap: () => _push(context, const PlanScreen()),
            ),
          ),
        const SizedBox(height: 12),
        const HmSectionHeader(title: 'More tools'),
        const SizedBox(height: 8),
        CommandCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
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

  static String _friendlySourceName(String raw) {
    final value = raw.trim();
    final lower = value.toLowerCase();
    if (lower.contains('samsung')) return 'Samsung Health';
    if (lower.contains('fitbit')) return 'Fitbit';
    if (lower.contains('garmin')) return 'Garmin Connect';
    if (lower.contains('withings')) return 'Withings';
    if (lower.contains('health connect') ||
        lower.contains('com.google.android.apps.healthdata')) {
      return 'Health Connect';
    }
    if (lower.contains('google fit')) return 'Google Fit';
    return value;
  }

  static IconData _sourceIcon(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('samsung')) return Icons.directions_run_rounded;
    if (lower.contains('fitbit')) return Icons.watch_rounded;
    if (lower.contains('garmin')) return Icons.navigation_rounded;
    if (lower.contains('withings')) return Icons.monitor_weight_outlined;
    return Icons.sensors_rounded;
  }

  static Color _sourceColor(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('samsung')) return AppTheme.mint;
    if (lower.contains('fitbit')) return AppTheme.cyan;
    if (lower.contains('garmin')) return AppTheme.textPrimary;
    if (lower.contains('withings')) return AppTheme.blue;
    return AppTheme.purple;
  }

  String _lastSync(HealthyMeState app) {
    final sync = app.health.lastSync;
    if (sync == null) return 'Not synced yet';
    final now = DateTime.now();
    final sameDay = sync.year == now.year &&
        sync.month == now.month &&
        sync.day == now.day;
    if (sameDay) {
      final hour = sync.hour % 12 == 0 ? 12 : sync.hour % 12;
      final minute = sync.minute.toString().padLeft(2, '0');
      final suffix = sync.hour >= 12 ? 'PM' : 'AM';
      return 'Last sync: Today, $hour:$minute $suffix';
    }
    return 'Last sync: ${sync.month}/${sync.day}/${sync.year}';
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _SourceRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool connected;
  final VoidCallback onTap;

  const _SourceRow({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            HmIconBadge(icon: icon, color: accent, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            HmStatusPill(
              text: connected ? 'Connected' : 'Connect',
              color: connected ? AppTheme.mint : AppTheme.rose,
            ),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SupportChip extends StatelessWidget {
  final String label;

  const _SupportChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '$label • via Health Connect',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
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
          HmIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 9.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
