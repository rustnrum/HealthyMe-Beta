import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../services/recovery_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../state/navigation_provider.dart';
import '../widgets/salus_widgets.dart';
import '../widgets/overnight_signals_card.dart';

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

    return Container(
      color: AppTheme.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text(
            _date(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 2),
          const Divider(height: 4, thickness: 0.8),
          const SizedBox(height: 4),
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
                      
                        onTap: () => ref.read(navigationProvider.notifier).go(3),),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricSleep,
                        value: _sleep(h.sleepMinutes),
                        label: 'Sleep',
                      
                        onTap: () => ref.read(navigationProvider.notifier).go(2),),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricSteps,
                        value: '${h.stepsToday}',
                        label: 'Steps',
                      
                        onTap: () => ref.read(navigationProvider.notifier).go(1),),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SalusMetric(
                        asset: SalusAssets.metricRecovery,
                        value: recovery.score?.toString() ?? '—',
                        label: 'Recovery',
                      
                        onTap: () => Navigator.of(context).pushNamed('/recovery'),),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          OvernightSignalsCard(
            report: recovery,
            onSignalTap: (name) {
              if (name == 'Sleep') {
                ref.read(navigationProvider.notifier).go(2);
              } else {
                Navigator.of(context).pushNamed('/trends');
              }
            },
            onViewTrends: () => Navigator.of(context).pushNamed('/trends'),
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
                onTap: () => Navigator.of(context).pushNamed('/trends'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
