import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/lab_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';

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
      final labs = lower.endsWith('.xlsx')
          ? LabService.parseXlsx(bytes)
          : LabService.parseCsv(bytes);

      if (labs.isNotEmpty) {
        ref.read(appStateProvider.notifier).addLabs(labs);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            labs.isEmpty
                ? 'No usable lab rows were found.'
                : 'Imported ${labs.length} lab result${labs.length == 1 ? '' : 's'}.',
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

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    LabResult? existing,
  }) async {
    final app = ref.read(appStateProvider);
    final markers = LabService.markersForSex(app.profile.sex);
    final knownExisting =
        existing != null && markers.contains(existing.name);
    var selected = existing == null
        ? markers.first
        : knownExisting
            ? existing.name
            : 'Custom';

    final custom = TextEditingController(
      text: existing != null && !knownExisting ? existing.name : '',
    );
    final value = TextEditingController(text: existing?.value ?? '');
    final unit = TextEditingController(text: existing?.unit ?? '');
    final source = TextEditingController(text: existing?.source ?? '');
    var date = existing?.date;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add lab result' : 'Edit lab result'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Marker'),
                      items: [
                        ...markers.map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'Custom',
                          child: Text('Custom marker'),
                        ),
                      ],
                      onChanged: (next) {
                        if (next != null) {
                          setDialogState(() => selected = next);
                        }
                      },
                    ),
                    if (selected == 'Custom') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: custom,
                        decoration:
                            const InputDecoration(labelText: 'Custom marker'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: value,
                      decoration:
                          const InputDecoration(labelText: 'Result value'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: source,
                      decoration:
                          const InputDecoration(labelText: 'Lab / source'),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Collection date'),
                      subtitle: Text(
                        date == null
                            ? 'Optional'
                            : '${date!.month}/${date!.day}/${date!.year}',
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date ?? now,
                          firstDate: DateTime(now.year - 20),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setDialogState(() => date = picked);
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
      ),
    );

    final markerName =
        selected == 'Custom' ? custom.text.trim() : selected;

    if (save == true &&
        markerName.isNotEmpty &&
        value.text.trim().isNotEmpty) {
      final lab = LabResult(
        id: existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: markerName,
        value: value.text.trim(),
        unit: unit.text.trim(),
        date: date,
        source: source.text.trim(),
      );

      if (existing == null) {
        ref.read(appStateProvider.notifier).addLab(lab);
      } else {
        ref.read(appStateProvider.notifier).updateLab(lab);
      }
    }

    custom.dispose();
    value.dispose();
    unit.dispose();
    source.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final labs = [...app.labs]
      ..sort((a, b) {
        final aa = a.date ?? DateTime(1900);
        final bb = b.date ?? DateTime(1900);
        return bb.compareTo(aa);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bloodwork',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${labs.length} result${labs.length == 1 ? '' : 's'} stored',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Healthy Me stores the observed value and its age. It does not diagnose a result as high or low.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _edit(context, ref),
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
          const SizedBox(height: 14),
          if (labs.isEmpty)
            const CommandCard(
              child: Column(
                children: [
                  Icon(Icons.science_outlined, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'No bloodwork entered',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Bloodwork is slow-moving context. Add it when you have it; the daily command center works without it.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...labs.map(
              (lab) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: CommandCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lab.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${lab.value} ${lab.unit}'.trim(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (lab.date != null)
                                  '${lab.date!.month}/${lab.date!.day}/${lab.date!.year}',
                                if (lab.source.isNotEmpty) lab.source,
                              ].join(' • '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (choice) {
                          if (choice == 'edit') {
                            _edit(context, ref, existing: lab);
                          } else if (choice == 'delete') {
                            ref
                                .read(appStateProvider.notifier)
                                .removeLab(lab.id);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
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
}
