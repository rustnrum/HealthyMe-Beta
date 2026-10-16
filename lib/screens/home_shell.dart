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
import 'premium/salus_home_87.dart';
import 'more_screen.dart';
import 'sleep_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
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
    if (!sync.isLoading) ref.read(healthSyncProvider.notifier).sync();
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
    // Preserve all existing Activity, Sleep, Body and More screens. The
    // approved four-item navigation links Training/Health to existing modules.
    const screens = [
      SalusHome87(), ActivityScreen(), SleepScreen(), BodyScreen(), MoreScreen(),
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

    void selectHomeTab(int tab) {
      switch (tab) {
        case 0:
          ref.read(navigationProvider.notifier).go(0);
          break;
        case 1:
          Navigator.of(context).pushNamed('/workout');
          break;
        case 2:
          Navigator.of(context).pushNamed('/health');
          break;
        case 3:
          ref.read(navigationProvider.notifier).go(4);
          break;
      }
    }

    return Scaffold(
      floatingActionButton: index == 0
          ? null
          : SalusVoiceLauncher(
              onPressed: () => Navigator.of(context).pushNamed('/voice')),
      appBar: index == 0
          ? null
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
      bottomNavigationBar: _SalusBottomNav(
        index: index == 4 ? 3 : 0,
        onChanged: selectHomeTab,
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
    (Icons.fitness_center_rounded, 'Training'),
    (Icons.favorite_border_rounded, 'Health'),
    (Icons.explore_outlined, 'Discover'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 6),
        decoration: BoxDecoration(
          color: const Color(0xF20A1117),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.border.withValues(alpha: .9)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: .38),
            blurRadius: 28, offset: const Offset(0, 14),
          )],
        ),
        child: Row(children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_items[i].$1,
                    color: i == index ? AppTheme.cyan : AppTheme.textMuted,
                    size: 25),
                  const SizedBox(height: 4),
                  Text(_items[i].$2, maxLines: 1,
                    overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == index ? AppTheme.textPrimary : AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                    )),
                ]),
              ),
            )),
        ]),
      ),
    );
  }
}
