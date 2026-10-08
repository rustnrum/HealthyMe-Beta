import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import 'connections_screen.dart';
import 'goals_screen.dart';
import 'photos_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final plan = PlanService.build(state);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 34), children: [
      const HmSectionHeader(title: 'Connections and data'),
      const SizedBox(height: 10),
      _link(context, 'Devices & Sources', 'Nearby wearable discovery starts automatically',
          Icons.bluetooth_searching_rounded, AppTheme.cyan,
          () => Navigator.of(context).pushNamed('/auto-discover')),
      const SizedBox(height: 9),
      _link(context, 'My saved devices', 'Device images, local readers and battery readings',
          Icons.devices_other_rounded, AppTheme.blue,
          () => Navigator.of(context).pushNamed('/device-gallery')),
      const SizedBox(height: 9),
      _link(context, 'Automatic wearable discovery',
        'Find, inspect and match nearby Bluetooth devices automatically',
        Icons.bluetooth_searching_rounded, AppTheme.mint,
        () => Navigator.of(context).pushNamed('/auto-discover')),
      const SizedBox(height: 9),
      _link(context, 'Source settings', 'Manage connections and choose a source per metric',
        Icons.settings_input_antenna_rounded, AppTheme.purple,
        () => _push(context, const ConnectionsScreen())),
      const SizedBox(height: 22),
      HmSectionHeader(title: 'Your plan', action: 'See all',
          onAction: () => _push(context, const PlanScreen())),
      const SizedBox(height: 10),
      for (final item in plan.take(3)) ...[
        _link(context, item.title, item.detail, _planIcon(item.category),
          AppTheme.mint, () => _openPlanItem(context, item.category)),
        const SizedBox(height: 9),
      ],
      const SizedBox(height: 19),
      const HmSectionHeader(title: 'More tools'),
      const SizedBox(height: 10),
      _link(context, 'Health and Vitals', 'Individual history charts and bloodwork',
          Icons.monitor_heart_outlined, AppTheme.rose,
          () => Navigator.of(context).pushNamed('/health')),
      const SizedBox(height: 9),
      _link(context, 'Body measurements', 'Illustration, tape measurements, and measured composition',
          Icons.accessibility_new_rounded, AppTheme.mint,
          () => Navigator.of(context).pushNamed('/body-visual')),
      const SizedBox(height: 9),
      _link(context, 'Goals & Progress', 'Weight, sleep, steps and workout goals',
          Icons.track_changes_rounded, AppTheme.mint,
          () => _push(context, const GoalsScreen())),
      const SizedBox(height: 9),
      _link(context, 'Progress Photos', 'Front, side and back history',
          Icons.photo_camera_back_rounded, AppTheme.purple,
          () => _push(context, const PhotosScreen())),
      const SizedBox(height: 9),
      _link(context, 'Profile & Settings', 'Personal information and preferences',
          Icons.person_rounded, AppTheme.cyan,
          () => _push(context, const ProfileScreen())),
    ]);
  }

  Widget _link(BuildContext context, String title, String subtitle,
      IconData icon, Color tint, VoidCallback onTap) => CommandCard(
    onTap: onTap,
    child: Row(children: [
      HmIconBadge(icon: icon, color: tint, size: 44),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
        ])),
      const SizedBox(width: 8),
      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
    ]),
  );

  IconData _planIcon(String category) => switch (category) {
    'Sleep' => Icons.bedtime_rounded,
    'Activity' => Icons.directions_walk_rounded,
    'Body' => Icons.accessibility_new_rounded,
    'Training' => Icons.fitness_center_rounded,
    'Nutrition' => Icons.restaurant_rounded,
    'Recovery' => Icons.bolt_rounded,
    'Labs' => Icons.science_outlined,
    _ => Icons.track_changes_rounded,
  };

  void _openPlanItem(BuildContext context, String category) {
    switch (category) {
      case 'Training':
        Navigator.of(context).pushNamed('/workout');
        break;
      case 'Nutrition':
        Navigator.of(context).pushNamed('/diet');
        break;
      case 'Recovery':
        Navigator.of(context).pushNamed('/recovery');
        break;
      case 'Labs':
        Navigator.of(context).pushNamed('/labs');
        break;
      case 'Data':
        Navigator.of(context).pushNamed('/sources');
        break;
      case 'Body':
        Navigator.of(context).pushNamed('/body-visual');
        break;
      case 'Sleep':
        Navigator.of(context).pushNamed('/sleep-detail');
        break;
      case 'Activity':
        Navigator.of(context).pushNamed('/activity-detail');
        break;
      default:
        _push(context, const PlanScreen());
    }
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
