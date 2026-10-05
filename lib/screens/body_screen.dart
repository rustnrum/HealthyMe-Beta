import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/source_name_service.dart';
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
  String _weightRange = '1M';

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        HmTabs(
          labels: const ['Weight', 'Measurements', 'Composition'],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 12),
        if (_tab == 'Weight') _weightTab(context, app),
        if (_tab == 'Measurements') _measurementTab(context, app),
        if (_tab == 'Composition') _compositionTab(context, app),
      ],
    );
  }

  Widget _weightTab(BuildContext context, HealthyMeState app) {
    final current = app.currentWeightLb;
    final goal = app.profile.goalWeightLb;
    final history = _filterWeightHistory(app.mergedWeightHistory, _weightRange);
    final allHistory = app.mergedWeightHistory;
    final first = allHistory.isEmpty
        ? app.profile.startingWeightLb
        : allHistory.first.pounds;
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _editGoal(context, app),
                    child: const Text('Edit goal'),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              current == null ? '—' : current.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 5, bottom: 5),
                              child: Text(
                                'lb',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (change != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} lb since first entry',
                            style: TextStyle(
                              color: change <= 0 ? AppTheme.mint : AppTheme.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          app.health.weightLb == null
                              ? 'Source: Manual'
                              : 'Source: ${_sourceLabel(app, 'Weight')}',
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (app.health.freshness['Weight'] != null)
                          Text(
                            'Weight data ${relativeAge(app.health.freshness['Weight'])}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 68, color: AppTheme.border),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Goal',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        goal == null ? '—' : '${goal.toStringAsFixed(0)} lb',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              WeightTrendChart(values: history),
              const SizedBox(height: 10),
              _RangeSelector(
                selected: _weightRange,
                onChanged: (value) => setState(() => _weightRange = value),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _logWeight(context),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Log weight'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        HmSectionHeader(
          title: 'Body Measurements',
          action: 'See all',
          onAction: () => setState(() => _tab = 'Measurements'),
        ),
        const SizedBox(height: 10),
        _measurementGrid(app.measurements, preview: true),
        const SizedBox(height: 12),
        _bodyFatCard(app),
        const SizedBox(height: 22),
        HmSectionHeader(
          title: 'Progress Photos',
          action: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PhotosScreen()),
          ),
        ),
        const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              _measurementGrid(app.measurements),
              const SizedBox(height: 12),
              const Text(
                'Tape measurements are manual. Body-fat percentage comes only from a connected compatible source.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _photoCard(context, app),
      ],
    );
  }

  Widget _compositionTab(BuildContext context, HealthyMeState app) {
    final bmi = _bmi(app);
    return Column(
      children: [
        _bmiCard(app),
        const SizedBox(height: 12),
        _bodyFatCard(app),
        const SizedBox(height: 12),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Composition telemetry',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _dataLine(
                'Weight',
                app.currentWeightLb == null
                    ? '—'
                    : '${app.currentWeightLb!.toStringAsFixed(1)} lb',
              ),
              _dataLine(
                'Weight type',
                app.health.weightLb != null ? 'Device reading' : 'Manual',
              ),
              _dataLine(
                'Weight source',
                app.health.weightLb != null ? _sourceLabel(app, 'Weight') : 'Manual',
              ),
              _dataLine(
                'BMI',
                bmi == null ? '—' : bmi.toStringAsFixed(1),
              ),
              _dataLine('BMI type', 'Calculated'),
              _dataLine(
                'Body fat type',
                app.health.bodyFatPercent == null ? 'No device reading' : 'Device reading',
              ),
              if (app.health.bodyFatPercent != null)
                _dataLine('Body fat source', _sourceLabel(app, 'Body fat')),
              if (app.health.bodyWaterMassKg != null)
                _dataLine(
                  'Body water',
                  _bodyWaterLabel(app),
                ),
              if (app.health.bodyWaterMassKg != null)
                _dataLine('Body water source', _sourceLabel(app, 'Body water')),
              if (app.health.leanBodyMassKg != null)
                _dataLine(
                  'Lean body mass',
                  '${(app.health.leanBodyMassKg! * 2.2046226218).toStringAsFixed(1)} lb',
                ),
              if (app.health.leanBodyMassKg != null)
                _dataLine('Lean mass source', _sourceLabel(app, 'Lean body mass')),
              if (app.health.bodyFatPercent != null)
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

  Widget _bmiCard(HealthyMeState app) {
    final bmi = _bmi(app);
    return CommandCard(
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.calculate_rounded,
            color: AppTheme.mint,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'BMI',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    HmStatusPill(text: 'Calculated', color: AppTheme.mint),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bmi == null ? '—' : bmi.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  bmi == null
                      ? 'Add height and a current weight to calculate BMI.'
                      : 'Calculated locally from your current weight and profile height.',
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

  double? _bmi(HealthyMeState app) {
    final height = app.profile.heightIn;
    final weight = app.currentWeightLb;
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      return null;
    }
    return (weight * 703) / (height * height);
  }

  Widget _bodyFatCard(HealthyMeState app) {
    final bodyFat = app.health.bodyFatPercent;
    return CommandCard(
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.monitor_weight_outlined,
            color: AppTheme.cyan,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Body Fat',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    HmStatusPill(
                      text: bodyFat == null ? 'No reading' : 'Measured',
                      color: bodyFat == null ? AppTheme.textMuted : AppTheme.cyan,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  bodyFat == null
                      ? '—'
                      : '${bodyFat.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  bodyFat == null
                      ? 'Salus does not ask you to manually enter body fat.'
                      : 'Device body-fat reading from ${_sourceLabel(app, 'Body fat')}.',
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

  String _sourceLabel(HealthyMeState app, String metric) {
    final key = app.health.resolvedSources[metric];
    if (key == null || key.isEmpty) return 'Connected source';
    return app.health.sourceLabels[key] ?? SourceNameService.friendly(key);
  }

  String _bodyWaterLabel(HealthyMeState app) {
    final kg = app.health.bodyWaterMassKg;
    if (kg == null) return '—';
    final pounds = kg * 2.2046226218;
    final weight = app.health.weightLb;
    final waterSource = app.health.resolvedSources['Body water'];
    final weightSource = app.health.resolvedSources['Weight'];
    if (weight != null &&
        weight > 0 &&
        waterSource != null &&
        weightSource != null &&
        SourceNameService.sameProvider(waterSource, weightSource)) {
      final percent = (pounds / weight * 100).clamp(0, 100);
      return '${percent.toStringAsFixed(1)}% • ${pounds.toStringAsFixed(1)} lb';
    }
    return '${pounds.toStringAsFixed(1)} lb';
  }

  Widget _measurementGrid(BodyMeasurements m, {bool preview = false}) {
    final entries = <(String, double?, IconData, Color)>[
      ('Waist', m.waist, Icons.straighten_rounded, AppTheme.cyan),
      ('Chest', m.chest, Icons.accessibility_new_rounded, AppTheme.mint),
      ('Hips', m.hips, Icons.straighten_rounded, AppTheme.amber),
      ('Arms', m.leftArm, Icons.fitness_center_rounded, AppTheme.cyan),
      ('Thighs', m.leftThigh, Icons.directions_walk_rounded, AppTheme.purple),
      if (!preview)
        ('Neck', m.neck, Icons.radio_button_unchecked_rounded, AppTheme.rose),
      if (!preview)
        ('Calves', m.leftCalf, Icons.directions_walk_rounded, AppTheme.mint),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 74),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.$3, size: 20, color: entry.$4),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.$1,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.$2 == null
                                  ? '—'
                                  : '${entry.$2!.toStringAsFixed(1)} in',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 17, color: AppTheme.textMuted),
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
          const SizedBox(height: 10),
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
            borderRadius: BorderRadius.circular(13),
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
          borderRadius: BorderRadius.circular(13),
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.photo_outlined,
          color: AppTheme.textMuted,
          size: 28,
        ),
      );
    }

    return SizedBox(
      height: 116,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: photoSlot(i)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PhotosScreen()),
              ),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.textMuted),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.textSecondary, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  List<WeightPoint> _filterWeightHistory(List<WeightPoint> source, String range) {
    if (source.isEmpty || range == 'ALL') return source;
    final now = DateTime.now();
    final days = switch (range) {
      '1W' => 7,
      '1M' => 31,
      '3M' => 93,
      '6M' => 186,
      '1Y' => 366,
      _ => 31,
    };
    final cutoff = now.subtract(Duration(days: days));
    final result = source.where((item) => item.date.isAfter(cutoff)).toList();
    return result.isEmpty ? source : result;
  }

  Future<void> _editGoal(BuildContext context, HealthyMeState app) async {
    final controller = TextEditingController(
      text: app.profile.goalWeightLb?.toStringAsFixed(0) ?? '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit weight goal'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Goal weight (lb)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final value = double.tryParse(controller.text.trim());
    controller.dispose();
    if (save == true && value != null) {
      ref.read(appStateProvider.notifier).saveProfile(
            app.profile.copyWith(goalWeightLb: value),
          );
    }
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
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
    final result = await showDialog<BodyMeasurements>(
      context: context,
      builder: (_) => _MeasurementsDialog(current: current),
    );
    if (result != null) {
      ref.read(appStateProvider.notifier).saveMeasurements(result);
    }
  }

}


