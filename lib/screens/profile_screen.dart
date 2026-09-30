import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/health_data_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _goalWeight;
  late String _goal;
  late String _activity;
  late String _sex;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _name = TextEditingController(text: profile.firstName);
    _weight = TextEditingController(
      text: profile.currentWeightLb?.toStringAsFixed(1) ?? '',
    );
    _goalWeight = TextEditingController(
      text: profile.goalWeightLb?.toStringAsFixed(1) ?? '',
    );
    _goal = profile.primaryGoal;
    _activity = profile.activityLevel;
    _sex = profile.sex;
    _birthday = profile.birthday;
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
    final current = ref.read(profileProvider);
    final newWeight = double.tryParse(_weight.text.trim());
    final goalWeight = double.tryParse(_goalWeight.text.trim());

    final next = UserProfile(
      completed: true,
      firstName: _name.text.trim(),
      sex: _sex,
      birthday: _birthday,
      heightIn: current.heightIn,
      startingWeightLb: current.startingWeightLb,
      currentWeightLb: newWeight ?? current.currentWeightLb,
      goalWeightLb: goalWeight ?? current.goalWeightLb,
      primaryGoal: _goal,
      activityLevel: _activity,
    );

    ref.read(profileProvider.notifier).update(next);
    if (newWeight != null && newWeight != current.currentWeightLb) {
      ref.read(healthDataProvider.notifier).addWeight(newWeight);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const goals = [
      'Fat loss',
      'Build strength',
      'Improve fitness',
      'Maintain health',
    ];
    const activityLevels = [
      'Mostly seated',
      'Lightly active',
      'Active',
      'Very active',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'First name'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Male', label: Text('Male')),
              ButtonSegment(value: 'Female', label: Text('Female')),
            ],
            selected: {_sex},
            onSelectionChanged: (values) =>
                setState(() => _sex = values.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: const Text('Birthday'),
            subtitle: Text(
              _birthday == null
                  ? 'Not set'
                  : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}',
            ),
            onTap: _pickBirthday,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Current weight (lb)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goalWeight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Goal weight (lb)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Primary goal'),
            items: goals
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _goal = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Typical activity'),
            items: activityLevels
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _activity = value);
            },
          ),
          const SizedBox(height: 22),
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
