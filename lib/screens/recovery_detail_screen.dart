import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/recovery_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class RecoveryDetailScreen extends ConsumerWidget {
  const RecoveryDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final report = RecoveryService.build(app);
    final color = _bandColor(report.band);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery'),
        actions: [
          IconButton(
            tooltip: 'Daily State',
            icon: const Icon(Icons.self_improvement_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/daily-state'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          CommandCard(
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: report.score == null ? 0.15 : report.score! / 100,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        color: color,
                        backgroundColor: AppTheme.surfaceHigh,
                      ),
                      Center(
                        child: Text(
                          report.score?.toString() ?? '—',
                          style: TextStyle(
                            color: color,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recovery',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        report.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.confidence}% confidence',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.summary,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Recovery contributors'),
          const SizedBox(height: 10),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < report.contributors.length; i++) ...[
                  _ContributorRow(item: report.contributors[i]),
                  if (i != report.contributors.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'What this means'),
          const SizedBox(height: 10),
          CommandCard(
            child: Text(
              _meaning(report),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Recovery is a wellness estimate, not a medical diagnosis. Daily State is a Healthy Me subjective input, not an official SRSS score. Nutrition will become a contributor only after the Diet section has actual meal data.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _meaning(RecoveryReport report) {
    if (report.score == null) {
      return 'Healthy Me does not have enough recovery telemetry yet. Daily State, sleep, cardio and connected workout history will improve this estimate.';
    }
    if (report.band == RecoveryBand.good) {
      return 'Your available subjective, sleep, cardiovascular, breathing and recent training-load signals are generally supportive of normal activity today.';
    }
    if (report.band == RecoveryBand.fair) {
      return 'One or more recovery signals are less favorable than your recent pattern. A sensible training day is still possible, but avoid treating one score as a command.';
    }
    return 'Several available recovery signals are off your recent pattern. Consider an easier training day and prioritize recovery basics.';
  }

  static Color _bandColor(RecoveryBand band) {
    switch (band) {
      case RecoveryBand.good:
        return AppTheme.mint;
      case RecoveryBand.fair:
        return AppTheme.amber;
      case RecoveryBand.watch:
        return AppTheme.rose;
      case RecoveryBand.noData:
        return AppTheme.textMuted;
    }
  }
}

class _ContributorRow extends StatelessWidget {
  final RecoveryContributor item;

  const _ContributorRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final score = item.score;
    final resolvedScore = score ?? 0;
    final color = score == null
        ? AppTheme.textMuted
        : resolvedScore >= 80
            ? AppTheme.mint
            : resolvedScore >= 60
                ? AppTheme.amber
                : AppTheme.rose;
    final icon = switch (item.name) {
      'Sleep' => Icons.bedtime_rounded,
      'Daily state' => Icons.self_improvement_rounded,
      'Cardio' => Icons.favorite_rounded,
      'HRV' => Icons.insights_rounded,
      'Resting HR' => Icons.favorite_border_rounded,
      'Breathing' => Icons.air_rounded,
      'Training load' => Icons.directions_run_rounded,
      'Nutrition' => Icons.restaurant_rounded,
      _ => Icons.insights_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      score == null ? 'N/A' : '$score%',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: score == null ? 0 : resolvedScore / 100,
                    minHeight: 7,
                    color: color,
                    backgroundColor: AppTheme.surfaceHigh,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.detail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
