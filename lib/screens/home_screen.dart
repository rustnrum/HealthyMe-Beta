import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/recovery_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../state/navigation_provider.dart';
import '../widgets/salus_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _sleep(int minutes) => minutes <= 0 ? '—' : '${minutes ~/ 60}h ${minutes % 60}m';
  String _weight(double? value) => value == null ? '—' : '${value.toStringAsFixed(1)} lb';
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
                      Text(_greeting(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.w400)),
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
                        'Your signals, your baseline, your next move.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Salus AI',
                  onPressed: () => Navigator.of(context).pushNamed('/coach'),
                  icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.cyan),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: _sleep(h.sleepMinutes),
                      status: h.sleepMinutes <= 0 ? 'Awaiting data' : 'Last sleep',
                      color: AppTheme.blue,
                      onTap: () => ref.read(navigationProvider.notifier).go(2),
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
                      onTap: () => Navigator.of(context).pushNamed('/trends'),
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
                      status: _baselineStatus(h.restingHeartRate, h.restingHeartRate30),
                      color: AppTheme.rose,
                      onTap: () => Navigator.of(context).pushNamed('/trends'),
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
                      value: _number(h.respiratoryRate, '/min', decimals: 1),
                      status: _baselineStatus(h.respiratoryRate, h.respiratoryRate30),
                      color: AppTheme.cyan,
                      onTap: () => Navigator.of(context).pushNamed('/trends'),
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
                      value: _number(h.bloodOxygenPercent, '%', decimals: 0),
                      status: h.bloodOxygenPercent == null ? 'Awaiting data' : 'Latest reading',
                      color: AppTheme.purple,
                      onTap: () => Navigator.of(context).pushNamed('/health'),
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
                      status: h.stepsToday == 0 ? 'Awaiting movement data' : 'Today',
                      color: AppTheme.cyan,
                      onTap: () => ref.read(navigationProvider.notifier).go(1),
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
                      status: weight == null ? 'Awaiting scale data' : 'Current',
                      color: AppTheme.blue,
                      onTap: () => ref.read(navigationProvider.notifier).go(3),
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
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [AppTheme.cyan.withValues(alpha: 0.25), AppTheme.cyan.withValues(alpha: 0.06)]),
                          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.track_changes_rounded, color: AppTheme.cyan),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Today’s Focus', style: TextStyle(color: AppTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Small steps. Clear signals.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      SalusQuickAction(
                        icon: Icons.edit_note_rounded,
                        label: 'Check-in',
                        color: AppTheme.mint,
                        onTap: () => Navigator.of(context).pushNamed('/daily-state'),
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
                        onTap: () => Navigator.of(context).pushNamed('/trends'),
                      ),
                      const SizedBox(width: 8),
                      SalusQuickAction(
                        icon: Icons.bluetooth_searching_rounded,
                        label: 'Devices',
                        color: AppTheme.purple,
                        onTap: () => Navigator.of(context).pushNamed('/sources'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/coach'),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Ask Salus AI about today’s data'),
            ),
          ],
        ),
      ),
    );
  }
}
