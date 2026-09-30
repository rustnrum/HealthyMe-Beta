import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/app_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _name = TextEditingController();
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _weight = TextEditingController();
  final _goalWeight = TextEditingController();

  int _page = 0;
  String _sex = 'Male';
  DateTime? _birthday;
  String _goal = 'Fat loss';
  String _activity = 'Mostly seated';

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _feet.dispose();
    _inches.dispose();
    _weight.dispose();
    _goalWeight.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 35),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (value != null) setState(() => _birthday = value);
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    final feet = double.tryParse(_feet.text.trim());
    final inches = double.tryParse(_inches.text.trim()) ?? 0;
    final weight = double.tryParse(_weight.text.trim());
    final goal = double.tryParse(_goalWeight.text.trim());

    if (_name.text.trim().isEmpty ||
        _birthday == null ||
        feet == null ||
        weight == null ||
        goal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the required profile fields first.')),
      );
      return;
    }

    final profile = UserProfile(
      completed: true,
      firstName: _name.text.trim(),
      sex: _sex,
      birthday: _birthday,
      heightIn: feet * 12 + inches,
      startingWeightLb: weight,
      manualCurrentWeightLb: weight,
      goalWeightLb: goal,
      primaryGoal: _goal,
      activityLevel: _activity,
    );

    ref.read(appStateProvider.notifier).saveProfile(profile);
    ref.read(appStateProvider.notifier).logManualWeight(weight);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17C8F4), Color(0xFF35E39A)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Healthy Me',
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text('${_page + 1} / 3'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(
                value: (_page + 1) / 3,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _pageWrap(
                    context,
                    title: 'Start with you',
                    subtitle:
                        'Healthy Me uses this profile to interpret data instead of making you guess at basic targets.',
                    children: [
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Male', label: Text('Male')),
                          ButtonSegment(value: 'Female', label: Text('Female')),
                        ],
                        selected: {_sex},
                        onSelectionChanged: (values) =>
                            setState(() => _sex = values.first),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cake_outlined),
                        title: const Text('Birthday'),
                        subtitle: Text(
                          _birthday == null
                              ? 'Used for age-based guidance'
                              : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickBirthday,
                      ),
                    ],
                  ),
                  _pageWrap(
                    context,
                    title: 'Starting point',
                    subtitle:
                        'Body fat is not a manual field. It will come from a compatible connected source when available.',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _feet,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Height (ft)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _inches,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Inches'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _weight,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Current weight (lb)',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _goalWeight,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Goal weight (lb)',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                      ),
                    ],
                  ),
                  _pageWrap(
                    context,
                    title: 'What are we working toward?',
                    subtitle:
                        'These choices tune the wellness guidance. They do not create a medical treatment plan.',
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _goal,
                        decoration:
                            const InputDecoration(labelText: 'Primary goal'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Fat loss',
                            child: Text('Fat loss'),
                          ),
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
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _activity,
                        decoration:
                            const InputDecoration(labelText: 'Typical activity'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Mostly seated',
                            child: Text('Mostly seated'),
                          ),
                          DropdownMenuItem(
                            value: 'Lightly active',
                            child: Text('Lightly active'),
                          ),
                          DropdownMenuItem(
                            value: 'Active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'Very active',
                            child: Text('Very active'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _activity = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton.icon(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      _page == 2 ? Icons.check_rounded : Icons.arrow_forward,
                    ),
                    label: Text(
                      _page == 2 ? 'Build my command center' : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageWrap(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 20),
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(subtitle),
        const SizedBox(height: 28),
        ...children,
      ],
    );
  }
}
