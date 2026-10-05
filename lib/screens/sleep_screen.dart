import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/sleep_guidance_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  String _range = 'Day';

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final guidance = SleepGuidanceService.forAge(app.profile.age);
    final sleepSourceKey = h.resolvedSources['Sleep'];
    final sleepSourceLabel = sleepSourceKey == null
        ? 'No connected source'
        : (h.sourceLabels[sleepSourceKey] ??
            SourceNameService.friendly(sleepSourceKey));
    final stageSourceKey =
        h.resolvedSources['Sleep Stages'] ?? h.resolvedSources['Sleep'];
    final stageSourceLabel = stageSourceKey == null
        ? 'No connected source'
        : (h.sourceLabels[stageSourceKey] ??
            SourceNameService.friendly(stageSourceKey));
    final sleepFreshness = h.freshness['Sleep'];
    final recent = h.sleepMinutes7.where((value) => value > 0).toList();
    final avg = recent.isEmpty
        ? 0
        : (recent.reduce((a, b) => a + b) / recent.length).round();
    final score = guidance.minimumMinutes <= 0 || h.sleepMinutes <= 0
        ? null
        : min(100, ((h.sleepMinutes / guidance.minimumMinutes) * 100).round());

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        HmTabs(
          labels: const ['Day', 'Week', 'Month', 'Year'],
          selected: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 12),
        _DateNavigator(label: _dateLabel(DateTime.now())),
        const SizedBox(height: 12),
        CommandCard(
          child: Row(
            children: [
              const HmIconBadge(
                icon: Icons.bedtime_rounded,
                color: AppTheme.purple,
                size: 58,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      minutesLabel(h.sleepMinutes),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.65,
                      ),
                    ),
                    const Text(
                      'Total Sleep',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Source: $sleepSourceLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.purple,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sleepFreshness != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Sleep data ${relativeAge(sleepFreshness)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      'Target: ${guidance.label} based on your age',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _ScoreRing(score: score),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_range == 'Day') ...[
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Sleep Stages',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (h.sleepMinutes > 0)
                      Text(
                        minutesLabel(h.sleepMinutes),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Stages from: $stageSourceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.purple,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SleepStageBar(
                  awake: h.sleepAwakeMinutes,
                  rem: h.sleepRemMinutes,
                  light: h.sleepLightMinutes,
                  deep: h.sleepDeepMinutes,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CommandCard(
            color: const Color(0xFF0B3144),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HmIconBadge(
                  icon: Icons.lightbulb_rounded,
                  color: AppTheme.amber,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sleep Insight',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _insight(h.sleepMinutes, avg, guidance.minimumMinutes),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              ],
            ),
          ),
        ] else if (_range == 'Week') ...[
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sleep duration • 7 days',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                SimpleBarChart(
                  values: h.sleepMinutes7,
                  target: guidance.minimumMinutes > 0
                      ? guidance.minimumMinutes.toDouble()
                      : null,
                  showTarget: guidance.minimumMinutes > 0,
                  labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                  height: 190,
                ),
              ],
            ),
          ),
        ] else ...[
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.history_rounded,
              title: 'Longer sleep history is not available yet',
              detail: 'Month and year views appear after enough connected sleep history has synced.',
            ),
          ),
        ],
        const SizedBox(height: 24),
        const HmSectionHeader(title: 'Sleep Consistency (7 days)'),
        const SizedBox(height: 10),
        CommandCard(
          child: SimpleBarChart(
            values: h.sleepMinutes7,
            target: guidance.minimumMinutes > 0
                ? guidance.minimumMinutes.toDouble()
                : null,
            showTarget: guidance.minimumMinutes > 0,
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
            height: 155,
          ),
        ),
      ],
    );
  }

  String _insight(int tonight, int average, int target) {
    if (tonight <= 0) {
      return 'No sleep data yet. Connect a sleep source through Health Connect and Salus will compare it with your own baseline.';
    }
    if (average > 0) {
      final delta = tonight - average;
      if (delta <= -45) {
        return 'You slept less than your recent average. A lighter day and a consistent sleep window may support recovery.';
      }
      if (delta >= 45) {
        return 'You slept more than your recent average. Salus will keep watching whether that becomes a trend.';
      }
    }
    if (target > 0 && tonight < target) {
      return 'Sleep was below your age-based target. Prioritize a consistent bedtime rather than chasing one perfect night.';
    }
    return 'Sleep duration is near your recent pattern and age-based target.';
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

class _ScoreRing extends StatelessWidget {
  final int? score;
  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final value = score == null ? 0.0 : (score! / 100).clamp(0.0, 1.0);
    final color = score == null
        ? AppTheme.textMuted
        : score! >= 85
            ? AppTheme.mint
            : score! >= 70
                ? AppTheme.purple
                : AppTheme.rose;
    final status = score == null
        ? 'No data'
        : score! >= 85
            ? 'Good'
            : score! >= 70
                ? 'Fair'
                : 'Watch';

    return SizedBox(
      width: 88,
      child: Column(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  color: color,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    score?.toString() ?? '—',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Sleep Score',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          Text(
            status,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
