import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/lab_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class LabsScreen extends ConsumerWidget {
  final bool embedded;

  const LabsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = const _LabsContent();
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Bloodwork')),
      body: content,
    );
  }
}

class _LabsContent extends ConsumerWidget {
  const _LabsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final labs = [...app.labs]
      ..sort((a, b) {
        final aa = a.date ?? DateTime(1900);
        final bb = b.date ?? DateTime(1900);
        return bb.compareTo(aa);
      });
    final dated = labs.where((lab) => lab.date != null).toList();
    final newest = dated.isEmpty ? null : dated.first.date;
    final panels = LabService.panelsForSex(app.profile.sex);

    LabResult? latestFor(String marker) {
      final matches = labs.where((lab) => lab.name == marker).toList();
      return matches.isEmpty ? null : matches.first;
    }

    return ListView(
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
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              const Text(
                'Enter the values exactly as shown on the lab report. Healthy Me stores the raw result, unit, date and source for trends and wellness context; it does not diagnose or automatically label a result high or low.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openResultDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add other result'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const HmSectionHeader(title: 'Common bloodwork'),
        const SizedBox(height: 6),
        const Text(
          'These are the routine and high-value markers Healthy Me is prepared to track. Only fill in what was actually tested.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        for (final panel in panels) ...[
          _LabPanelCard(
            panel: panel,
            latestFor: latestFor,
            onAdd: (marker) => _openResultDialog(
              context,
              ref,
              marker: marker,
            ),
            onEdit: (lab) => _openResultDialog(
              context,
              ref,
              existing: lab,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (labs.isNotEmpty) ...[
          const SizedBox(height: 12),
          const HmSectionHeader(title: 'Recent entries'),
          const SizedBox(height: 8),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
            child: Column(
              children: [
                for (var i = 0; i < labs.take(12).length; i++) ...[
                  _LabRow(
                    lab: labs[i],
                    onEdit: () => _openResultDialog(
                      context,
                      ref,
                      existing: labs[i],
                    ),
                    onDelete: () => ref
                        .read(appStateProvider.notifier)
                        .removeLab(labs[i].id),
                  ),
                  if (i != labs.take(12).length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openResultDialog(
    BuildContext context,
    WidgetRef ref, {
    LabMarkerDefinition? marker,
    LabResult? existing,
  }) async {
    final app = ref.read(appStateProvider);
    final result = await showDialog<LabResult>(
      context: context,
      builder: (_) => _LabResultDialog(
        sex: app.profile.sex,
        marker: marker,
        existing: existing,
      ),
    );
    if (result == null) return;
    if (existing == null) {
      ref.read(appStateProvider.notifier).addLab(result);
    } else {
      ref.read(appStateProvider.notifier).updateLab(result);
    }
  }

  static String _date(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';
}

class _LabPanelCard extends StatelessWidget {
  final LabPanelDefinition panel;
  final LabResult? Function(String marker) latestFor;
  final ValueChanged<LabMarkerDefinition> onAdd;
  final ValueChanged<LabResult> onEdit;

  const _LabPanelCard({
    required this.panel,
    required this.latestFor,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final entered = panel.markers
        .where((marker) => latestFor(marker.name) != null)
        .length;
    return CommandCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
          iconColor: AppTheme.cyan,
          collapsedIconColor: AppTheme.textMuted,
          title: Text(
            panel.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            entered == 0
                ? panel.description
                : '$entered of ${panel.markers.length} markers entered • ${panel.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          children: [
            for (var i = 0; i < panel.markers.length; i++) ...[
              _MarkerRow(
                marker: panel.markers[i],
                latest: latestFor(panel.markers[i].name),
                onAdd: () => onAdd(panel.markers[i]),
                onEdit: () {
                  final latest = latestFor(panel.markers[i].name);
                  if (latest != null) onEdit(latest);
                },
              ),
              if (i != panel.markers.length - 1)
                const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  final LabMarkerDefinition marker;
  final LabResult? latest;
  final VoidCallback onAdd;
  final VoidCallback onEdit;

  const _MarkerRow({
    required this.marker,
    required this.latest,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: latest == null ? onAdd : onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marker.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest == null
                        ? (marker.unit.isEmpty ? 'Not entered' : 'Expected unit: ${marker.unit}')
                        : '${latest!.value} ${latest!.unit}'.trim(),
                    style: TextStyle(
                      color: latest == null
                          ? AppTheme.textMuted
                          : AppTheme.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _LabResultDialog extends StatefulWidget {
  final String sex;
  final LabMarkerDefinition? marker;
  final LabResult? existing;

  const _LabResultDialog({
    required this.sex,
    this.marker,
    this.existing,
  });

  @override
  State<_LabResultDialog> createState() => _LabResultDialogState();
}

class _LabResultDialogState extends State<_LabResultDialog> {
  late final List<LabMarkerDefinition> _markers;
  late String _selected;
  late final TextEditingController _custom;
  late final TextEditingController _value;
  late final TextEditingController _unit;
  late final TextEditingController _source;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _markers = LabService.markersForSex(widget.sex);
    final existing = widget.existing;
    final fixed = widget.marker;
    final knownExisting = existing != null &&
        _markers.any((marker) => marker.name == existing.name);
    _selected = fixed?.name ??
        (existing == null
            ? _markers.first.name
            : knownExisting
                ? existing.name
                : 'Custom');
    _custom = TextEditingController(
      text: existing != null && !knownExisting ? existing.name : '',
    );
    _value = TextEditingController(text: existing?.value ?? '');
    final defaultUnit = fixed?.unit ??
        LabService.defaultUnitFor(widget.sex, _selected);
    _unit = TextEditingController(
      text: existing?.unit.isNotEmpty == true ? existing!.unit : defaultUnit,
    );
    _source = TextEditingController(text: existing?.source ?? '');
    _date = existing?.date;
  }

  @override
  void dispose() {
    _custom.dispose();
    _value.dispose();
    _unit.dispose();
    _source.dispose();
    super.dispose();
  }

  void _changeMarker(String next) {
    setState(() {
      _selected = next;
      if (_unit.text.trim().isEmpty || widget.existing == null) {
        _unit.text = LabService.defaultUnitFor(widget.sex, next);
      }
    });
  }

  void _save() {
    final name = widget.marker?.name ??
        (_selected == 'Custom' ? _custom.text.trim() : _selected);
    final value = _value.text.trim();
    if (name.isEmpty || value.isEmpty) return;
    Navigator.pop(
      context,
      LabResult(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        value: value,
        unit: _unit.text.trim(),
        date: _date,
        source: _source.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixed = widget.marker != null;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add lab result' : 'Edit lab result'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (fixed)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Marker'),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.marker!.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Marker'),
                  items: [
                    ..._markers.map(
                      (marker) => DropdownMenuItem(
                        value: marker.name,
                        child: Text(
                          marker.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'Custom',
                      child: Text('Custom marker'),
                    ),
                  ],
                  onChanged: (next) {
                    if (next != null) _changeMarker(next);
                  },
                ),
              if (!fixed && _selected == 'Custom') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _custom,
                  decoration: const InputDecoration(labelText: 'Custom marker'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Result value'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _source,
                decoration: const InputDecoration(
                  labelText: 'Lab / source',
                  hintText: 'VA, Quest, Labcorp, hospital…',
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Collection date'),
                subtitle: Text(
                  _date == null
                      ? 'Optional'
                      : '${_date!.month}/${_date!.day}/${_date!.year}',
                ),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date ?? now,
                    firstDate: DateTime(now.year - 20),
                    lastDate: now,
                  );
                  if (picked != null && mounted) {
                    setState(() => _date = picked);
                  }
                },
              ),
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
                    fontSize: 12.5,
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
                    fontSize: 12.5,
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
