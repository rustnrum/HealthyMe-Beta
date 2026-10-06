import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/salus_widgets.dart';

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final prompt = (value ?? _controller.text).trim();
    if (prompt.isEmpty) return;
    _controller.text = prompt;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salus AI chat is staged visually. The conversation engine will be connected after the health-data pipeline is validated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final firstName = app.profile.firstName.trim().isEmpty
        ? 'there'
        : app.profile.firstName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salus AI'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () {},
            icon: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SalusPageBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  children: [
                    const Text(
                      'SALUS AI',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Y O U R   W E L L N E S S   C O A C H',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SalusPaper(
                      glow: true,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -2,
                            top: -8,
                            width: 180,
                            height: 190,
                            child: Opacity(
                              opacity: 0.94,
                              child: Image.asset(
                                SalusAssets.aiOrb,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 118),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MEET YOUR AI COACH',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Hi $firstName,\nI’m Salus AI',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 36,
                                    height: 1.05,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Use your own data to explore meals, workouts, biomarkers, sleep and recovery.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14.5,
                                    height: 1.42,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(height: 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _CapabilityRow(),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TRY ASKING',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                        TextButton(onPressed: () {}, child: const Text('See all')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PromptGrid(onPrompt: _submit),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xF20A1117),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.55)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyan.withValues(alpha: 0.12),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimary),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _submit,
                          decoration: const InputDecoration(
                            hintText: 'Ask Salus AI anything…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _submit(),
                        icon: const Icon(Icons.arrow_upward_rounded, color: AppTheme.cyan),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow();

  static const items = [
    (Icons.restaurant_rounded, 'Food', AppTheme.mint),
    (Icons.fitness_center_rounded, 'Workout', AppTheme.cyan),
    (Icons.bar_chart_rounded, 'Biomarkers', AppTheme.purple),
    (Icons.bedtime_rounded, 'Sleep', AppTheme.blue),
    (Icons.favorite_border_rounded, 'Recovery', AppTheme.rose),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: items[i].$3.withValues(alpha: 0.08),
                    border: Border.all(color: items[i].$3.withValues(alpha: 0.25)),
                  ),
                  child: Icon(items[i].$1, color: items[i].$3, size: 23),
                ),
                const SizedBox(height: 6),
                Text(
                  items[i].$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PromptGrid extends StatelessWidget {
  final ValueChanged<String> onPrompt;

  const _PromptGrid({required this.onPrompt});

  static const prompts = [
    (Icons.restaurant_rounded, 'Log my breakfast', 'Track calories and nutrition', AppTheme.mint),
    (Icons.fitness_center_rounded, 'Plan a workout for today', 'Use my current goals', AppTheme.cyan),
    (Icons.bar_chart_rounded, 'Review my biomarkers', 'Explain my latest results', AppTheme.purple),
    (Icons.bedtime_rounded, 'How did I sleep last night?', 'Use sleep and recovery signals', AppTheme.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prompts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final item = prompts[index];
        return SalusPaper(
          onTap: () => onPrompt(item.$2),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.$4.withValues(alpha: 0.09),
                  border: Border.all(color: item.$4.withValues(alpha: 0.28)),
                ),
                child: Icon(item.$1, color: item.$4, size: 21),
              ),
              const Spacer(),
              Text(item.$2, maxLines: 2, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(item.$3, maxLines: 2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.25)),
            ],
          ),
        );
      },
    );
  }
}
