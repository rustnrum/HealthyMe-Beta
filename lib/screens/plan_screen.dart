import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final plan = PlanService.build(app);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s context',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _ContextPill(app.profile.primaryGoal),
                    _ContextPill(app.profile.activityLevel),
                    _ContextPill(
                      app.health.authorized
                          ? 'Health Connect active'
                          : 'Health Connect not connected',
                    ),
                    _ContextPill('${app.labs.length} labs'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const HmSectionHeader(title: 'Suggestions'),
          const SizedBox(height: 8),
          for (final item in plan)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlanCard(item: item),
            ),
          const SizedBox(height: 6),
          const Text(
            'Healthy Me provides wellness suggestions, not diagnosis or treatment. Medical symptoms and abnormal results belong with a qualified clinician.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  final String text;

  const _ContextPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanItem item;

  const _PlanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _color(item.category);
    return CommandCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(
            icon: _icon(item.category),
            color: color,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
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
