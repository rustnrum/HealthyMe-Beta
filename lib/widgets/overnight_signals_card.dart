import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/recovery_service.dart';
import 'salus_widgets.dart';

class OvernightSignalsCard extends StatelessWidget {
  final RecoveryReport report;
  final ValueChanged<String> onSignalTap;
  final VoidCallback onViewTrends;

  const OvernightSignalsCard({
    super.key,
    required this.report,
    required this.onSignalTap,
    required this.onViewTrends,
  });

  @override
  Widget build(BuildContext context) {
    final signals = report.contributors
        .where((item) => const {'HRV', 'Breathing', 'Resting HR', 'Sleep'}.contains(item.name))
        .toList()
      ..sort((a, b) => _sortScore(a).compareTo(_sortScore(b)));

    final changed = signals
        .where((item) => item.available && item.score != null && item.score! < 80)
        .toList();

    final summary = changed.isEmpty
        ? 'Your available overnight signals are close to your recent baseline.'
        : '${changed.take(2).map((item) => _displayName(item.name)).join(' + ')} changed the most from your usual pattern.';

    return SalusPaper(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: SalusSectionTitle(
                  title: 'Overnight signals',
                  eyebrow: 'What changed',
                ),
              ),
              TextButton(
                onPressed: onViewTrends,
                child: const Text('View trends'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            summary,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < signals.length; i++) ...[
            _SignalRow(
              item: signals[i],
              onTap: () => onSignalTap(signals[i].name),
            ),
            if (i != signals.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  static int _sortScore(RecoveryContributor item) {
    if (!item.available || item.score == null) return 101;
    return item.score!;
  }

  static String _displayName(String name) => switch (name) {
        'Breathing' => 'Respiration',
        'Resting HR' => 'Resting heart rate',
        _ => name,
      };
}

class _SignalRow extends StatelessWidget {
  final RecoveryContributor item;
  final VoidCallback onTap;

  const _SignalRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _status(item);
    final color = _color(item);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          OvernightSignalsCard._displayName(item.name),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    maxLines: 2,
                    softWrap: true,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static String _status(RecoveryContributor item) {
    if (!item.available || item.score == null) return 'Building baseline';
    if (item.score! >= 80) return 'In range';
    if (item.score! >= 60) return 'Watch';
    return 'Off baseline';
  }

  static Color _color(RecoveryContributor item) {
    if (!item.available || item.score == null) return AppTheme.textMuted;
    if (item.score! >= 80) return AppTheme.mint;
    if (item.score! >= 60) return AppTheme.amber;
    return AppTheme.rose;
  }
}
