import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/health_provider.dart';
import '../providers/labs_provider.dart';
import '../providers/profile_provider.dart';
import '../services/sleep_guidance_service.dart';
import '../widgets/section_card.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final labs = ref.watch(labsProvider);
    final connections = ref.watch(healthConnectionsProvider);

    final sleepTarget =
        SleepGuidanceService.targetForBirthday(profile.birthday);

    final suggestions = <String>[
      'Sleep: aim for $sleepTarget consistently before chasing advanced recovery metrics.',
      'Training: build a repeatable weekly routine before adding more volume.',
      'Nutrition: prioritize protein, fiber-rich foods, vegetables, and a sustainable calorie target.',
    ];

    if (labs.isNotEmpty) {
      suggestions.add(
        'Bloodwork: ${labs.length} result${labs.length == 1 ? '' : 's'} available as context for future wellness suggestions.',
      );
    }

    if (connections.selectedSourceByMetric.isEmpty) {
      suggestions.add(
        'Connections: choose at least one data source so future guidance can use real trends.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Your Plan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Simple suggestions from the information you choose to share.',
        ),
        const SizedBox(height: 16),
        ...suggestions.map(
          (text) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Healthy Me provides wellness suggestions only. Medical diagnosis and treatment belong with a qualified clinician.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
