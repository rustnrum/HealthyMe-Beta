import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/daily_state.dart';
import '../services/daily_state_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class DailyStateScreen extends ConsumerStatefulWidget {
  const DailyStateScreen({super.key});

  @override
  ConsumerState<DailyStateScreen> createState() => _DailyStateScreenState();
}

class _DailyStateScreenState extends ConsumerState<DailyStateScreen> {
  final Map<String, int?> _ratings = {
    'physical': null,
    'mental': null,
    'emotional': null,
    'recovery': null,
    'muscular': null,
    'activation': null,
    'negative': null,
    'stress': null,
  };

  bool get _complete => _ratings.values.every((value) => value != null);

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final today = DailyStateService.today(app);
    final completed = today?.isCompleted == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily State')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const Text(
            'Morning check-in',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'A fast snapshot of how you feel right now. Recovery items: higher is better. Stress items: higher means more stress/load.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsCard(app: app),
          const SizedBox(height: 20),
          if (completed)
            _TodayResult(entry: today!, app: app)
          else ...[
            const HmSectionHeader(title: 'How are you feeling right now?'),
            const SizedBox(height: 10),
            _QuestionCard(
              title: 'Physical capability',
              prompt: 'How physically capable do you feel today?',
              value: _ratings['physical'],
              onChanged: (value) => _set('physical', value),
            ),
            _QuestionCard(
              title: 'Mental capability',
              prompt: 'How well does your head feel like it is functioning today?',
              value: _ratings['mental'],
              onChanged: (value) => _set('mental', value),
            ),
            _QuestionCard(
              title: 'Emotional balance',
              prompt: 'How emotionally balanced do you feel right now?',
              value: _ratings['emotional'],
              onChanged: (value) => _set('emotional', value),
            ),
            _QuestionCard(
              title: 'Overall recovery',
              prompt: 'How recovered do you feel overall?',
              value: _ratings['recovery'],
              onChanged: (value) => _set('recovery', value),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stress/load',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            _QuestionCard(
              title: 'Body stress',
              prompt: 'How much muscular soreness or physical strain do you feel?',
              value: _ratings['muscular'],
              onChanged: (value) => _set('muscular', value),
            ),
            _QuestionCard(
              title: 'Low activation',
              prompt: 'How sluggish, unmotivated or lacking in energy do you feel?',
              value: _ratings['activation'],
              onChanged: (value) => _set('activation', value),
            ),
            _QuestionCard(
              title: 'Negative emotional state',
              prompt: 'How irritable, down or negative do you feel right now?',
              value: _ratings['negative'],
              onChanged: (value) => _set('negative', value),
            ),
            _QuestionCard(
              title: 'Overall stress',
              prompt: 'How overloaded or stressed do you feel overall?',
              value: _ratings['stress'],
              onChanged: (value) => _set('stress', value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _complete ? _save : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save today’s check-in'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                ref.read(appStateProvider.notifier).markDailyStateToday('skipped');
                Navigator.of(context).pop();
              },
              child: const Text('Skip today'),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Daily State is a wellness check-in, not a diagnosis. This beta uses recovery/stress research constructs and a 0–6 response format while commercial instrument wording/licensing is still being resolved. Salus’s combined recovery estimate is its own transparent app calculation, not an official SRSS score.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _set(String key, int value) => setState(() => _ratings[key] = value);

  void _save() {
    final now = DateTime.now();
    final entry = DailyStateEntry(
      date: now,
      physicalCapability: _ratings['physical'],
      mentalCapability: _ratings['mental'],
      emotionalBalance: _ratings['emotional'],
      overallRecovery: _ratings['recovery'],
      muscularStress: _ratings['muscular'],
      lackActivation: _ratings['activation'],
      negativeEmotionalState: _ratings['negative'],
      overallStress: _ratings['stress'],
    );
    final action = DailyStateService.suggestedReset(entry);
    ref.read(appStateProvider.notifier).saveDailyState(
          entry.copyWith(resetAction: action),
        );
  }
}

class _SettingsCard extends ConsumerWidget {
  final HealthyMeState app;

  const _SettingsCard({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour24 = app.dailyStateStartMinutes ~/ 60;
    final minute = app.dailyStateStartMinutes % 60;
    final time = TimeOfDay(hour: hour24, minute: minute);

    return CommandCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Morning check-in',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              'Optional. The prompt is controlled by the selected time, not by app launch.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
              ),
            ),
            value: app.dailyStateEnabled,
            onChanged: (value) => ref
                .read(appStateProvider.notifier)
                .setDailyStateSettings(enabled: value),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded, color: AppTheme.cyan),
            title: const Text(
              'Start time',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Appears once per day after this time.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
            trailing: Text(
              time.format(context),
              style: const TextStyle(
                color: AppTheme.cyan,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            onTap: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (selected == null) return;
              ref.read(appStateProvider.notifier).setDailyStateSettings(
                    startMinutes: selected.hour * 60 + selected.minute,
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String title;
  final String prompt;
  final int? value;
  final ValueChanged<int> onChanged;

  const _QuestionCard({
    required this.title,
    required this.prompt,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CommandCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              prompt,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var score = 0; score <= 6; score++)
                  ChoiceChip(
                    label: Text('$score'),
                    selected: value == score,
                    onSelected: (_) => onChanged(score),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0 = does not apply',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                Text(
                  '6 = fully applies',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayResult extends ConsumerWidget {
  final DailyStateEntry entry;
  final HealthyMeState app;

  const _TodayResult({required this.entry, required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = entry.recoveryAverage ?? 0;
    final stress = entry.stressAverage ?? 0;
    final estimate = DailyStateService.recoveryEstimate(entry);
    final action = entry.resetAction ?? DailyStateService.suggestedReset(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HmSectionHeader(title: 'Today’s state'),
        const SizedBox(height: 10),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Recovery',
                      value: recovery.toStringAsFixed(1),
                      suffix: '/6',
                      color: AppTheme.mint,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Stress',
                      value: stress.toStringAsFixed(1),
                      suffix: '/6',
                      color: AppTheme.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                DailyStateService.baselineComparison(app, entry),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (estimate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Salus subjective recovery input: $estimate/100',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const HmSectionHeader(title: 'Try this'),
        const SizedBox(height: 10),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Did it help?',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final label in ['Worse', 'Same', 'A little', 'A lot'])
                    ChoiceChip(
                      label: Text(label),
                      selected: entry.resetFeedback == label,
                      onSelected: (_) => ref
                          .read(appStateProvider.notifier)
                          .setDailyStateFeedback(entry.dayKey, label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
