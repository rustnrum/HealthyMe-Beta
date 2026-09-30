import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';
import 'photos_screen.dart';

class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key});

  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  String _tab = 'Weight';

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'Body',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Weight', label: Text('Weight')),
            ButtonSegment(
              value: 'Measurements',
              label: Text('Measurements'),
            ),
            ButtonSegment(
              value: 'Composition',
              label: Text('Composition'),
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (value) =>
              setState(() => _tab = value.first),
        ),
        const SizedBox(height: 14),
        if (_tab == 'Weight') _weightTab(context, app),
        if (_tab == 'Measurements') _measurementTab(context, app),
        if (_tab == 'Composition') _compositionTab(context, app),
      ],
    );
  }

  Widget _weightTab(BuildContext context, HealthyMeState app) {
    final current = app.currentWeightLb;
    final goal = app.profile.goalWeightLb;
    final start = app.profile.startingWeightLb;
    final change = current != null && start != null ? current - start : null;

    return Column(
      children: [
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weight & Goal',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      current == null
                          ? 'No weight'
                          : '${current.toStringAsFixed(1)} lb',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (goal != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Goal'),
                        Text(
                          '${goal.toStringAsFixed(0)} lb',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (change != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} lb from start',
                  style: TextStyle(
                    color: change <= 0 ? AppTheme.mint : AppTheme.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              WeightTrendChart(values: app.mergedWeightHistory),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _logWeight(context),
                icon: const Icon(Icons.add),
                label: const Text('Log weight'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _measurementPreview(context, app),
        const SizedBox(height: 12),
        _photoPreview(context, app),
      ],
    );
  }

  Widget _measurementTab(BuildContext context, HealthyMeState app) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Body Measurements',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editMeasurements(context, app.measurements),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _measurementGrid(context, app.measurements),
          const SizedBox(height: 12),
          Text(
            'Measurements are manual. Body fat is deliberately not entered here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _compositionTab(BuildContext context, HealthyMeState app) {
    final bodyFat = app.health.bodyFatPercent;

    return Column(
      children: [
        CommandCard(
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x2217C8F4),
                child: Icon(
                  Icons.monitor_weight_outlined,
                  color: AppTheme.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Body Fat',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bodyFat == null
                          ? 'Waiting for connected data'
                          : '${bodyFat.toStringAsFixed(1)}%',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bodyFat == null
                          ? 'Healthy Me does not ask you to manually type body fat.'
                          : 'From your selected connected body-fat source.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Additional body telemetry',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _dataLine(
                context,
                'Current weight',
                app.currentWeightLb == null
                    ? '—'
                    : '${app.currentWeightLb!.toStringAsFixed(1)} lb',
              ),
              _dataLine(
                context,
                'Weight source',
                app.health.weightLb != null ? 'Health Connect' : 'Manual',
              ),
              _dataLine(
                context,
                'Body-fat freshness',
                relativeAge(app.health.freshness['Body fat']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _measurementPreview(BuildContext context, HealthyMeState app) {
    return CommandCard(
      onTap: () => setState(() => _tab = 'Measurements'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Body Measurements',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text('See all'),
              SizedBox(width: 3),
              Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          _measurementGrid(context, app.measurements, preview: true),
        ],
      ),
    );
  }

  Widget _photoPreview(BuildContext context, HealthyMeState app) {
    final photos = [...app.photos]..sort((a, b) => b.date.compareTo(a.date));

    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress Photos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhotosScreen()),
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...photos.take(3).map(
                      (photo) => Container(
                        width: 82,
                        margin: const EdgeInsets.only(right: 8),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        child: File(photo.path).existsSync()
                            ? Image.file(
                                File(photo.path),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PhotosScreen()),
                  ),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 82,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add),
                        SizedBox(height: 4),
                        Text('Add'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _measurementGrid(
    BuildContext context,
    BodyMeasurements m, {
    bool preview = false,
  }) {
    final entries = <String, double?>{
      'Waist': m.waist,
      'Chest': m.chest,
      'Hips': m.hips,
      'Arms': m.leftArm,
      'Thighs': m.leftThigh,
      if (!preview) 'Neck': m.neck,
      if (!preview) 'Calves': m.leftCalf,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.entries.map((entry) {
            return Container(
              width: width,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    entry.value == null
                        ? '—'
                        : '${entry.value!.toStringAsFixed(1)}"',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _dataLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _logWeight(BuildContext context) async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (lb)'),
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

    final value = double.tryParse(controller.text.trim());
    controller.dispose();
    if (save == true && value != null) {
      ref.read(appStateProvider.notifier).logManualWeight(value);
    }
  }

  Future<void> _editMeasurements(
    BuildContext context,
    BodyMeasurements current,
  ) async {
    TextEditingController c(double? value) =>
        TextEditingController(text: value?.toStringAsFixed(1) ?? '');

    final controllers = <String, TextEditingController>{
      'Neck': c(current.neck),
      'Chest': c(current.chest),
      'Waist': c(current.waist),
      'Hips': c(current.hips),
      'Left arm': c(current.leftArm),
      'Right arm': c(current.rightArm),
      'Left thigh': c(current.leftThigh),
      'Right thigh': c(current.rightThigh),
      'Left calf': c(current.leftCalf),
      'Right calf': c(current.rightCalf),
    };

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Body measurements'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              children: controllers.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: TextField(
                        controller: entry.value,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            InputDecoration(labelText: '${entry.key} (in)'),
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

    double? read(String key) =>
        double.tryParse(controllers[key]!.text.trim());

    if (save == true) {
      ref.read(appStateProvider.notifier).saveMeasurements(
            BodyMeasurements(
              neck: read('Neck'),
              chest: read('Chest'),
              waist: read('Waist'),
              hips: read('Hips'),
              leftArm: read('Left arm'),
              rightArm: read('Right arm'),
              leftThigh: read('Left thigh'),
              rightThigh: read('Right thigh'),
              leftCalf: read('Left calf'),
              rightCalf: read('Right calf'),
            ),
          );
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}
