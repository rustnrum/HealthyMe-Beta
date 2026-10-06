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

  String _date() {
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}';
  }

  String _sourceAsset(String label) {
    final value = label.toLowerCase();
    if (value.contains('ring') || value.contains('qring')) {
      return SalusAssets.sourceRing;
    }
    if (value.contains('scale') || value.contains('imoni')) {
      return SalusAssets.sourceScale;
    }
    if (value.contains('lab')) return SalusAssets.sourceLabs;
    if (value.contains('samsung') || value.contains('health')) {
      return SalusAssets.sourceHealth;
    }
    if (value.contains('phone') || value.contains('android')) {
      return SalusAssets.sourcePhone;
    }
    return SalusAssets.sourceWatch;
  }

  Future<void> _sync(WidgetRef ref) async {
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      await ref.read(healthSyncProvider.notifier).connectAndSync();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final recovery = RecoveryService.build(app);
    final weight = app.currentWeightLb;
    final bodyLine = h.bodyFatPercent == null
        ? 'Body fat — awaiting scale'
        : 'Body fat ${h.bodyFatPercent!.toStringAsFixed(1)}%';
    final sleepSourceKey = h.resolvedSources['Sleep'];
    final sleepSource = sleepSourceKey == null ? null : (h.sourceLabels[sleepSourceKey] ?? sleepSourceKey);
    final detected = h.detectedSources.take(3).toList();
    final latestState = app.dailyStates.isEmpty ? null : app.dailyStates.last;

    return Container(
      color: AppTheme.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _date(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              Opacity(
                opacity: 0.76,
                child: Image.asset(SalusAssets.calloutSameMe, width: 142, height: 54, fit: BoxFit.contain),
              ),
            ],
          ),
          const Divider(height: 8, thickness: 0.8),
          const SizedBox(height: 8),
          SalusPaper(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(child: SalusSectionTitle(title: 'Today', eyebrow: 'At a glance')),
                    Opacity(
                      opacity: 0.74,
                      child: Image.asset(SalusAssets.calloutSmallSteps, width: 145, height: 46, fit: BoxFit.contain),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricWeight,
                        value: _weight(weight),
                        label: 'Weight',
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricSleep,
                        value: _sleep(h.sleepMinutes),
                        label: 'Sleep',
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricSteps,
                        value: '${h.stepsToday}',
                        label: 'Steps',
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricRecovery,
                        value: recovery.score?.toString() ?? '—',
                        label: 'Recovery',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          SalusModuleRow(
            tileAsset: SalusAssets.tileBody,
            artAsset: SalusAssets.artBody,
            tint: AppTheme.mint,
            title: 'Body',
            line1: weight == null ? 'No weight reading yet' : 'Current weight ${_weight(weight)}',
            line2: bodyLine,
            onTap: () => ref.read(navigationProvider.notifier).go(3),
          ),
          const SizedBox(height: 8),
          SalusModuleRow(
            tileAsset: SalusAssets.tileSleep,
            artAsset: SalusAssets.artSleep,
            tint: AppTheme.blue,
            title: 'Sleep',
            line1: '${_sleep(h.sleepMinutes)}${sleepSource == null ? '' : '  |  $sleepSource'}',
            line2: h.sleepMinutes <= 0 ? 'No sleep record yet' : 'Compare tonight with your personal baseline',
            onTap: () => ref.read(navigationProvider.notifier).go(2),
          ),
          const SizedBox(height: 8),
          SalusModuleRow(
            tileAsset: SalusAssets.tileActivity,
            artAsset: SalusAssets.artActivity,
            tint: AppTheme.amber,
            title: 'Activity',
            line1: '${h.stepsToday} / ${app.profile.stepGoal} steps',
            line2: h.workouts.isEmpty
                ? 'No workout logged today'
                : '${h.workouts.length} recent workout${h.workouts.length == 1 ? '' : 's'}',
            onTap: () => ref.read(navigationProvider.notifier).go(1),
          ),
          const SizedBox(height: 8),
          SalusModuleRow(
            tileAsset: SalusAssets.tileNotes,
            artAsset: SalusAssets.artNotes,
            tint: AppTheme.purple,
            title: 'Check-in',
            line1: latestState?.isCompleted == true ? 'Today’s check-in recorded' : 'Morning check-in waiting',
            line2: latestState?.resetFeedback,
            onTap: () => Navigator.of(context).pushNamed('/daily-state'),
          ),
          const SizedBox(height: 11),
          SalusPaper(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(child: SalusSectionTitle(title: 'Sources', eyebrow: 'Connected to a clearer you')),
                    Opacity(
                      opacity: 0.78,
                      child: Image.asset(SalusAssets.calloutAllInOne, width: 135, height: 44, fit: BoxFit.contain),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (detected.isEmpty)
                  const Text(
                    'No provider records detected yet. Sync Health Connect to refresh.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < detected.length; i++) ...[
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final source = detected[i];
                              final label = h.sourceLabels[source] ?? source;
                              return SalusSourceItem(
                                asset: _sourceAsset(label),
                                label: label,
                                status: 'connected',
                              );
                            },
                          ),
                        ),
                        if (i != detected.length - 1) const SizedBox(width: 6),
                      ],
                      if (detected.length < 4) ...[
                        if (detected.isNotEmpty) const SizedBox(width: 6),
                        const Expanded(
                          child: SalusSourceItem(
                            asset: SalusAssets.sourceLabs,
                            label: 'Labs',
                            status: 'ready',
                            statusColor: AppTheme.amber,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              SalusQuickAction(
                icon: Icons.edit_note_rounded,
                label: 'Check-in',
                onTap: () => Navigator.of(context).pushNamed('/daily-state'),
              ),
              const SizedBox(width: 7),
              SalusQuickAction(icon: Icons.sync_rounded, label: 'Sync', onTap: () => _sync(ref)),
              const SizedBox(width: 7),
              SalusQuickAction(
                icon: Icons.bar_chart_rounded,
                label: 'Trends',
                onTap: () => ref.read(navigationProvider.notifier).go(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
