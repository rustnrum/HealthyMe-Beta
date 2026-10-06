import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../state/navigation_provider.dart';
import '../widgets/module_menu_button.dart';
import 'activity_screen.dart';
import 'body_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'profile_screen.dart';
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
    const screens = [
      HomeScreen(),
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
      appBar: index == 0
          ? _SalusBrandAppBar(
              onModuleSelected: selectModule,
              onCoach: () => Navigator.of(context).pushNamed('/coach'),
              onProfile: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            )
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
      body: SafeArea(top: false, bottom: false, child: IndexedStack(index: index, children: screens)),
      bottomNavigationBar: _SalusBottomNav(
        index: index,
        onChanged: ref.read(navigationProvider.notifier).go,
      ),
    );
  }
}

class _SalusBrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueChanged<HealthyMeModule> onModuleSelected;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  const _SalusBrandAppBar({
    required this.onModuleSelected,
    required this.onCoach,
    required this.onProfile,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 76,
      automaticallyImplyLeading: false,
      titleSpacing: 18,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandSpark(),
          SizedBox(width: 10),
          Text(
            'S a l u s',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: 3.0,
            ),
          ),
        ],
      ),
      actions: [
        _RoundAction(
          tooltip: 'Salus modules',
          child: HealthyMeModuleMenuButton(
            current: HealthyMeModule.fitness,
            onSelected: onModuleSelected,
          ),
        ),
        const SizedBox(width: 6),
        _RoundAction(
          tooltip: 'Salus AI',
          onTap: onCoach,
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(width: 6),
        _RoundAction(
          tooltip: 'Profile',
          onTap: onProfile,
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}

class _BrandSpark extends StatelessWidget {
  const _BrandSpark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [AppTheme.cyan.withValues(alpha: 0.30), Colors.transparent],
        ),
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.cyan, size: 18),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? child;

  const _RoundAction({
    required this.tooltip,
    this.onTap,
    this.icon,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return Tooltip(
        message: tooltip,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface.withValues(alpha: 0.72),
            border: Border.all(color: AppTheme.border),
          ),
          child: child,
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface.withValues(alpha: 0.72),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 21),
        ),
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
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.cyan),
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
