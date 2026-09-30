import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/lab_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

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
    final newest = labs.where((lab) => lab.date != null).isEmpty
        ? null
        : labs.where((lab) => lab.date != null).first.date;

    return Scaffold(
      appBar: AppBar(title: const Text('Bloodwork')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HmIconBadge(
                      icon: Icons.science_rounded,
                      color: AppTheme.amber,
                      size: 42,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${labs.length} result${labs.length == 1 ? '' : 's'} stored',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            newest == null
                                ? 'No dated bloodwork yet'
                                : 'Newest dated result: ${_date(newest)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                const Text(
                  'Raw values only. Healthy Me uses collection date and source for context and does not automatically label a result high or low.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _edit(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add result'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _import(context, ref),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('CSV / XLSX'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cyan,
                          side: const BorderSide(color: AppTheme.border),
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const HmSectionHeader(title: 'Results'),
          const SizedBox(height: 8),
          if (labs.isEmpty)
            const CommandCard(
              child: HmEmptyState(
                icon: Icons.science_outlined,
                title: 'No bloodwork entered',
                detail: 'Add only the results you want Healthy Me to use as slow-moving wellness context.',
              ),
            )
          else
            CommandCard(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
              child: Column(
                children: [
                  for (var i = 0; i < labs.length; i++) ...[
                    _LabRow(
                      lab: labs[i],
                      onEdit: () => _edit(context, ref, existing: labs[i]),
                      onDelete: () => ref
                          .read(appStateProvider.notifier)
                          .removeLab(labs[i].id),
                    ),
                    if (i != labs.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _date(DateTime date) => '${date.month}/${date.day}/${date.year}';

}

class _LabRow extends StatelessWidget {
  final LabResult lab;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LabRow({
    required this.lab,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.biotech_rounded,
            color: AppTheme.amber,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lab.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lab.value} ${lab.unit}'.trim(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  [
                    if (lab.date != null)
                      '${lab.date!.month}/${lab.date!.day}/${lab.date!.year}',
                    if (lab.source.isNotEmpty) lab.source,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppTheme.surfaceHigh,
            iconColor: AppTheme.textSecondary,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

