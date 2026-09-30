import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final plan = PlanService.build(app);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Plan',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s context',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    Chip(label: Text(app.profile.primaryGoal)),
                    Chip(label: Text(app.profile.activityLevel)),
                    Chip(
                      label: Text(
                        app.health.authorized
                            ? 'Health Connect active'
                            : 'Health Connect not connected',
                      ),
                    ),
                    Chip(label: Text('${app.labs.length} labs')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...plan.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: CommandCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          _color(item.category).withValues(alpha: 0.14),
                      child: Icon(
                        _icon(item.category),
                        color: _color(item.category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.category.toUpperCase(),
                            style: TextStyle(
                              color: _color(item.category),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(item.detail),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Healthy Me provides wellness suggestions, not diagnosis or treatment. Medical symptoms and abnormal results belong with a qualified clinician.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
        return Icons.bedtime_outlined;
      case 'Training':
        return Icons.directions_run;
      case 'Nutrition':
        return Icons.restaurant_outlined;
      case 'Labs':
        return Icons.science_outlined;
      default:
        return Icons.sensors_outlined;
    }
  }
}
