import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bloodwork_result.dart';
import '../providers/labs_provider.dart';
import '../providers/profile_provider.dart';
import '../services/lab_import_service.dart';
import '../services/lab_markers.dart';
import '../widgets/section_card.dart';

class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

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

      if (results.isNotEmpty) {
        ref.read(labsProvider.notifier).addAll(results);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            results.isEmpty
                ? 'No usable lab rows were found.'
                : 'Imported ${results.length} result${results.length == 1 ? '' : 's'}.',
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

  Future<void> _editResult(
    BuildContext context,
    WidgetRef ref, {
    BloodworkResult? existing,
    required String sex,
  }) async {
    final markers = LabMarkers.forSex(sex);
    final markerController = TextEditingController(
      text: existing?.testName ?? markers.first,
    );
    final valueController =
        TextEditingController(text: existing?.resultValue ?? '');
    final unitController = TextEditingController(text: existing?.unit ?? '');
    final sourceController =
        TextEditingController(text: existing?.labSource ?? '');
    var collectionDate = existing?.collectionDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add lab result' : 'Edit lab result'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: markerController.text),
                        optionsBuilder: (value) {
                          final query = value.text.toLowerCase();
                          return markers.where(
                            (item) => item.toLowerCase().contains(query),
                          );
                        },
                        onSelected: (value) => markerController.text = value,
                        fieldViewBuilder:
                            (context, controller, focusNode, onSubmitted) {
                          controller.addListener(
                            () => markerController.text = controller.text,
                          );
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Test / marker',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valueController,
                        decoration: const InputDecoration(
                          labelText: 'Result value',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sourceController,
                        decoration: const InputDecoration(
                          labelText: 'Lab source',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Collection date'),
                        subtitle: Text(
                          collectionDate == null
                              ? 'Optional'
                              : '${collectionDate!.month}/${collectionDate!.day}/${collectionDate!.year}',
                        ),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: collectionDate ?? now,
                            firstDate: DateTime(now.year - 20),
                            lastDate: now,
                          );
                          if (picked != null) {
                            setDialogState(() => collectionDate = picked);
                          }
                        },
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
            );
          },
        );
      },
    );

    if (saved == true &&
        markerController.text.trim().isNotEmpty &&
        valueController.text.trim().isNotEmpty) {
      final result = BloodworkResult(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        testName: markerController.text.trim(),
        resultValue: valueController.text.trim(),
        unit: unitController.text.trim(),
        collectionDate: collectionDate,
        labSource: sourceController.text.trim(),
      );

      if (existing == null) {
        ref.read(labsProvider.notifier).add(result);
      } else {
        ref.read(labsProvider.notifier).update(result);
      }
    }

    markerController.dispose();
    valueController.dispose();
    unitController.dispose();
    sourceController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);
    final profile = ref.watch(profileProvider);

    final sorted = [...labs]
      ..sort((a, b) {
        final aDate = a.collectionDate ?? DateTime(1900);
        final bDate = b.collectionDate ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text(
          'Bloodwork',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your observed numbers, without diagnostic high/low labels.',
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${labs.length} result${labs.length == 1 ? '' : 's'} stored',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${LabMarkers.forSex(profile.sex).length} suggested markers for this profile, plus custom markers.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _editResult(context, ref, sex: profile.sex),
                    icon: const Icon(Icons.add),
                    label: const Text('Add result'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _import(context, ref),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV / XLSX'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (sorted.isEmpty)
          const SectionCard(
            child: Column(
              children: [
                Icon(Icons.science_outlined, size: 42),
                SizedBox(height: 12),
                Text(
                  'No bloodwork entered',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Add only the results you want Healthy Me to use as wellness context.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...sorted.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.testName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${result.resultValue} ${result.unit}'.trim(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (result.collectionDate != null)
                                '${result.collectionDate!.month}/${result.collectionDate!.day}/${result.collectionDate!.year}',
                              if (result.labSource.isNotEmpty) result.labSource,
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editResult(
                            context,
                            ref,
                            existing: result,
                            sex: profile.sex,
                          );
                        } else if (value == 'delete') {
                          ref.read(labsProvider.notifier).remove(result.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
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
