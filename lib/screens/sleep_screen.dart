import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/sleep_guidance_service.dart';
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
    final recent = h.sleepMinutes7.where((value) => value > 0).toList();
    final avg = recent.isEmpty
        ? 0
        : (recent.reduce((a, b) => a + b) / recent.length).round();
    final score = guidance.minimumMinutes <= 0 || h.sleepMinutes <= 0
        ? null
        : min(100, ((h.sleepMinutes / guidance.minimumMinutes) * 100).round());

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
                _dateLabel(DateTime.now()),
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
          child: Row(
            children: [
              const HmIconBadge(
                icon: Icons.bedtime_rounded,
                color: AppTheme.purple,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      minutesLabel(h.sleepMinutes),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Total sleep',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Target: ${guidance.label} based on age',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              _ScoreRing(score: score),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_range == 'Day') ...[
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Sleep stages',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (h.sleepMinutes > 0)
                      Text(
                        minutesLabel(h.sleepMinutes),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SleepStageBar(
                  awake: h.sleepAwakeMinutes,
                  rem: h.sleepRemMinutes,
                  light: h.sleepLightMinutes,
                  deep: h.sleepDeepMinutes,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CommandCard(
            color: const Color(0xFF0B3144),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HmIconBadge(
                  icon: Icons.lightbulb_rounded,
                  color: AppTheme.amber,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sleep insight',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _insight(h.sleepMinutes, avg, guidance.minimumMinutes),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SimpleBarChart(
                  values: h.sleepMinutes7,
                  target: guidance.minimumMinutes > 0
                      ? guidance.minimumMinutes.toDouble()
                      : null,
                  showTarget: guidance.minimumMinutes > 0,
                  height: 180,
                ),
              ],
            ),
          ),
        ] else ...[
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.history_rounded,
              title: 'Longer sleep history is not available yet',
              detail: 'Healthy Me will show month and year views once enough connected sleep history has been synced.',
            ),
          ),
        ],
        const SizedBox(height: 18),
        const HmSectionHeader(title: 'Sleep consistency'),
        const SizedBox(height: 8),
        CommandCard(
          child: SimpleBarChart(
            values: h.sleepMinutes7,
            target: guidance.minimumMinutes > 0
                ? guidance.minimumMinutes.toDouble()
                : null,
            showTarget: guidance.minimumMinutes > 0,
            height: 126,
          ),
        ),
      ],
    );
  }

  String _insight(int tonight, int average, int target) {
    if (tonight <= 0) {
      return 'No sleep data yet. Connect a sleep source through Health Connect and Healthy Me will compare it with your own baseline.';
    }
    if (average > 0) {
      final delta = tonight - average;
      if (delta <= -45) {
        return 'You slept ${(-delta)} minutes less than your recent average. A lighter day and a consistent sleep window may help recovery.';
      }
      if (delta >= 45) {
        return 'You slept $delta minutes more than your recent average.';
      }
    }
    if (target > 0 && tonight < target) {
      return 'Sleep duration was below your age-based target. Prioritize a consistent sleep window tonight.';
    }
    return 'Sleep duration is close to your recent pattern and age-based target.';
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

class _ScoreRing extends StatelessWidget {
  final int? score;

  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final value = score == null ? 0.0 : (score! / 100).clamp(0.0, 1.0);
    final color = score == null
        ? AppTheme.textMuted
        : score! >= 90
            ? AppTheme.mint
            : score! >= 75
                ? AppTheme.cyan
                : AppTheme.purple;

    return Column(
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AppTheme.surfaceHigh,
              ),
              Center(
                child: Text(
                  score?.toString() ?? '—',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Duration score',
          style: TextStyle(
            color: color,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
