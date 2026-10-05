import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../state/navigation_provider.dart';
import 'activity_screen.dart';
import 'body_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'profile_screen.dart';
import 'sleep_screen.dart';
import '../widgets/module_menu_button.dart';

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
      final app = ref.read(appStateProvider);
      final sync = ref.read(healthSyncProvider);
      if (app.health.authorized && !sync.isLoading) ref.read(healthSyncProvider.notifier).sync();
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
    final app = ref.read(appStateProvider);
    final sync = ref.read(healthSyncProvider);
    if (app.health.authorized && !sync.isLoading) ref.read(healthSyncProvider.notifier).sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = ref.read(appStateProvider);
      if (app.health.authorized) ref.read(healthSyncProvider.notifier).sync();
    });
  }

  Future<void> _syncOrConnect() async {
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      final success = await ref.read(healthSyncProvider.notifier).connectAndSync();
      if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health Connect was not connected. Open More for source details.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navigationProvider);
    final sync = ref.watch(healthSyncProvider);
    final app = ref.watch(appStateProvider);
    const screens = [HomeScreen(), ActivityScreen(), SleepScreen(), BodyScreen(), MoreScreen()];
    const titles = ['Salus', 'Activity', 'Sleep', 'Body', 'More'];

    return Scaffold(
      appBar: AppBar(
        leading: index == 0 ? null : IconButton(tooltip: 'Back to Home', onPressed: () => ref.read(navigationProvider.notifier).go(0), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
        title: index == 0
            ? const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('SALUS', style: TextStyle(color: AppTheme.creamText, fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: 2.4)),
                Text('by RUST N RUM', style: TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2.0)),
              ])
            : Text(titles[index]),
        actions: [
          HealthyMeModuleMenuButton(current: HealthyMeModule.fitness, onSelected: (module) {
            switch (module) {
              case HealthyMeModule.fitness: ref.read(navigationProvider.notifier).go(0); break;
              case HealthyMeModule.diet: Navigator.of(context).pushNamed('/diet'); break;
              case HealthyMeModule.health: Navigator.of(context).pushNamed('/health'); break;
            }
          }),
          if (sync.isLoading)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2.1, color: AppTheme.cyan)))
          else if (index == 0)
            IconButton(tooltip: app.health.authorized ? 'Refresh health data' : 'Connect Health Connect', onPressed: _syncOrConnect, icon: Icon(app.health.authorized ? Icons.sync_rounded : Icons.add_link_rounded, size: 22)),
          if (index == 0)
            IconButton(tooltip: 'Profile', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())), icon: const Icon(Icons.account_circle_outlined, size: 23)),
        ],
      ),
      body: SafeArea(top: false, child: IndexedStack(index: index, children: screens)),
      bottomNavigationBar: _SalusBottomNav(index: index, onChanged: ref.read(navigationProvider.notifier).go),
    );
  }
}

class _SalusBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _SalusBottomNav({required this.index, required this.onChanged});
  static const _items = [(Icons.home_outlined, 'Home'), (Icons.directions_walk_rounded, 'Activity'), (Icons.bedtime_outlined, 'Sleep'), (Icons.monitor_weight_outlined, 'Body'), (Icons.more_horiz_rounded, 'More')];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: AppTheme.backgroundDeep, border: Border(top: BorderSide(color: AppTheme.border, width: 0.8))),
    padding: EdgeInsets.only(top: 8, bottom: 6 + MediaQuery.paddingOf(context).bottom * 0.45),
    child: Row(children: [for (var i = 0; i < _items.length; i++) Expanded(child: InkWell(onTap: () => onChanged(i), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_items[i].$1, color: i == index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72), size: 22),
      const SizedBox(height: 4),
      Text(_items[i].$2, style: TextStyle(color: i == index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72), fontSize: 12, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500)),
      const SizedBox(height: 4),
      AnimatedContainer(duration: const Duration(milliseconds: 160), width: i == index ? 22 : 4, height: 2, decoration: BoxDecoration(color: i == index ? AppTheme.cyan : Colors.transparent, borderRadius: BorderRadius.circular(99))),
    ]))))]),
  );
}
