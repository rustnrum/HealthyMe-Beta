import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/app_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _goalWeight;
  late String _sex;
  late String _goal;
  late String _activity;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final p = ref.read(appStateProvider).profile;
    _name = TextEditingController(text: p.firstName);
    _weight = TextEditingController(
      text: ref.read(appStateProvider).currentWeightLb?.toStringAsFixed(1) ?? '',
    );
    _goalWeight =
        TextEditingController(text: p.goalWeightLb?.toStringAsFixed(1) ?? '');
    _sex = p.sex;
    _goal = p.primaryGoal;
    _activity = p.activityLevel;
    _birthday = p.birthday;
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _goalWeight.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 35),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _save() {
    final app = ref.read(appStateProvider);
    final old = app.profile;
    final newWeight = double.tryParse(_weight.text.trim());

    final next = UserProfile(
      completed: true,
      firstName: _name.text.trim(),
      sex: _sex,
      birthday: _birthday,
      heightIn: old.heightIn,
      startingWeightLb: old.startingWeightLb,
      manualCurrentWeightLb:
          newWeight ?? old.manualCurrentWeightLb,
      goalWeightLb:
          double.tryParse(_goalWeight.text.trim()) ?? old.goalWeightLb,
      primaryGoal: _goal,
      activityLevel: _activity,
      stepGoal: old.stepGoal,
      workoutGoalPerWeek: old.workoutGoalPerWeek,
    );

    ref.read(appStateProvider.notifier).saveProfile(next);

    if (newWeight != null &&
        newWeight != old.manualCurrentWeightLb &&
        app.health.weightLb == null) {
      ref.read(appStateProvider.notifier).logManualWeight(newWeight);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 11),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Male', label: Text('Male')),
              ButtonSegment(value: 'Female', label: Text('Female')),
            ],
            selected: {_sex},
            onSelectionChanged: (values) =>
                setState(() => _sex = values.first),
          ),
          const SizedBox(height: 11),
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: const Text('Birthday'),
            subtitle: Text(
              _birthday == null
                  ? 'Not set'
                  : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickBirthday,
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _weight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Manual weight (lb)'),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _goalWeight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Goal weight (lb)'),
          ),
          const SizedBox(height: 11),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Primary goal'),
            items: const [
              DropdownMenuItem(value: 'Fat loss', child: Text('Fat loss')),
              DropdownMenuItem(
                value: 'Build strength',
                child: Text('Build strength'),
              ),
              DropdownMenuItem(
                value: 'Improve fitness',
                child: Text('Improve fitness'),
              ),
              DropdownMenuItem(
                value: 'Maintain health',
                child: Text('Maintain health'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _goal = value);
            },
          ),
          const SizedBox(height: 11),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Activity level'),
            items: const [
              DropdownMenuItem(
                value: 'Mostly seated',
                child: Text('Mostly seated'),
              ),
              DropdownMenuItem(
                value: 'Lightly active',
                child: Text('Lightly active'),
              ),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(
                value: 'Very active',
                child: Text('Very active'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _activity = value);
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}
