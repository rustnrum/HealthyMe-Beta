import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/health_data_provider.dart';
import '../providers/profile_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalWeightController = TextEditingController();

  var _page = 0;
  var _sex = 'Male';
  DateTime? _birthday;
  var _goal = 'Fat loss';
  var _activity = 'Mostly seated';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _finish() {
    final feet = double.tryParse(_heightFeetController.text.trim());
    final inches = double.tryParse(_heightInchesController.text.trim()) ?? 0;
    final weight = double.tryParse(_weightController.text.trim());
    final goalWeight = double.tryParse(_goalWeightController.text.trim());

    if (_nameController.text.trim().isEmpty ||
        _birthday == null ||
        feet == null ||
        weight == null ||
        goalWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the required profile fields first.')),
      );
      return;
    }

    final profile = UserProfile(
      completed: true,
      firstName: _nameController.text.trim(),
      sex: _sex,
      birthday: _birthday,
      heightIn: feet * 12 + inches,
      startingWeightLb: weight,
      currentWeightLb: weight,
      goalWeightLb: goalWeight,
      primaryGoal: _goal,
      activityLevel: _activity,
    );

    ref.read(profileProvider.notifier).complete(profile);
    ref.read(healthDataProvider.notifier).seedWeight(weight);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 35),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _birthday = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Healthy Me',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text('${_page + 1} / 3'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: LinearProgressIndicator(
                value: (_page + 1) / 3,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _AboutPage(
                    nameController: _nameController,
                    sex: _sex,
                    birthday: _birthday,
                    onSexChanged: (value) => setState(() => _sex = value),
                    onBirthday: _pickBirthday,
                  ),
                  _StartingPointPage(
                    feetController: _heightFeetController,
                    inchesController: _heightInchesController,
                    weightController: _weightController,
                    goalWeightController: _goalWeightController,
                  ),
                  _GoalsPage(
                    goal: _goal,
                    activity: _activity,
                    onGoalChanged: (value) => setState(() => _goal = value),
                    onActivityChanged: (value) =>
                        setState(() => _activity = value),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton.icon(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      _page == 2 ? Icons.check_rounded : Icons.arrow_forward,
                    ),
                    label: Text(_page == 2 ? 'Build my dashboard' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  final TextEditingController nameController;
  final String sex;
  final DateTime? birthday;
  final ValueChanged<String> onSexChanged;
  final VoidCallback onBirthday;

  const _AboutPage({
    required this.nameController,
    required this.sex,
    required this.birthday,
    required this.onSexChanged,
    required this.onBirthday,
  });

  String _date(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 20),
      children: [
        Text(
          'Start with you',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Healthy Me uses your profile to set sensible goals instead of asking you to guess them.',
        ),
        const SizedBox(height: 28),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'First name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 18),
        Text('Sex', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Male', label: Text('Male')),
            ButtonSegment(value: 'Female', label: Text('Female')),
          ],
          selected: {sex},
          onSelectionChanged: (values) => onSexChanged(values.first),
        ),
        const SizedBox(height: 18),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.cake_outlined),
          title: const Text('Birthday'),
          subtitle: Text(
            birthday == null ? 'Used for age-based guidance' : _date(birthday!),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onBirthday,
        ),
      ],
    );
  }
}

class _StartingPointPage extends StatelessWidget {
  final TextEditingController feetController;
  final TextEditingController inchesController;
  final TextEditingController weightController;
  final TextEditingController goalWeightController;

  const _StartingPointPage({
    required this.feetController,
    required this.inchesController,
    required this.weightController,
    required this.goalWeightController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 20),
      children: [
        Text(
          'Your starting point',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can update weight and measurements anytime. Body fat is not a manual field.',
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: feetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (ft)',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: inchesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Inches',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Current weight (lb)',
            prefixIcon: Icon(Icons.monitor_weight_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: goalWeightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Goal weight (lb)',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
      ],
    );
  }
}

class _GoalsPage extends StatelessWidget {
  final String goal;
  final String activity;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<String> onActivityChanged;

  const _GoalsPage({
    required this.goal,
    required this.activity,
    required this.onGoalChanged,
    required this.onActivityChanged,
  });

  static const goals = [
    'Fat loss',
    'Build strength',
    'Improve fitness',
    'Maintain health',
  ];

  static const activityLevels = [
    'Mostly seated',
    'Lightly active',
    'Active',
    'Very active',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 20),
      children: [
        Text(
          'What are we working toward?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'These choices shape the suggestions you see. They are not a medical treatment plan.',
        ),
        const SizedBox(height: 28),
        DropdownButtonFormField<String>(
          initialValue: goal,
          decoration: const InputDecoration(
            labelText: 'Primary goal',
            prefixIcon: Icon(Icons.track_changes),
          ),
          items: goals
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) onGoalChanged(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: activity,
          decoration: const InputDecoration(
            labelText: 'Typical activity',
            prefixIcon: Icon(Icons.directions_walk),
          ),
          items: activityLevels
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) onActivityChanged(value);
          },
        ),
      ],
    );
  }
}
