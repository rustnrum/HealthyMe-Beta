import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connections_provider.dart';
import '../providers/health_data_provider.dart';
import '../providers/labs_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/profile_provider.dart';
import '../services/recommendation_service.dart';
import '../services/sleep_guidance_service.dart';
import '../widgets/metric_tile.dart';
import '../widgets/section_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final health = ref.watch(healthDataProvider);
    final labs = ref.watch(labsProvider);
    final connections = ref.watch(connectionsProvider);
    final sleep = SleepGuidanceService.forAge(profile.age);
    final guidance = RecommendationService.build(
      profile: profile,
      labs: labs,
      connections: connections,
    );

    final remaining = profile.remainingWeightLb;
    final current = profile.currentWeightLb;
    final goal = profile.goalWeightLb;
    final start = profile.startingWeightLb;

    var progress = 0.0;
    if (start != null &&
        current != null &&
        goal != null &&
        (start - goal).abs() > 0.1) {
      progress = ((start - current) / (start - goal)).clamp(0.0, 1.0).toDouble();
    }

    final stepsSource = connections.preferredSourceByMetric['Steps'];
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text(
          '${_greeting()}, ${profile.firstName}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Here is what matters today.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weight goal',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          current == null
                              ? 'Add weight'
                              : '${current.toStringAsFixed(1)} lb',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal == null
                              ? 'No goal set'
                              : remaining != null && remaining > 0
                                  ? '${remaining.toStringAsFixed(1)} lb to ${goal.toStringAsFixed(0)} lb'
                                  : 'Goal ${goal.toStringAsFixed(0)} lb',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                borderRadius: BorderRadius.circular(999),
                minHeight: 7,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Your metrics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 174,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              MetricTile(
                icon: Icons.directions_walk_rounded,
                label: 'Steps',
                value: stepsSource == null ? 'Not connected' : 'Ready',
                detail: stepsSource == null
                    ? 'Choose a source'
                    : 'Preferred source selected',
                onTap: () =>
                    ref.read(navigationProvider.notifier).setIndex(2),
              ),
              const SizedBox(width: 10),
              MetricTile(
                icon: Icons.bedtime_rounded,
                label: 'Sleep target',
                value: sleep.target,
                detail: sleep.sourceNote,
              ),
              const SizedBox(width: 10),
              MetricTile(
                icon: Icons.monitor_weight_outlined,
                label: 'Body fat',
                value: health.bodyFatPercent == null
                    ? 'From scale'
                    : '${health.bodyFatPercent!.toStringAsFixed(1)}%',
                detail: 'Never a required manual field',
              ),
              const SizedBox(width: 10),
              MetricTile(
                icon: Icons.science_outlined,
                label: 'Labs',
                value: '${labs.length}',
                detail: labs.isEmpty ? 'Optional context' : 'Stored results',
                onTap: () =>
                    ref.read(navigationProvider.notifier).setIndex(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Today’s focus',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        ...guidance.take(3).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: scheme.secondaryContainer,
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(item.detail),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 8),
        Text(
          'Healthy Me provides wellness guidance, not diagnosis or treatment.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
