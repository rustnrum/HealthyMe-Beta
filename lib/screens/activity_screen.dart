import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/source_name_service.dart';
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

    final selectedStepSource = app.metricSources['Steps'];
    final stepSourceLabel = selectedStepSource == null || selectedStepSource == 'Auto'
        ? 'Health Connect recommended'
        : SourceNameService.friendly(selectedStepSource);
    final stepFreshness = health.freshness['Steps'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        HmTabs(
          labels: const ['Day', 'Week', 'Month', 'Year'],
          selected: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 12),
        _DateNavigator(label: _dateLabel(now)),
        const SizedBox(height: 12),
        CommandCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const HmIconBadge(
                    icon: Icons.directions_walk_rounded,
                    color: AppTheme.cyan,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.65,
                          ),
                        ),
                        Text(
                          'of ${compactNumber(goal)} steps',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Source: $stepSourceLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (stepFreshness != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Step data ${relativeAge(stepFreshness)}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    health.authorized ? '${(progress * 100).round()}%' : '—',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: health.authorized ? progress : 0,
                  minHeight: 11,
                  color: AppTheme.cyan,
                  backgroundColor: AppTheme.surfaceHigh,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (_range == 'Year' && !health.historicalAccess)
                    const Text(
                      'History needed',
                      style: TextStyle(
                        color: AppTheme.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SimpleBarChart(
                values: chartValues,
                target: _range == 'Day' ? null : goal.toDouble(),
                showTarget: _range == 'Week' || _range == 'Month',
                labels: _labelsFor(_range, chartValues.length),
                height: 180,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 10),
            Expanded(
              child: HmMetricCard(
                label: 'Active calories',
                value: health.authorized
                    ? '${health.activeCaloriesToday.round()} cal'
                    : '—',
                accent: AppTheme.mint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HmMetricCard(
                label: 'Active time',
                value: activeMinutes > 0 ? '$activeMinutes min' : '—',
                accent: AppTheme.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        HmSectionHeader(
          title: 'Workouts',
          action: health.authorized ? 'See all' : 'Connect',
          onAction: health.authorized
              ? null
              : () => ref.read(healthSyncProvider.notifier).connectAndSync(),
        ),
        const SizedBox(height: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
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
        const SizedBox(height: 24),
        const HmSectionHeader(title: 'Weekly activity', action: 'This week'),
        const SizedBox(height: 10),
        CommandCard(
          child: SimpleBarChart(
            values: _tail(health.dailySteps30, 7),
            target: goal.toDouble(),
            showTarget: true,
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
            height: 150,
          ),
        ),
      ],
    );
  }

  List<T> _tail<T>(List<T> values, int count) {
    if (values.length <= count) return values;
    return values.sublist(values.length - count);
  }

  List<String>? _labelsFor(String range, int count) {
    if (count <= 0) return null;
    if (range == 'Day') {
      return List.generate(count, (i) {
        if (i == 0) return '12A';
        if (i == 6) return '6A';
        if (i == 12) return '12P';
        if (i == 18) return '6P';
        if (i == count - 1) return '12A';
        return '';
      });
    }
    if (range == 'Week') {
      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return List.generate(count, (i) => days[i % 7]);
    }
    return null;
  }

  String _dateLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DateNavigator extends StatelessWidget {
  final String label;
  const _DateNavigator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary, size: 25),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 25),
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final WorkoutEntry workout;

  const _WorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.directions_run_rounded,
            color: AppTheme.mint,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.type,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shortDate(workout.start)} • ${workout.minutes} min • ${workout.source}',
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
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        ],
      ),
    );
  }
}
