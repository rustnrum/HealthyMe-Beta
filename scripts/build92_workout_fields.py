"""Build92 additive workout-field migration on the validated Build91 source.

Never delete user data or touch Health Connect, Nutrition, or the other modules.
Exact source anchors fail closed if an upstream file changes.
"""
from pathlib import Path

def replace(path, before, after, times=1):
    p=Path(path)
    s=p.read_text()
    n=s.count(before)
    if n!=times:
        raise RuntimeError(f'{path}: expected {times} anchor, got {n}: {before[:85]!r}')
    p.write_text(s.replace(before,after))

m='lib/models/workout_models.dart'
replace(m, '  final String notes;\n  final String catalogSource;',
           "  final String notes;\n  final String phase; // Warm-up, Main, or Cool-down\n  final String catalogSource;")
replace(m, "    this.notes = '',\n    this.catalogSource = 'Manual',",
           "    this.notes = '',\n    this.phase = 'Main',\n    this.catalogSource = 'Manual',")
replace(m, '    String? notes,\n    String? catalogSource,',
           '    String? notes,\n    String? phase,\n    String? catalogSource,')
replace(m, '      notes: notes ?? this.notes,\n      catalogSource: catalogSource ?? this.catalogSource,',
           '      notes: notes ?? this.notes,\n      phase: phase ?? this.phase,\n      catalogSource: catalogSource ?? this.catalogSource,')
replace(m, "        'notes': notes,\n        'catalogSource': catalogSource,",
           "        'notes': notes,\n        'phase': phase,\n        'catalogSource': catalogSource,")
replace(m, "      notes: json['notes']?.toString() ?? '',\n      catalogSource: json['catalogSource']?.toString() ?? 'Manual',",
           "      notes: json['notes']?.toString() ?? '',\n      phase: const ['Warm-up', 'Main', 'Cool-down'].contains(json['phase'])\n          ? json['phase'] as String : 'Main',\n      catalogSource: json['catalogSource']?.toString() ?? 'Manual',")

replace(m, '  final String? templateId;\n  final List<WorkoutExercise> exercises;\n  final String notes;',
           '  final String? templateId;\n  final List<WorkoutExercise> exercises;\n  final String notes;\n  final int? plannedMinutes;\n  final String focus;')
replace(m, "    this.templateId,\n    this.exercises = const [],\n    this.notes = '',\n  });",
           "    this.templateId,\n    this.exercises = const [],\n    this.notes = '',\n    this.plannedMinutes,\n    this.focus = '',\n  });")
replace(m, '    List<WorkoutExercise>? exercises,\n    String? notes,\n  }) {\n    return ScheduledWorkout(',
           '    List<WorkoutExercise>? exercises,\n    String? notes,\n    int? plannedMinutes,\n    String? focus,\n  }) {\n    return ScheduledWorkout(')
replace(m, '      exercises: exercises ?? this.exercises,\n      notes: notes ?? this.notes,\n    );\n  }\n\n  Map<String, dynamic> toJson() => {',
           '      exercises: exercises ?? this.exercises,\n      notes: notes ?? this.notes,\n      plannedMinutes: plannedMinutes ?? this.plannedMinutes,\n      focus: focus ?? this.focus,\n    );\n  }\n\n  Map<String, dynamic> toJson() => {')
replace(m, "        'templateId': templateId,\n        'exercises': exercises.map((e) => e.toJson()).toList(),\n        'notes': notes,",
           "        'templateId': templateId,\n        'exercises': exercises.map((e) => e.toJson()).toList(),\n        'notes': notes,\n        'plannedMinutes': plannedMinutes,\n        'focus': focus,")
replace(m, "      notes: json['notes']?.toString() ?? '',\n    );\n  }\n}\n\nclass CompletedPlannedWorkout",
           "      notes: json['notes']?.toString() ?? '',\n      plannedMinutes: (json['plannedMinutes'] as num?)?.toInt(),\n      focus: json['focus']?.toString() ?? '',\n    );\n  }\n}\n\nclass CompletedPlannedWorkout")


import re
w='lib/screens/workout_screen.dart'
replace(w, '  late final TextEditingController _notesController;\n  late DateTime _date;',
           '  late final TextEditingController _notesController;\n  late final TextEditingController _durationController;\n  late final TextEditingController _focusController;\n  late DateTime _date;')
