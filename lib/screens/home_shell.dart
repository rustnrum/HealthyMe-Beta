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
import '../widgets/salus_widgets.dart';

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
      if (app.health.authorized && !sync.isLoading) {
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
    final app = ref.read(appStateProvider);
    final sync = ref.read(healthSyncProvider);
    if (app.health.authorized && !sync.isLoading) {
      ref.read(healthSyncProvider.notifier).sync();
    }
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

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navigationProvider);
    const screens = [HomeScreen(), ActivityScreen(), SleepScreen(), BodyScreen(), MoreScreen()];
    const titles = ['Salus', 'Activity', 'Sleep', 'Body', 'More'];

    void selectModule(HealthyMeModule module) {
      switch (module) {
        case HealthyMeModule.fitness:
          ref.read(navigationProvider.notifier).go(0);
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
      appBar: index == 0
          ? _SalusBrandAppBar(
              onModuleSelected: selectModule,
              onProfile: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            )
          : AppBar(
              leading: IconButton(
                tooltip: 'Back to Home',
                onPressed: () => ref.read(navigationProvider.notifier).go(0),
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
              title: Text(titles[index]),
              actions: [HealthyMeModuleMenuButton(current: HealthyMeModule.fitness, onSelected: selectModule)],
            ),
      body: SafeArea(top: false, child: IndexedStack(index: index, children: screens)),
      bottomNavigationBar: _SalusBottomNav(index: index, onChanged: ref.read(navigationProvider.notifier).go),
    );
  }
}

class _SalusBrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueChanged<HealthyMeModule> onModuleSelected;
  final VoidCallback onProfile;
  const _SalusBrandAppBar({required this.onModuleSelected, required this.onProfile});

  @override
  Size get preferredSize => const Size.fromHeight(116);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 116,
      automaticallyImplyLeading: false,
      titleSpacing: 10,
      backgroundColor: AppTheme.backgroundDeep,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: AppTheme.backgroundDeep,
          image: DecorationImage(
            image: AssetImage(SalusAssets.leatherTexture),
            fit: BoxFit.cover,
            opacity: 0.9,
          ),
        ),
      ),
      title: Row(
        children: [
          Opacity(
            opacity: 0.92,
            child: Image.asset(SalusAssets.headerBranch, width: 48, height: 88, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SALUS',
                  style: TextStyle(
                    color: AppTheme.creamText,
                    fontSize: 31,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.7,
                    height: 0.95,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'by RUST N RUM',
                  style: TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'A HEALTHIER TOMORROW\nLIVES IN A MORE AWARE TODAY.',
                  maxLines: 2,
                  style: TextStyle(
                    color: Color(0xFFC8A96E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.55,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        HealthyMeModuleMenuButton(current: HealthyMeModule.fitness, onSelected: onModuleSelected),
        IconButton(
          tooltip: 'Profile',
          onPressed: onProfile,
          icon: const Icon(Icons.account_circle_outlined, size: 25, color: AppTheme.cyan),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _SalusBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _SalusBottomNav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.directions_walk_rounded, 'Activity'),
    (Icons.bedtime_outlined, 'Sleep'),
    (Icons.monitor_weight_outlined, 'Body'),
    (Icons.more_horiz_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDeep,
        image: DecorationImage(image: AssetImage(SalusAssets.leatherTexture), fit: BoxFit.cover, opacity: 0.82),
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 6 + MediaQuery.paddingOf(context).bottom * 0.45),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _items[i].$1,
                        color: i == index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72),
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[i].$2,
                        style: TextStyle(
                          color: i == index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: i == index ? 22 : 4,
                        height: 2,
                        decoration: BoxDecoration(
                          color: i == index ? AppTheme.cyan : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
