import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../models/workout_models.dart';
import '../state/app_state.dart';
import '../state/workout_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import '../widgets/module_menu_button.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  String _tab = 'Today';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(workoutStateProvider);
    final health = ref.watch(appStateProvider).health;

    void selectModule(HealthyMeModule module) {
      switch (module) {
        case HealthyMeModule.fitness:
          Navigator.of(context).popUntil((route) => route.isFirst);
          break;
        case HealthyMeModule.workout:
          break;
        case HealthyMeModule.diet:
          Navigator.of(context).pushReplacementNamed('/diet');
          break;
        case HealthyMeModule.health:
          Navigator.of(context).pushReplacementNamed('/health');
          break;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          HealthyMeModuleMenuButton(
            current: HealthyMeModule.workout,
            onSelected: selectModule,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: HmTabs(
                labels: const ['Today', 'Schedule', 'Templates', 'History'],
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
            ),
            Expanded(
              child: !library.loaded
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTab(context, library, health),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    WorkoutLibraryState library,
    HealthSnapshot health,
  ) {
    return switch (_tab) {
      'Schedule' => _ScheduleView(library: library),
      'Templates' => _TemplatesView(library: library),
      'History' => _HistoryView(library: library, connected: health.workouts),
      _ => _TodayView(library: library, connected: health.workouts),
    };
  }
}

class _TodayView extends StatelessWidget {
  final WorkoutLibraryState library;
  final List<WorkoutEntry> connected;

  const _TodayView({required this.library, required this.connected});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final planned = library.scheduled
        .where((item) => _sameDay(item.scheduledFor, today))
        .toList();
    final connectedToday = connected
        .where((item) => _sameDay(item.start, today))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        CommandCard(
          child: Row(
            children: [
              const HmIconBadge(
                icon: Icons.fitness_center_rounded,
                color: AppTheme.mint,
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(today),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      planned.isEmpty
                          ? 'No workout planned yet'
                          : '${planned.length} planned workout${planned.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openScheduledEditor(context, date: today),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Plan'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const HmSectionHeader(title: 'Today'),
        const SizedBox(height: 10),
        if (planned.isEmpty)
          CommandCard(
            child: Column(
              children: [
                const HmEmptyState(
                  icon: Icons.calendar_today_rounded,
                  title: 'Nothing scheduled today',
                  detail: 'Build a workout from scratch or start from one of your templates.',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openScheduledEditor(context, date: today),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Plan workout'),
                  ),
                ),
              ],
            ),
          )
        else
          ...planned.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlannedWorkoutCard(workout: item),
            ),
          ),
        const SizedBox(height: 14),
        HmSectionHeader(
          title: 'Connected activity',
          action: connectedToday.isEmpty ? null : '${connectedToday.length} today',
        ),
        const SizedBox(height: 10),
        if (connectedToday.isEmpty)
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.sync_rounded,
              title: 'No connected workout today',
              detail: 'Exercise sessions imported through your health source will appear here.',
            ),
          )
        else
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < connectedToday.length; i++) ...[
                  _ConnectedWorkoutRow(workout: connectedToday[i]),
                  if (i != connectedToday.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ScheduleView extends StatelessWidget {
  final WorkoutLibraryState library;

  const _ScheduleView({required this.library});

  @override
  Widget build(BuildContext context) {
    final items = [...library.scheduled]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Workout schedule',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (date != null && context.mounted) {
                  _openScheduledEditor(context, date: date);
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.event_available_rounded,
              title: 'No workouts scheduled',
              detail: 'Choose a day, then build a workout or use a saved template.',
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ScheduledRow(workout: item),
            ),
          ),
      ],
    );
  }
}

class _TemplatesView extends ConsumerWidget {
  final WorkoutLibraryState library;

