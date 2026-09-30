import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bloodwork_result.dart';
import '../providers/labs_provider.dart';
import '../providers/profile_provider.dart';
import '../services/lab_import_service.dart';
import '../widgets/section_card.dart';

class BloodworkScreen extends ConsumerWidget {
  const BloodworkScreen({super.key});

  List<String> _markersForSex(String sex) {
    const common = [
      'A1C',
      'Fasting glucose',
      'LDL',
      'HDL',
      'Triglycerides',
      'Vitamin D',
      'Ferritin',
      'Hemoglobin',
    ];

    if (sex == 'Female') {
      return [
        ...common,
        'Estradiol',
        'FSH',
        'LH',
        'Total testosterone',
      ];
    }

    return [
      ...common,
      'Total testosterone',
      'Free testosterone',
    ];
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();

      final lower = file.name.toLowerCase();
      final results = lower.endsWith('.xlsx')
          ? LabImportService.parseXlsx(bytes)
          : LabImportService.parseCsv(bytes);

      ref.read(labsProvider.notifier).addAll(results);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            results.isEmpty
                ? 'No usable lab rows found.'
                : 'Imported ${results.length} lab result${results.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }

  Future<void> _addManual(
    BuildContext context,
    WidgetRef ref,
    String sex,
  ) async {
    final marker = ValueNotifier<String>(_markersForSex(sex).first);
    final valueController = TextEditingController();
    final unitController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add bloodwork result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder(
                valueListenable: marker,
                builder: (context, selected, _) {
                  return DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: _markersForSex(sex)
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (next) {
                      if (next != null) marker.value = next;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Test',
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Result value'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
            ],
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
        );
      },
    );

    if (shouldSave == true && valueController.text.trim().isNotEmpty) {
      ref.read(labsProvider.notifier).add(
            BloodworkResult(
              testName: marker.value,
              resultValue: valueController.text.trim(),
              unit: unitController.text.trim(),
            ),
          );
    }

    marker.dispose();
    valueController.dispose();
    unitController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);
    final profile = ref.watch(profileProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Bloodwork',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Store the observed result. Healthy Me does not label it high/low or diagnose it.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Male', label: Text('Male')),
                  ButtonSegment(value: 'Female', label: Text('Female')),
                ],
                selected: {profile.sex},
                onSelectionChanged: (values) {
                  ref.read(profileProvider.notifier).setSex(values.first);
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _import(context, ref),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV/XLSX'),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        _addManual(context, ref, profile.sex),
                    icon: const Icon(Icons.add),
                    label: const Text('Add result'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (labs.isEmpty)
          const SectionCard(
            child: Text(
              'No bloodwork entered yet. Import an Excel/CSV file or add a result manually.',
            ),
          )
        else
          ...labs.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.testName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.value.resultValue} ${entry.value.unit}'.trim(),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => ref
                              .read(labsProvider.notifier)
                              .removeAt(entry.key),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
