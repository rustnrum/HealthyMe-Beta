import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/workout_models.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/recovery_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../state/navigation_provider.dart';
import '../state/today_plan_state.dart';
import '../state/workout_state.dart';
import '../widgets/salus_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _sleep(int minutes) =>
      minutes <= 0 ? '—' : '${minutes ~/ 60}h ${minutes % 60}m';
  String _weight(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} lb';
  String _number(double? value, String suffix, {int decimals = 0}) =>
      value == null ? '—' : '${value.toStringAsFixed(decimals)} $suffix';

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _sync(WidgetRef ref) async {
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      await ref.read(healthSyncProvider.notifier).connectAndSync();
    }
  }

  String _recoverySubtitle(int? score) {
    if (score == null) return 'More overnight data will improve this score.';
    if (score >= 80) return 'Your signals are in a good range today.';
    if (score >= 60) return 'A mixed day — watch the signals below.';
    return 'Several signals are outside your recent baseline.';
  }

  String _baselineStatus(double? value, List<double> history) {
    if (value == null) return 'Building baseline';
    if (history.length < 5) return 'Current reading';
    final average = history.reduce((a, b) => a + b) / history.length;
    if (average == 0) return 'Current reading';
    final delta = (value - average) / average;
    if (delta.abs() < 0.06) return 'Within range';
    return delta > 0 ? 'Above baseline' : 'Below baseline';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final recovery = RecoveryService.build(app);
    final weight = app.currentWeightLb;
    final mealState = ref.watch(todayPlanStateProvider);
    final workoutState = ref.watch(workoutStateProvider);
    final now = DateTime.now();
    final meals = mealState.mealsFor(now);
    final plannedWorkouts = workoutState.scheduled
        .where((item) => _sameDay(item.scheduledFor, now))
        .toList();
    final completedToday = workoutState.history
        .where((item) => _sameDay(item.completedAt, now))
        .toList();
    final firstName = app.profile.firstName.trim().isEmpty
        ? 'there'
        : app.profile.firstName.trim().split(RegExp(r'\s+')).first;

    return SalusPageBackground(
      child: RefreshIndicator(
        color: AppTheme.cyan,
        backgroundColor: AppTheme.surfaceHigh,
        onRefresh: () => _sync(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        firstName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 40,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'What’s on the plan today — and how you’re doing.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Salus AI',
                  onPressed: () => Navigator.of(context).pushNamed('/coach'),
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: SalusRecoveryOrb(
                score: recovery.score,
                subtitle: _recoverySubtitle(recovery.score),
                onTap: () => Navigator.of(context).pushNamed('/recovery'),
              ),
            ),
            const SizedBox(height: 16),
            _TodayPlanCard(
              meals: meals,
              plannedWorkouts: plannedWorkouts,
              completedWorkoutCount: completedToday.length,
              onMeals: () => Navigator.of(context).pushNamed('/diet'),
              onWorkout: () => Navigator.of(context).pushNamed('/workout'),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<_DeviceBattery>>(
              future: _loadDeviceBatteries(),
              builder: (context, snapshot) {
                final batteries = snapshot.data ?? const <_DeviceBattery>[];
                if (batteries.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SalusPaper(
                    padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device batteries',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in batteries)
                              _BatteryChip(item: item),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: _sleep(h.sleepMinutes),
                      status:
                          h.sleepMinutes <= 0 ? 'Awaiting data' : 'Last sleep',
                      color: AppTheme.blue,
                      onTap: () =>
                          ref.read(navigationProvider.notifier).go(2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.show_chart_rounded,
                      label: 'HRV',
                      value: _number(h.hrvMs, 'ms'),
                      status: _baselineStatus(h.hrvMs, h.hrv30),
                      color: AppTheme.mint,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/trends'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.favorite_border_rounded,
                      label: 'Resting HR',
                      value: _number(h.restingHeartRate, 'bpm'),
                      status: _baselineStatus(
                        h.restingHeartRate,
                        h.restingHeartRate30,
                      ),
                      color: AppTheme.rose,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/trends'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 126,
                    child: SalusGlassMetricCard(
                      icon: Icons.air_rounded,
                      label: 'Respiration',
                      value:
                          _number(h.respiratoryRate, '/min', decimals: 1),
                      status: _baselineStatus(
                        h.respiratoryRate,
                        h.respiratoryRate30,
                      ),
                      color: AppTheme.cyan,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/trends'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 126,
                    child: SalusGlassMetricCard(
                      icon: Icons.water_drop_outlined,
                      label: 'SpO₂',
                      value: _number(
                        h.bloodOxygenPercent,
                        '%',
                        decimals: 0,
                      ),
                      status: h.bloodOxygenPercent == null
                          ? 'Awaiting data'
                          : 'Latest reading',
                      color: AppTheme.purple,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/health'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 126,
                    child: SalusGlassMetricCard(
                      icon: Icons.directions_walk_rounded,
                      label: 'Steps',
                      value: '${h.stepsToday}',
                      status: h.stepsToday == 0
                          ? 'Awaiting movement data'
                          : 'Today',
                      color: AppTheme.cyan,
                      onTap: () =>
                          ref.read(navigationProvider.notifier).go(1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 126,
                    child: SalusGlassMetricCard(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight',
                      value: _weight(weight),
                      status:
                          weight == null ? 'Awaiting scale data' : 'Current',
                      color: AppTheme.blue,
                      onTap: () =>
                          ref.read(navigationProvider.notifier).go(3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SalusPaper(
              glow: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today’s actions',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SalusQuickAction(
                        icon: Icons.edit_note_rounded,
                        label: 'Check-in',
                        color: AppTheme.mint,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/daily-state'),
                      ),
                      const SizedBox(width: 8),
                      SalusQuickAction(
                        icon: Icons.sync_rounded,
                        label: 'Sync',
                        onTap: () => _sync(ref),
                      ),
                      const SizedBox(width: 8),
                      SalusQuickAction(
                        icon: Icons.insights_rounded,
                        label: 'Trends',
                        color: AppTheme.blue,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/trends'),
                      ),
                      const SizedBox(width: 8),
                      SalusQuickAction(
                        icon: Icons.bluetooth_searching_rounded,
                        label: 'Devices',
                        color: AppTheme.purple,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/sources'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPlanCard extends StatelessWidget {
  final Map<String, String> meals;
  final List<ScheduledWorkout> plannedWorkouts;
  final int completedWorkoutCount;
  final VoidCallback onMeals;
  final VoidCallback onWorkout;

  const _TodayPlanCard({
    required this.meals,
    required this.plannedWorkouts,
    required this.completedWorkoutCount,
    required this.onMeals,
    required this.onWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return SalusPaper(
      glow: true,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today_rounded, color: AppTheme.cyan),
              SizedBox(width: 9),
              Text(
                'Today',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final slot in salusMealSlots)
            _PlanRow(
              icon: _mealIcon(slot),
              tint: _mealColor(slot),
              title: slot,
              detail: (meals[slot] ?? '').trim().isEmpty
                  ? 'Not planned'
                  : meals[slot]!,
              onTap: onMeals,
            ),
          const Divider(height: 20),
          _PlanRow(
            icon: completedWorkoutCount > 0
                ? Icons.check_circle_rounded
                : Icons.fitness_center_rounded,
            tint: completedWorkoutCount > 0 ? AppTheme.mint : AppTheme.cyan,
            title: 'Workout',
            detail: completedWorkoutCount > 0
                ? 'Completed today'
                : plannedWorkouts.isEmpty
                    ? 'No workout scheduled'
                    : plannedWorkouts.map((item) => item.name).join(' • '),
            onTap: onWorkout,
          ),
          if (plannedWorkouts.isNotEmpty && completedWorkoutCount == 0) ...[
            const SizedBox(height: 7),
            for (final exercise in plannedWorkouts
                .expand((workout) => workout.exercises)
                .take(5))
              Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 4),
                child: Text(
                  '${exercise.name} • ${exercise.sets}×${exercise.reps}'
                  '${exercise.weight == null ? '' : ' • ${_trim(exercise.weight!)} lb'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11.8,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static IconData _mealIcon(String slot) => switch (slot) {
        'Breakfast' => Icons.wb_sunny_outlined,
        'Lunch' => Icons.light_mode_outlined,
        'Dinner' => Icons.wb_twilight_outlined,
        _ => Icons.bedtime_outlined,
      };

  static Color _mealColor(String slot) => switch (slot) {
        'Breakfast' => AppTheme.mint,
        'Lunch' => AppTheme.amber,
        'Dinner' => AppTheme.rose,
        _ => AppTheme.purple,
      };
}

class _PlanRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _PlanRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: tint, size: 20),
            const SizedBox(width: 11),
            SizedBox(
              width: 76,
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceBattery {
  final SavedDirectDevice device;
  final double value;

  const _DeviceBattery(this.device, this.value);
}

class _BatteryChip extends StatelessWidget {
  final _DeviceBattery item;

  const _BatteryChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final kind = item.device.deviceKind.toLowerCase();
        final isWatch = kind.contains('watch') || kind.contains('band');
        if (item.device.protocolId == 'cpap-family') {
          Navigator.of(context).pushNamed('/cpap', arguments: item.device.id);
        } else if (isWatch) {
          Navigator.of(context)
              .pushNamed('/watch-device', arguments: item.device.id);
        } else {
          Navigator.of(context).pushNamed('/sources');
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.mint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.mint.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.battery_charging_full_rounded,
              color: AppTheme.mint,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              '${item.device.name} ${item.value.round()}%',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<List<_DeviceBattery>> _loadDeviceBatteries() async {
  final devices = await DirectDeviceStore().load();
  final samples = await DirectMetricService().loadSamples();
  final values = <_DeviceBattery>[];
  for (final device in devices) {
    final matching = samples
        .where(
          (sample) =>
              sample.deviceId == device.id && sample.metric == 'Battery',
        )
        .toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    if (matching.isEmpty) continue;
    values.add(
      _DeviceBattery(
        device,
        matching.last.value.clamp(0.0, 100.0).toDouble(),
      ),
    );
  }
  return values;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _trim(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
