import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../services/recovery_service.dart';
import '../state/app_state.dart';
import '../state/navigation_provider.dart';
import '../widgets/salus_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _sleep(int minutes) => minutes <= 0 ? '—' : '${minutes ~/ 60}h ${minutes % 60}m';
  String _weight(double? value) => value == null ? '—' : '${value.toStringAsFixed(1)} lb';
  String _date() {
    const days = ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'];
    const months = ['JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE','JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final recovery = RecoveryService.build(app);
    final weight = app.currentWeightLb;
    final bodyLine = h.bodyFatPercent == null ? 'Body fat — awaiting scale' : 'Body fat ${h.bodyFatPercent!.toStringAsFixed(1)}%';
    final sleepSourceKey = h.resolvedSources['Sleep'];
    final sleepSource = sleepSourceKey == null ? null : (h.sourceLabels[sleepSourceKey] ?? sleepSourceKey);
    final detected = h.detectedSources.take(4).toList();
    final latestState = app.dailyStates.isEmpty ? null : app.dailyStates.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(_date(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.2)),
        const SizedBox(height: 5),
        const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('SAME STEPS • A BETTER YOU', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, letterSpacing: 1.4))), Expanded(child: Divider())]),
        const SizedBox(height: 12),
        SalusPaper(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SalusSectionTitle(title: 'Today', eyebrow: 'At a glance'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: SalusMetric(icon: Icons.monitor_weight_outlined, value: _weight(weight), label: 'Weight', tint: AppTheme.mint)),
              const SizedBox(width: 4),
              Expanded(child: SalusMetric(icon: Icons.bedtime_outlined, value: _sleep(h.sleepMinutes), label: 'Sleep', tint: AppTheme.blue)),
              const SizedBox(width: 4),
              Expanded(child: SalusMetric(icon: Icons.directions_walk_rounded, value: '${h.stepsToday}', label: 'Steps', tint: AppTheme.amber)),
              const SizedBox(width: 4),
              Expanded(child: SalusMetric(icon: Icons.favorite_border_rounded, value: recovery.score?.toString() ?? '—', label: 'Recovery', tint: AppTheme.rose)),
            ]),
          ]),
        ),
        const SizedBox(height: 11),
        SalusModuleRow(icon: Icons.accessibility_new_rounded, tint: AppTheme.mint, title: 'Body', line1: weight == null ? 'No weight reading yet' : 'Current weight ${_weight(weight)}', line2: bodyLine, onTap: () => ref.read(navigationProvider.notifier).go(3)),
        const SizedBox(height: 9),
        SalusModuleRow(icon: Icons.bedtime_outlined, tint: AppTheme.blue, title: 'Sleep', line1: '${_sleep(h.sleepMinutes)}${sleepSource == null ? '' : '  |  $sleepSource'}', line2: h.sleepMinutes <= 0 ? 'No sleep record yet' : 'Compare tonight with your personal baseline', onTap: () => ref.read(navigationProvider.notifier).go(2)),
        const SizedBox(height: 9),
        SalusModuleRow(icon: Icons.directions_walk_rounded, tint: AppTheme.amber, title: 'Activity', line1: '${h.stepsToday} / ${app.profile.stepGoal} steps', line2: h.workouts.isEmpty ? 'No workout logged today' : '${h.workouts.length} recent workout${h.workouts.length == 1 ? '' : 's'}', onTap: () => ref.read(navigationProvider.notifier).go(1)),
        const SizedBox(height: 9),
        SalusModuleRow(icon: Icons.edit_note_rounded, tint: AppTheme.purple, title: 'Check-in', line1: latestState?.isCompleted == true ? 'Today’s check-in recorded' : 'Morning check-in waiting', line2: latestState?.resetFeedback, onTap: () => Navigator.of(context).pushNamed('/daily-state')),
        const SizedBox(height: 12),
        SalusPaper(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SalusSectionTitle(title: 'Sources', eyebrow: 'Connected to a clearer you'),
            const SizedBox(height: 12),
            if (detected.isEmpty)
              const Text('No provider records detected yet. Sync Health Connect to refresh.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5))
            else
              Wrap(spacing: 10, runSpacing: 10, children: [for (final source in detected) _SourceChip(label: h.sourceLabels[source] ?? source)]),
          ]),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  const _SourceChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 118),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(color: AppTheme.surfaceHigh.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border.withValues(alpha: 0.7))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.circle, color: AppTheme.mint, size: 9), const SizedBox(width: 7), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)))]),
  );
}
