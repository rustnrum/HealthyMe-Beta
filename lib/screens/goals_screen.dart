import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sleep_guidance_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  late final TextEditingController _weight;
  late final TextEditingController _steps;
  late final TextEditingController _workouts;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appStateProvider).profile;
    _weight = TextEditingController(
      text: profile.goalWeightLb?.toStringAsFixed(0) ?? '',
    );
    _steps = TextEditingController(text: profile.stepGoal.toString());
    _workouts =
        TextEditingController(text: profile.workoutGoalPerWeek.toString());
  }

  @override
  void dispose() {
    _weight.dispose();
    _steps.dispose();
    _workouts.dispose();
    super.dispose();
  }

  void _save() {
    final current = ref.read(appStateProvider).profile;
    final next = current.copyWith(
      goalWeightLb:
          double.tryParse(_weight.text.trim()) ?? current.goalWeightLb,
      stepGoal: int.tryParse(_steps.text.trim()) ?? current.stepGoal,
      workoutGoalPerWeek:
          int.tryParse(_workouts.text.trim()) ?? current.workoutGoalPerWeek,
    );
    ref.read(appStateProvider.notifier).saveProfile(next);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final sleep = SleepGuidanceService.forAge(app.profile.age);
    final current = app.currentWeightLb;
    final goal = app.profile.goalWeightLb;
    final weightProgress = current != null &&
            goal != null &&
            app.profile.startingWeightLb != null &&
            (app.profile.startingWeightLb! - goal).abs() > 0.1
        ? ((app.profile.startingWeightLb! - current) /
                (app.profile.startingWeightLb! - goal))
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Goals & Progress',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _goalCard(
            context,
            icon: Icons.monitor_weight_outlined,
            title: 'Weight Goal',
            progress: weightProgress,
            child: TextField(
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Goal weight (lb)'),
            ),
          ),
          const SizedBox(height: 10),
          _goalCard(
            context,
            icon: Icons.directions_walk,
            title: 'Steps Goal',
            progress: app.profile.stepGoal <= 0
                ? 0
                : (app.health.stepsToday / app.profile.stepGoal)
                    .clamp(0.0, 1.0)
                    .toDouble(),
            child: TextField(
              controller: _steps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Steps per day'),
            ),
          ),
          const SizedBox(height: 10),
          _goalCard(
            context,
            icon: Icons.bedtime_outlined,
            title: 'Sleep Target',
            progress: sleep.minimumMinutes <= 0
                ? 0
                : (app.health.sleepMinutes / sleep.minimumMinutes)
                    .clamp(0.0, 1.0)
                    .toDouble(),
            child: Text(
              '${sleep.label} • recommended from age/profile',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          _goalCard(
            context,
            icon: Icons.fitness_center,
            title: 'Workout Goal',
            progress: 0,
            child: TextField(
              controller: _workouts,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Workouts per week'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save goals'),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double progress,
    required Widget child,
  }) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text('${(progress * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
