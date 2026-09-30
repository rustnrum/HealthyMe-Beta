import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _range = 'Day';

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final health = app.health;
    final goal = app.profile.stepGoal <= 0 ? 10000 : app.profile.stepGoal;
    final progress = (health.stepsToday / goal).clamp(0.0, 1.0);
    final now = DateTime.now();
    final todayWorkouts = health.workouts.where((w) {
      return w.start.year == now.year &&
          w.start.month == now.month &&
          w.start.day == now.day;
    }).toList();
    final activeMinutes = todayWorkouts.fold<int>(0, (sum, w) => sum + w.minutes);

    final chartValues = switch (_range) {
      'Day' => health.hourlySteps,
      'Week' => _tail(health.dailySteps30, 7),
      'Month' => health.dailySteps30,
      _ => health.monthlySteps12,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        HmTabs(
          labels: const ['Day', 'Week', 'Month', 'Year'],
          selected: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
            Expanded(
              child: Text(
                _dateLabel(now),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
        const SizedBox(height: 10),
        CommandCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  const HmIconBadge(
                    icon: Icons.directions_walk_rounded,
                    color: AppTheme.cyan,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          health.authorized
                              ? compactNumber(health.stepsToday)
                              : '—',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'of ${compactNumber(goal)} steps',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    health.authorized ? '${(progress * 100).round()}%' : '—',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: health.authorized ? progress : 0,
                  minHeight: 8,
                  color: AppTheme.cyan,
                  backgroundColor: AppTheme.surfaceHigh,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _range == 'Day' ? 'Steps through the day' : 'Step trend',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (_range == 'Year' && !health.historicalAccess)
                    const Text(
                      'History access needed',
                      style: TextStyle(
                        color: AppTheme.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SimpleBarChart(
                values: chartValues,
                target: _range == 'Day' ? null : goal.toDouble(),
                showTarget: _range == 'Week' || _range == 'Month',
                height: 150,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: HmMetricCard(
                label: 'Distance',
                value: health.authorized
                    ? '${health.distanceMilesToday.toStringAsFixed(1)} mi'
                    : '—',
                accent: AppTheme.cyan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HmMetricCard(
                label: 'Active calories',
                value: health.authorized
                    ? '${health.activeCaloriesToday.round()} cal'
                    : '—',
                accent: AppTheme.mint,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HmMetricCard(
                label: 'Active time',
                value: activeMinutes > 0 ? '$activeMinutes min' : '—',
                accent: AppTheme.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        HmSectionHeader(
          title: 'Workouts',
          action: health.authorized ? null : 'Connect',
          onAction: health.authorized
              ? null
              : () => ref.read(healthSyncProvider.notifier).connectAndSync(),
        ),
        const SizedBox(height: 8),
        if (health.workouts.isEmpty)
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.directions_run_rounded,
              title: 'No workout history yet',
              detail: 'Connected workout sessions will appear here automatically.',
            ),
          )
        else
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
            child: Column(
              children: [
                for (var i = 0; i < health.workouts.take(4).length; i++) ...[
                  _WorkoutRow(workout: health.workouts[i]),
                  if (i != health.workouts.take(4).length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 18),
        const HmSectionHeader(title: 'Weekly activity'),
        const SizedBox(height: 8),
        CommandCard(
          child: SimpleBarChart(
            values: _tail(health.dailySteps30, 7),
            target: goal.toDouble(),
            showTarget: true,
            height: 125,
          ),
        ),
      ],
    );
  }

  List<T> _tail<T>(List<T> values, int count) {
    if (values.length <= count) return values;
    return values.sublist(values.length - count);
  }

  String _dateLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _WorkoutRow extends StatelessWidget {
  final WorkoutEntry workout;

  const _WorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.directions_run_rounded,
            color: AppTheme.mint,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.type,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shortDate(workout.start)} • ${workout.minutes} min • ${workout.source}',
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
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
