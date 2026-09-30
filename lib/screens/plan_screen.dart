import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connections_provider.dart';
import '../providers/labs_provider.dart';
import '../providers/profile_provider.dart';
import '../services/recommendation_service.dart';
import '../widgets/section_card.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final labs = ref.watch(labsProvider);
    final connections = ref.watch(connectionsProvider);
    final guidance = RecommendationService.build(
      profile: profile,
      labs: labs,
      connections: connections,
    );

    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text(
          'Your Plan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Built from what you actually entered or connected.',
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan context',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(profile.primaryGoal)),
                  Chip(label: Text(profile.activityLevel)),
                  Chip(
                    label: Text(
                      profile.age == null ? 'Age unknown' : 'Age ${profile.age}',
                    ),
                  ),
                  Chip(label: Text('${labs.length} labs')),
                  Chip(
                    label: Text(
                      '${connections.preferredSourceByMetric.length} metric sources',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...guidance.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      _iconFor(item.category),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
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
          'These are wellness suggestions, not medical diagnosis or treatment. Medical problems and abnormal lab results should be discussed with a clinician.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Sleep':
        return Icons.bedtime_outlined;
      case 'Activity':
        return Icons.directions_walk;
      case 'Nutrition':
        return Icons.restaurant_outlined;
      case 'Labs':
        return Icons.science_outlined;
      default:
        return Icons.fitness_center;
    }
  }
}
