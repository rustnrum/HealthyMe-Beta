import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../state/navigation_provider.dart';
import '../widgets/module_menu_button.dart';
import '../widgets/salus_voice_launcher.dart';
import 'activity_screen.dart';
import 'body_screen.dart';
import 'premium/salus_home_85.dart';
import 'more_screen.dart';
import 'sleep_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  bool _autoSyncStarted = false;
  Timer? _foregroundSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foregroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      final sync = ref.read(healthSyncProvider);
      if (!sync.isLoading) {
        ref.read(healthSyncProvider.notifier).sync();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final sync = ref.read(healthSyncProvider);
    if (!sync.isLoading) {
      ref.read(healthSyncProvider.notifier).sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = ref.read(appStateProvider);
      if (app.health.authorized) ref.read(healthSyncProvider.notifier).sync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navigationProvider);
    // Build 85 is deliberately Home-only. All other pages keep their working
    // implementations and storage; no wearable/data migration occurs here.
    const screens = [
      SalusHome85(),
      ActivityScreen(),
      SleepScreen(),
      BodyScreen(),
      MoreScreen(),
    ];
    const titles = ['Salus', 'Activity', 'Sleep', 'Body', 'More'];

    void selectModule(HealthyMeModule module) {
      switch (module) {
        case HealthyMeModule.fitness:
          ref.read(navigationProvider.notifier).go(0);
          break;
        case HealthyMeModule.workout:
          Navigator.of(context).pushNamed('/workout');
          break;
        case HealthyMeModule.diet:
          Navigator.of(context).pushNamed('/diet');
          break;
        case HealthyMeModule.health:
          Navigator.of(context).pushNamed('/health');
          break;
      }
    }

    return Scaffold(
      // The existing floating Voice button would cover the mockup CTA.
      // Keep it unchanged in other modules; Home has its own future UX.
      floatingActionButton: index == 0
          ? null
          : SalusVoiceLauncher(
              onPressed: () => Navigator.of(context).pushNamed('/voice')),
      appBar: index == 0
          ? null // Home owns the SALUS hero/header.
          : AppBar(
              leading: IconButton(
                tooltip: 'Back to Home',
                onPressed: () => ref.read(navigationProvider.notifier).go(0),
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
              title: Text(titles[index]),
              actions: [
                HealthyMeModuleMenuButton(
                  current: HealthyMeModule.fitness,
                  onSelected: selectModule,
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        top: index == 0,
        bottom: false,
        child: IndexedStack(index: index, children: screens),
      ),
      bottomNavigationBar: index == 0
          ? SalusHome85Nav(
              onTraining: () => Navigator.of(context).pushNamed('/workout'),
              onHealth: () => Navigator.of(context).pushNamed('/health'),
              onDiscover: () => ref.read(navigationProvider.notifier).go(4),
            )
          : _SalusBottomNav(
              index: index,
              onChanged: ref.read(navigationProvider.notifier).go,
            ),
    );
  }
}

class _SalusBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _SalusBottomNav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.insights_rounded, 'Activity'),
    (Icons.bedtime_rounded, 'Sleep'),
    (Icons.monitor_weight_rounded, 'Body'),
    (Icons.more_horiz_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
        decoration: BoxDecoration(
          color: const Color(0xF20A1117),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _items[i].$1,
                          color: i == index ? AppTheme.textPrimary : AppTheme.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            color: i == index ? AppTheme.textPrimary : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: i == index ? 7 : 0,
                          height: i == index ? 7 : 0,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppTheme.cyan),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