replace(w, "    _notesController = TextEditingController(text: scheduled?.notes ?? '');\n    _date =",
           "    _notesController = TextEditingController(text: scheduled?.notes ?? '');\n    _durationController = TextEditingController(\n      text: scheduled?.plannedMinutes?.toString() ?? '');\n    _focusController = TextEditingController(text: scheduled?.focus ?? '');\n    _date =")
replace(w, '    _notesController.dispose();\n    super.dispose();',
           '    _notesController.dispose();\n    _durationController.dispose();\n    _focusController.dispose();\n    super.dispose();')

p=Path(w)
s=p.read_text()
pattern=re.compile(r'(?P<i>^[ \t]*)TextField\(\n[ \t]*controller: _notesController,',re.M)
def inject_main(m):
    i=m.group('i')
    return (f"{i}TextField(\n{i}  controller: _focusController,\n"
            f"{i}  decoration: const InputDecoration(\n"
            f"{i}    labelText: 'Workout focus / type',\n"
            f"{i}    hintText: 'Upper body, Lower body, Cardio',\n"
            f"{i}  ),\n{i}),\n"
            f"{i}const SizedBox(height: 12),\n"
            f"{i}TextField(\n{i}  controller: _durationController,\n"
            f"{i}  keyboardType: TextInputType.number,\n"
            f"{i}  decoration: const InputDecoration(\n"
            f"{i}    labelText: 'Planned duration (minutes)',\n"
            f"{i}    hintText: 'Leave blank if unknown',\n"
            f"{i}  ),\n{i}),\n"
            f"{i}const SizedBox(height: 12),\n"
            f"{i}TextField(\n{i}  controller: _notesController,")
s,n=pattern.subn(inject_main,s)
if n!=1:raise RuntimeError(f'{w} workout details editor: expected 1, got {n}')
p.write_text(s)
replace(w, '  void _save() {\n    final name = _nameController.text.trim();',
           '  void _save() {\n'
           '    final durationText = _durationController.text.trim();\n'
           '    final minutes = durationText.isEmpty ? null : int.tryParse(durationText);\n'
           '    if (!widget.templateMode && durationText.isNotEmpty &&\n'
           '        (minutes == null || minutes < 1 || minutes > 600)) {\n'
           '      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(\n'
           "        content: Text('Enter 1–600 minutes or leave duration empty.')));\n"
           '      return;\n'
           '    }\n'
           '    final name = _nameController.text.trim();')
replace(w, '          notes: _notesController.text.trim(),',
           '          notes: _notesController.text.trim(),\n'
           '          plannedMinutes: minutes,\n'
           '          focus: _focusController.text.trim(),')
replace(w, '  late final TextEditingController _rest;\n  late final TextEditingController _notes;',
           '  late final TextEditingController _rest;\n  late final TextEditingController _notes;\n  late String _phase;')
replace(w, '    _notes = TextEditingController(text: exercise.notes);\n  }',
           '    _notes = TextEditingController(text: exercise.notes);\n    _phase = exercise.phase;\n  }')
p=Path(w);s=p.read_text()
pattern=re.compile(r'(?P<i>^[ \t]*)TextField\(\n[ \t]*controller: _notes,',re.M)
def inject_phase(m):
    i=m.group('i')
    return (f"{i}DropdownButtonFormField<String>(\n"
            f"{i}  initialValue: _phase,\n"
            f"{i}  decoration: const InputDecoration(labelText: 'Workout section'),\n"
            f"{i}  items: const [\n"
            f"{i}    DropdownMenuItem(value: 'Warm-up', child: Text('Warm-up')),\n"
            f"{i}    DropdownMenuItem(value: 'Main', child: Text('Main workout')),\n"
            f"{i}    DropdownMenuItem(value: 'Cool-down', child: Text('Cool-down')),\n"
            f"{i}  ],\n"
            f"{i}  onChanged: (value) {{ if (value != null) setState(() => _phase = value); }},\n"
            f"{i}),\n"
            f"{i}const SizedBox(height: 10),\n"
            f"{i}TextField(\n{i}  controller: _notes,")
s,n=pattern.subn(inject_phase,s)
if n!=1:raise RuntimeError(f'{w} workout section editor: expected 1, got {n}')
p.write_text(s)
replace(w, '        restSeconds: _nonNegativeInt(_rest.text),\n        notes: _notes.text.trim(),',
           '        restSeconds: _nonNegativeInt(_rest.text),\n        phase: _phase,\n        notes: _notes.text.trim(),')
print('Build92 optional workout duration, focus and sections integrated; old entries preserved.')