  const _TemplatesView({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout templates',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Your library stays provider-independent.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openTemplateEditor(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (library.templates.isEmpty)
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.view_list_rounded,
              title: 'No templates yet',
              detail: 'Create your own exercises now. A future exercise catalog or import source can plug into the same template structure.',
            ),
          )
        else
          ...library.templates.map(
            (template) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CommandCard(
                child: Row(
                  children: [
                    const HmIconBadge(
                      icon: Icons.fitness_center_rounded,
                      color: AppTheme.cyan,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${template.exercises.length} exercise${template.exercises.length == 1 ? '' : 's'} • ${template.source}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit template',
                      onPressed: () => _openTemplateEditor(context, existing: template),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          ref.read(workoutStateProvider.notifier).deleteTemplate(template.id);
                        }
                      },
                      itemBuilder: (_) => const [
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

class _HistoryView extends StatelessWidget {
  final WorkoutLibraryState library;
  final List<WorkoutEntry> connected;

  const _HistoryView({required this.library, required this.connected});

  @override
  Widget build(BuildContext context) {
    final local = [...library.history]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final imported = [...connected]..sort((a, b) => b.start.compareTo(a.start));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        const HmSectionHeader(title: 'Completed in Salus'),
        const SizedBox(height: 10),
        if (local.isEmpty)
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.history_rounded,
              title: 'No completed planned workouts yet',
              detail: 'Mark a scheduled workout complete and it will be kept here.',
            ),
          )
        else
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < local.length; i++) ...[
                  _LocalHistoryRow(workout: local[i]),
                  if (i != local.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        const HmSectionHeader(title: 'Connected workout history'),
        const SizedBox(height: 10),
        if (imported.isEmpty)
          const CommandCard(
            child: HmEmptyState(
              icon: Icons.sync_rounded,
              title: 'No imported workouts yet',
              detail: 'Workouts from connected health providers will appear here automatically.',
            ),
          )
        else
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < imported.length; i++) ...[
                  _ConnectedWorkoutRow(workout: imported[i]),
                  if (i != imported.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PlannedWorkoutCard extends ConsumerWidget {
  final ScheduledWorkout workout;

  const _PlannedWorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HmIconBadge(
                icon: Icons.fitness_center_rounded,
                color: AppTheme.mint,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${workout.exercises.length} exercise${workout.exercises.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _openScheduledEditor(
                  context,
                  date: workout.scheduledFor,
                  existing: workout,
                ),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          if (workout.exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final exercise in workout.exercises.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _exerciseSummary(exercise),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => ref
                  .read(workoutStateProvider.notifier)
                  .completeScheduled(workout.id),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Mark complete'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledRow extends ConsumerWidget {
  final ScheduledWorkout workout;

  const _ScheduledRow({required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommandCard(
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.event_rounded,
            color: AppTheme.purple,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateLabel(workout.scheduledFor)} • ${workout.exercises.length} exercises',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openScheduledEditor(
              context,
              date: workout.scheduledFor,
              existing: workout,
            ),
            icon: const Icon(Icons.edit_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'complete') {
                ref.read(workoutStateProvider.notifier).completeScheduled(workout.id);
              } else if (value == 'delete') {
                ref.read(workoutStateProvider.notifier).deleteScheduled(workout.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'complete', child: Text('Mark complete')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedWorkoutRow extends StatelessWidget {
  final WorkoutEntry workout;

  const _ConnectedWorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.directions_run_rounded,
            color: AppTheme.cyan,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.type,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${shortDate(workout.start)} • ${workout.minutes} min • ${workout.source}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalHistoryRow extends StatelessWidget {
  final CompletedPlannedWorkout workout;

  const _LocalHistoryRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.mint,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${shortDate(workout.completedAt)} • ${workout.exercises.length} exercises • Salus',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openTemplateEditor(
  BuildContext context, {
  WorkoutTemplate? existing,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _WorkoutBuilderScreen.template(existing: existing),
    ),
  );
}

Future<void> _openScheduledEditor(
  BuildContext context, {
  required DateTime date,
  ScheduledWorkout? existing,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _WorkoutBuilderScreen.schedule(
        date: date,
        existing: existing,
      ),
    ),
  );
}

class _WorkoutBuilderScreen extends ConsumerStatefulWidget {
  final bool templateMode;
  final WorkoutTemplate? existingTemplate;
  final ScheduledWorkout? existingScheduled;
  final DateTime? initialDate;

  const _WorkoutBuilderScreen.template({WorkoutTemplate? existing})
      : templateMode = true,
        existingTemplate = existing,
        existingScheduled = null,
        initialDate = null;

  const _WorkoutBuilderScreen.schedule({
    required DateTime date,
    ScheduledWorkout? existing,
  })  : templateMode = false,
        initialDate = date,
        existingScheduled = existing,
        existingTemplate = null;

  @override
  ConsumerState<_WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends ConsumerState<_WorkoutBuilderScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late List<WorkoutExercise> _exercises;
  String? _templateId;

  @override
  void initState() {
    super.initState();
    final template = widget.existingTemplate;
    final scheduled = widget.existingScheduled;
    _nameController = TextEditingController(
      text: template?.name ?? scheduled?.name ?? '',
    );
    _notesController = TextEditingController(text: scheduled?.notes ?? '');
    _date = scheduled?.scheduledFor ?? widget.initialDate ?? DateTime.now();
    _exercises = [
      ...(template?.exercises ?? scheduled?.exercises ?? const <WorkoutExercise>[]),
    ];
    _templateId = scheduled?.templateId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(workoutStateProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.templateMode ? 'Workout template' : 'Plan workout'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: widget.templateMode ? 'Template name' : 'Workout name',
                    hintText: widget.templateMode ? 'Push day' : 'Monday workout',
                  ),
                ),
                if (!widget.templateMode) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Scheduled day'),
                          subtitle: Text(_dateLabel(_date)),
                          trailing: const Icon(Icons.calendar_month_rounded),
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),
                  if (library.templates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _templateId ?? '',
                      decoration: const InputDecoration(labelText: 'Start from template'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No template'),
                        ),
                        ...library.templates.map(
                          (template) => DropdownMenuItem<String>(
                            value: template.id,
                            child: Text(template.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          final selectedId = (value == null || value.isEmpty) ? null : value;
                          _templateId = selectedId;
                          if (selectedId != null) {
                            final selected = library.templates
                                .where((item) => item.id == selectedId)
                                .first;
                            _nameController.text = selected.name;
                            _exercises = [...selected.exercises];
                          }
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Workout notes',
                      hintText: 'Optional notes for this day',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          HmSectionHeader(
            title: 'Exercises',
            action: 'Add exercise',
            onAction: _addExercise,
          ),
          const SizedBox(height: 10),
          if (_exercises.isEmpty)
            CommandCard(
              child: Column(
                children: [
                  const HmEmptyState(
                    icon: Icons.add_task_rounded,
                    title: 'No exercises yet',
                    detail: 'Add any exercise and enter your sets, reps, weight, rest and notes.',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add exercise'),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(
              _exercises.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CommandCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HmIconBadge(
                        icon: Icons.fitness_center_rounded,
                        color: AppTheme.cyan,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _exercises[index].name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _exerciseSummary(_exercises[index]),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                            if (_exercises[index].notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _exercises[index].notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit exercise',
                        onPressed: () => _editExercise(index),
                        icon: const Icon(Icons.edit_rounded),
                      ),
                      IconButton(
                        tooltip: 'Remove exercise',
                        onPressed: () => setState(() => _exercises.removeAt(index)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(widget.templateMode ? 'Save template' : 'Save workout'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addExercise() async {
    final exercise = await showDialog<WorkoutExercise>(
      context: context,
      builder: (_) => _ExerciseEditorDialog(
        exercise: WorkoutExercise(
          id: _id('exercise'),
          name: '',
        ),
      ),
    );
    if (exercise != null) setState(() => _exercises.add(exercise));
  }

  Future<void> _editExercise(int index) async {
    final exercise = await showDialog<WorkoutExercise>(
      context: context,
      builder: (_) => _ExerciseEditorDialog(exercise: _exercises[index]),
    );
    if (exercise != null) setState(() => _exercises[index] = exercise);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this workout a name first.')),
      );
      return;
    }

    final notifier = ref.read(workoutStateProvider.notifier);
    if (widget.templateMode) {
      notifier.saveTemplate(
        WorkoutTemplate(
          id: widget.existingTemplate?.id ?? _id('template'),
          name: name,
          exercises: _exercises,
          source: widget.existingTemplate?.source ?? 'Manual',
          externalId: widget.existingTemplate?.externalId,
          mediaBaseUrl: widget.existingTemplate?.mediaBaseUrl,
        ),
      );
    } else {
      notifier.saveScheduled(
        ScheduledWorkout(
          id: widget.existingScheduled?.id ?? _id('scheduled'),
          name: name,
          scheduledFor: _date,
          templateId: _templateId,
          exercises: _exercises,
          notes: _notesController.text.trim(),
        ),
      );
    }
    Navigator.of(context).pop();
  }
}

class _ExerciseEditorDialog extends StatefulWidget {
  final WorkoutExercise exercise;

  const _ExerciseEditorDialog({required this.exercise});

  @override
  State<_ExerciseEditorDialog> createState() => _ExerciseEditorDialogState();
}

class _ExerciseEditorDialogState extends State<_ExerciseEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _name = TextEditingController(text: exercise.name);
    _sets = TextEditingController(text: exercise.sets.toString());
    _reps = TextEditingController(text: exercise.reps.toString());
    _weight = TextEditingController(
      text: exercise.weight == null ? '' : _trimNumber(exercise.weight!),
    );
    _rest = TextEditingController(text: exercise.restSeconds.toString());
    _notes = TextEditingController(text: exercise.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.name.isEmpty ? 'Add exercise' : 'Edit exercise'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.exercise.name.isEmpty,
                decoration: const InputDecoration(labelText: 'Exercise'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sets'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _reps,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reps'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Weight'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _rest,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rest (sec)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      widget.exercise.copyWith(
        name: name,
        sets: _positiveInt(_sets.text, fallback: 1),
        reps: _positiveInt(_reps.text, fallback: 1),
        weight: double.tryParse(_weight.text.trim()),
        clearWeight: _weight.text.trim().isEmpty,
        restSeconds: _nonNegativeInt(_rest.text),
        notes: _notes.text.trim(),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateLabel(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _exerciseSummary(WorkoutExercise exercise) {
  final weight = exercise.weight == null ? '' : ' • ${_trimNumber(exercise.weight!)} lb';
  return '${exercise.sets} sets × ${exercise.reps} reps$weight • ${exercise.restSeconds}s rest';
}

String _trimNumber(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

int _positiveInt(String value, {required int fallback}) {
  final parsed = int.tryParse(value.trim()) ?? fallback;
  return parsed < 1 ? fallback : parsed;
}

int _nonNegativeInt(String value) {
  final parsed = int.tryParse(value.trim()) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';
