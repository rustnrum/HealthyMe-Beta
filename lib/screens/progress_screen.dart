import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_data.dart';
import '../providers/health_data_provider.dart';
import '../providers/profile_provider.dart';
import '../services/sleep_guidance_service.dart';
import '../widgets/activity_chart.dart';
import '../widgets/section_card.dart';
import '../widgets/weight_chart.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  Future<void> _editMeasurements(
    BuildContext context,
    WidgetRef ref,
    BodyMeasurements current,
  ) async {
    TextEditingController controller(double? value) =>
        TextEditingController(text: value?.toStringAsFixed(1) ?? '');

    final controllers = <String, TextEditingController>{
      'Waist': controller(current.waist),
      'Chest': controller(current.chest),
      'Hips': controller(current.hips),
      'Neck': controller(current.neck),
      'Left arm': controller(current.leftArm),
      'Right arm': controller(current.rightArm),
      'Left thigh': controller(current.leftThigh),
      'Right thigh': controller(current.rightThigh),
    };

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Body measurements'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              children: controllers.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: entry.value,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '${entry.key} (in)',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == true) {
      double? read(String key) =>
          double.tryParse(controllers[key]!.text.trim());

      ref.read(healthDataProvider.notifier).updateMeasurements(
            BodyMeasurements(
              waist: read('Waist'),
              chest: read('Chest'),
              hips: read('Hips'),
              neck: read('Neck'),
              leftArm: read('Left arm'),
              rightArm: read('Right arm'),
              leftThigh: read('Left thigh'),
              rightThigh: read('Right thigh'),
            ),
          );
    }

    for (final item in controllers.values) {
      item.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final health = ref.watch(healthDataProvider);
    final sleep = SleepGuidanceService.forAge(profile.age);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text(
          'Progress',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Trends first. No clutter, and no made-up data.',
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Weight trend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    profile.currentWeightLb == null
                        ? '—'
                        : '${profile.currentWeightLb!.toStringAsFixed(1)} lb',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              WeightChart(entries: health.weightHistory),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ActivityChart(recentSteps: health.recentSteps),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Body measurements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _editMeasurements(context, ref, health.measurements),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MeasurementGrid(measurements: health.measurements),
              const SizedBox(height: 12),
              Text(
                health.bodyFatPercent == null
                    ? 'Body fat: waiting for a compatible connected source.'
                    : 'Body fat: ${health.bodyFatPercent!.toStringAsFixed(1)}% from connected data.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bedtime_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep target',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sleep.target,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(sleep.sourceNote),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeasurementGrid extends StatelessWidget {
  final BodyMeasurements measurements;

  const _MeasurementGrid({
    required this.measurements,
  });

  @override
  Widget build(BuildContext context) {
    final items = <String, double?>{
      'Waist': measurements.waist,
      'Chest': measurements.chest,
      'Hips': measurements.hips,
      'Neck': measurements.neck,
      'Left arm': measurements.leftArm,
      'Right arm': measurements.rightArm,
      'Left thigh': measurements.leftThigh,
      'Right thigh': measurements.rightThigh,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.entries
              .map(
                (entry) => Container(
                  width: width,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text(
                        entry.value == null
                            ? '—'
                            : '${entry.value!.toStringAsFixed(1)}"',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
