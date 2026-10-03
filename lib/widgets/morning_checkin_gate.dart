import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/daily_state_service.dart';
import '../state/app_state.dart';

class MorningCheckInGate extends ConsumerStatefulWidget {
  final Widget child;

  const MorningCheckInGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MorningCheckInGate> createState() => _MorningCheckInGateState();
}

class _MorningCheckInGateState extends ConsumerState<MorningCheckInGate> {
  Timer? _timer;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    if (DailyStateService.isDue(app) && !_presenting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
    }
    return widget.child;
  }

  Future<void> _showPrompt() async {
    if (!mounted || _presenting) return;
    final app = ref.read(appStateProvider);
    if (!DailyStateService.isDue(app)) return;

    _presenting = true;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.self_improvement_rounded,
                      color: AppTheme.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Morning check-in',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'A quick snapshot of how you feel right now.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'This adds your physical, mental and stress state to today’s recovery picture instead of relying only on wearable data.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop('open'),
                  child: const Text('Check in now'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop('skip'),
                      child: const Text('Not today'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop('dismiss'),
                      child: const Text('Dismiss'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (result == 'open') {
      await Navigator.of(context).pushNamed('/daily-state');
      if (!mounted) return;
      final refreshed = ref.read(appStateProvider);
      if (DailyStateService.isDue(refreshed)) {
        ref.read(appStateProvider.notifier).markDailyStateToday('dismissed');
      }
    } else if (result == 'skip') {
      ref.read(appStateProvider.notifier).markDailyStateToday('skipped');
    } else {
      ref.read(appStateProvider.notifier).markDailyStateToday('dismissed');
    }
    _presenting = false;
  }
}
