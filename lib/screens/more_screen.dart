import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/status_widgets.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'More',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        CommandCard(
          onTap: () => _push(context, const SourcesScreen()),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x2217C8F4),
                child: Icon(
                  Icons.hub_outlined,
                  color: AppTheme.cyan,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Sources',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text('Health Connect, detected origins and metric routing'),
                  ],
                ),
              ),
              TinyStatusPill(
                text: app.health.authorized ? 'Connected' : 'Setup',
                color:
                    app.health.authorized ? AppTheme.mint : AppTheme.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Your Plan',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _push(context, const PlanScreen()),
              child: const Text('See all'),
            ),
          ],
        ),
        ...plan.take(3).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CommandCard(
                  onTap: () => _push(context, const PlanScreen()),
                  child: Row(
                    children: [
                      Icon(
                        item.category == 'Sleep'
                            ? Icons.bedtime_outlined
                            : item.category == 'Training'
                                ? Icons.directions_run
                                : Icons.restaurant_outlined,
                        color: item.category == 'Sleep'
                            ? AppTheme.purple
                            : item.category == 'Training'
                                ? AppTheme.mint
                                : AppTheme.amber,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              item.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 10),
        Text(
          'Command center',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        _menu(
          context,
          icon: Icons.favorite_outline,
          title: 'Heart Health',
          subtitle: 'Resting HR, trend, HRV, oxygen and respiratory data',
          onTap: () => _push(context, const HeartScreen()),
        ),
        _menu(
          context,
          icon: Icons.science_outlined,
          title: 'Labs',
          subtitle: 'Bloodwork history and freshness',
          onTap: () => _push(context, const LabsScreen()),
        ),
        _menu(
          context,
          icon: Icons.track_changes,
          title: 'Goals & Progress',
          subtitle: 'Weight, steps, sleep target and workouts',
          onTap: () => _push(context, const GoalsScreen()),
        ),
        _menu(
          context,
          icon: Icons.photo_camera_back_outlined,
          title: 'Progress Photos',
          subtitle: 'Front, side and back history',
          onTap: () => _push(context, const PhotosScreen()),
        ),
        _menu(
          context,
          icon: Icons.account_circle_outlined,
          title: 'Profile',
          subtitle: 'Personal information and goals',
          onTap: () => _push(context, const ProfileScreen()),
        ),
        _menu(
          context,
          icon: Icons.hub_outlined,
          title: 'Devices & Sources',
          subtitle: 'Connect and route health data',
          onTap: () => _push(context, const SourcesScreen()),
        ),
      ],
    );
  }

  Widget _menu(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CommandCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppTheme.cyan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