class _MeasurementsDialog extends StatefulWidget {
  final BodyMeasurements current;

  const _MeasurementsDialog({required this.current});

  @override
  State<_MeasurementsDialog> createState() => _MeasurementsDialogState();
}

class _MeasurementsDialogState extends State<_MeasurementsDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    TextEditingController c(double? value) =>
        TextEditingController(text: value?.toStringAsFixed(1) ?? '');
    final current = widget.current;
    _controllers = {
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
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _value(String key) =>
      double.tryParse(_controllers[key]!.text.trim());

  void _save() {
    Navigator.pop(
      context,
      BodyMeasurements(
        neck: _value('Neck'),
        chest: _value('Chest'),
        waist: _value('Waist'),
        hips: _value('Hips'),
        leftArm: _value('Left arm'),
        rightArm: _value('Right arm'),
        leftThigh: _value('Left thigh'),
        rightThigh: _value('Right thigh'),
        leftCalf: _value('Left calf'),
        rightCalf: _value('Right calf'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Body measurements'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final entry in _controllers.entries) ...[
                TextField(
                  controller: entry.value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '${entry.key} (in)'),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _RangeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const ranges = ['1W', '1M', '3M', '6M', '1Y', 'ALL'];
    return Row(
      children: [
        for (final range in ranges)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(range),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: selected == range ? AppTheme.cyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    range,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected == range ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
