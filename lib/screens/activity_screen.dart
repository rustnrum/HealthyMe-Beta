import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';

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
    final goal = app.profile.stepGoal;
    final progress =
        goal <= 0 ? 0.0 : (health.stepsToday / goal).clamp(0.0, 1.0);

    final chartValues = switch (_range) {
      'Day' => health.hourlySteps,
      'Week' => health.dailySteps30.length >= 7
          ? health.dailySteps30.sublist(health.dailySteps30.length - 7)
          : health.dailySteps30,
      'Month' => health.dailySteps30,
      _ => health.monthlySteps12,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            Text(
              'Activity',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            if (!health.authorized)
              TextButton.icon(
                onPressed: () =>
                    ref.read(healthSyncProvider.notifier).connectAndSync(),
                icon: const Icon(Icons.add_link),
                label: const Text('Connect'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Day', label: Text('Day')),
            ButtonSegment(value: 'Week', label: Text('Week')),
            ButtonSegment(value: 'Month', label: Text('Month')),
            ButtonSegment(value: 'Year', label: Text('Year')),
          ],
          selected: {_range},
          onSelectionChanged: (value) =>
              setState(() => _range = value.first),
        ),
        const SizedBox(height: 14),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.directions_walk_rounded,
                    color: AppTheme.cyan,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    health.authorized
                        ? compactNumber(health.stepsToday)
                        : '—',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('of ${compactNumber(goal)} steps'),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                borderRadius: BorderRadius.circular(999),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _range == 'Year' && !health.historicalAccess
                    ? 'Year view needs Health Connect history access'
                    : 'Step trend',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SimpleBarChart(
                values: chartValues,
                target: _range == 'Day' ? null : goal.toDouble(),
                showTarget: _range == 'Week' || _range == 'Month',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricBox(
                label: 'Distance',
                value: health.authorized
                    ? '${health.distanceMilesToday.toStringAsFixed(1)} mi'
                    : '—',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MetricBox(
                label: 'Active calories',
                value: health.authorized
                    ? '${health.activeCaloriesToday.round()} cal'
                    : '—',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MetricBox(
                label: 'Workouts',
                value: '${health.workouts.where((w) {
                  final now = DateTime.now();
                  return w.start.year == now.year &&
                      w.start.month == now.month &&
                      w.start.day == now.day;
                }).length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Recent workouts',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 9),
        if (health.workouts.isEmpty)
          const CommandCard(
            child: Text(
              'No workout sessions were found in the connected data yet.',
            ),
          )
        else
          ...health.workouts.take(5).map(
                (workout) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: CommandCard(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0x2235E39A),
                          child: Icon(
                            Icons.directions_run,
                            color: AppTheme.mint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout.type,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${shortDate(workout.start)} • ${workout.minutes} min • ${workout.source}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return CommandCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
