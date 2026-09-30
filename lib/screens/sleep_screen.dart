import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/sleep_guidance_service.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final guidance = SleepGuidanceService.forAge(app.profile.age);
    final recent = h.sleepMinutes7.where((value) => value > 0).toList();
    final avg = recent.isEmpty
        ? 0
        : (recent.reduce((a, b) => a + b) / recent.length).round();

    final score = guidance.minimumMinutes <= 0 || h.sleepMinutes <= 0
        ? null
        : min(
            100,
            ((h.sleepMinutes / guidance.minimumMinutes) * 100).round(),
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'Sleep',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        CommandCard(
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: Color(0x229B65F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bedtime_rounded,
                  size: 34,
                  color: AppTheme.purple,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      minutesLabel(h.sleepMinutes),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text('Total sleep'),
                    const SizedBox(height: 5),
                    Text(
                      'Target: ${guidance.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (score != null)
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 7,
                        color: score >= 90
                            ? AppTheme.mint
                            : score >= 75
                                ? AppTheme.amber
                                : AppTheme.rose,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.07),
                      ),
                      Center(
                        child: Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sleep stages',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              SleepStageBar(
                awake: h.sleepAwakeMinutes,
                rem: h.sleepRemMinutes,
                light: h.sleepLightMinutes,
                deep: h.sleepDeepMinutes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CommandCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x22FFB84D),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep insight',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(_insight(h.sleepMinutes, avg, guidance.minimumMinutes)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CommandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sleep consistency • 7 days',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              SimpleBarChart(
                values: h.sleepMinutes7,
                target: guidance.minimumMinutes > 0
                    ? guidance.minimumMinutes.toDouble()
                    : null,
                showTarget: guidance.minimumMinutes > 0,
                height: 165,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _insight(int tonight, int average, int target) {
    if (tonight <= 0) {
      return 'No sleep data is available yet. Connect a sleep source through Health Connect.';
    }
    if (average > 0) {
      final delta = tonight - average;
      if (delta <= -45) {
        return 'You slept ${(-delta)} minutes less than your recent average. Recovery may benefit from a lighter day.';
      }
      if (delta >= 45) {
        return 'You slept $delta minutes more than your recent average.';
      }
    }
    if (target > 0 && tonight < target) {
      return 'Sleep was below your age-based target. Prioritize a consistent sleep window tonight.';
    }
    return 'Sleep duration is close to your recent pattern and age-based target.';
  }
}
