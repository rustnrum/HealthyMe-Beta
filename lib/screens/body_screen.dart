import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        HmTabs(
          labels: const ['Weight', 'Measurements', 'Composition'],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 10),
        if (_tab == 'Weight') _weightTab(context, app),
        if (_tab == 'Measurements') _measurementTab(context, app),
        if (_tab == 'Composition') _compositionTab(context, app),
      ],
    );
  }

  Widget _weightTab(BuildContext context, HealthyMeState app) {
    final current = app.currentWeightLb;
    final goal = app.profile.goalWeightLb;
    final history = app.mergedWeightHistory;
    final first = history.isEmpty ? app.profile.startingWeightLb : history.first.pounds;
    final change = current != null && first != null ? current - first : null;

    return Column(
      children: [
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Weight & Goal',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _logWeight(context),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Log weight', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current == null ? '—' : current.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const Text(
                          'lb',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (change != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} lb since first entry',
                            style: TextStyle(
                              color: change <= 0 ? AppTheme.mint : AppTheme.amber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 64,
                    color: AppTheme.border,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Goal',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal == null ? '—' : '${goal.toStringAsFixed(0)} lb',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WeightTrendChart(values: history),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HmSectionHeader(
          title: 'Body Measurements',
          action: 'See all',
          onAction: () => setState(() => _tab = 'Measurements'),
        ),
        const SizedBox(height: 8),
        _measurementGrid(app.measurements, preview: true),
        const SizedBox(height: 12),
        _bodyFatCard(app),
        const SizedBox(height: 16),
        HmSectionHeader(
          title: 'Progress Photos',
          action: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PhotosScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _photoRow(context, app),
      ],
    );
  }

  Widget _measurementTab(BuildContext context, HealthyMeState app) {
    return Column(
      children: [
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HmSectionHeader(
                title: 'Body Measurements',
                action: 'Edit',
                onAction: () => _editMeasurements(context, app.measurements),
              ),
              const SizedBox(height: 10),
              _measurementGrid(app.measurements),
              const SizedBox(height: 10),
              const Text(
                'Measurements are manual entries. Body fat remains connected-source only.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _photoCard(context, app),
      ],
    );
  }

  Widget _compositionTab(BuildContext context, HealthyMeState app) {
    return Column(
      children: [
        _bodyFatCard(app),
        const SizedBox(height: 10),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Composition telemetry',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _dataLine(
                'Weight',
                app.currentWeightLb == null
                    ? '—'
                    : '${app.currentWeightLb!.toStringAsFixed(1)} lb',
              ),
              _dataLine(
                'Weight source',
                app.health.weightLb != null ? 'Connected source' : 'Manual',
              ),
              _dataLine(
                'Body-fat freshness',
                relativeAge(app.health.freshness['Body fat']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bodyFatCard(HealthyMeState app) {
    final bodyFat = app.health.bodyFatPercent;
    return CommandCard(
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.monitor_weight_outlined,
            color: AppTheme.cyan,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Body Fat',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bodyFat == null ? 'No connected reading' : '${bodyFat.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  bodyFat == null
                      ? 'Body fat is never manually entered.'
                      : 'From the selected connected scale/source.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }

  Widget _measurementGrid(BodyMeasurements m, {bool preview = false}) {
    final entries = <(String, double?, IconData, Color)>[
      ('Waist', m.waist, Icons.straighten_rounded, AppTheme.cyan),
      ('Chest', m.chest, Icons.accessibility_new_rounded, AppTheme.mint),
      ('Hips', m.hips, Icons.straighten_rounded, AppTheme.amber),
      ('Arms', m.leftArm, Icons.fitness_center_rounded, AppTheme.cyan),
      ('Thighs', m.leftThigh, Icons.directions_walk_rounded, AppTheme.purple),
      if (!preview) ('Neck', m.neck, Icons.radio_button_unchecked_rounded, AppTheme.rose),
      if (!preview) ('Calves', m.leftCalf, Icons.directions_walk_rounded, AppTheme.mint),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.$3, size: 15, color: entry.$4),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.$1,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              entry.$2 == null
                                  ? '—'
                                  : '${entry.$2!.toStringAsFixed(1)} in',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _photoCard(BuildContext context, HealthyMeState app) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmSectionHeader(
            title: 'Progress Photos',
            action: 'Open',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PhotosScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _photoRow(context, app),
        ],
      ),
    );
  }

  Widget _photoRow(BuildContext context, HealthyMeState app) {
    final photos = [...app.photos]..sort((a, b) => b.date.compareTo(a.date));
    final shown = photos.take(3).toList();

    Widget photoSlot(int index) {
      if (index < shown.length) {
        final photo = shown[index];
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
          ),
          child: File(photo.path).existsSync()
              ? Image.file(File(photo.path), fit: BoxFit.cover)
              : const Icon(Icons.image_not_supported_outlined),
        );
      }
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.photo_outlined,
          color: AppTheme.textMuted,
          size: 22,
        ),
      );
    }

    return SizedBox(
      height: 104,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: photoSlot(i)),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PhotosScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.textMuted),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.textSecondary),
                    SizedBox(height: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              children: [
                for (final entry in controllers.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: TextField(
                      controller: entry.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: '${entry.key} (in)'),
                    ),
                  ),
              ],
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

    double? read(String key) => double.tryParse(controllers[key]!.text.trim());

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
