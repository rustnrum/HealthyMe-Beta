import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../services/sleep_guidance_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _pickBirthday(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );

    if (selected != null) {
      ref.read(profileProvider.notifier).setBirthday(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final sleepTarget =
        SleepGuidanceService.targetForBirthday(profile.birthday);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Today',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Useful numbers first. Details only when you need them.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: const MetricCard(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    value: '—',
                    detail: 'Connect a source',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    icon: Icons.bedtime_outlined,
                    label: 'Sleep target',
                    value: sleepTarget,
                    detail: 'Suggested from age',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: const MetricCard(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Body fat',
                    value: 'Auto',
                    detail: 'From compatible scale',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: const MetricCard(
                    icon: Icons.fitness_center,
                    label: 'Workouts',
                    value: '—',
                    detail: 'No source connected',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile guidance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Sleep guidance: $sleepTarget'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _pickBirthday(context, ref, profile.birthday),
                icon: const Icon(Icons.cake_outlined),
                label: Text(
                  profile.birthday == null
                      ? 'Add birthday'
                      : 'Change birthday',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Healthy Me provides wellness guidance, not diagnosis or treatment.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
