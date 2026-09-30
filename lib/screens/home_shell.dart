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

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _autoSyncStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = ref.read(appStateProvider);
      if (app.health.authorized) {
        ref.read(healthSyncProvider.notifier).sync();
      }
    });
  }

  Future<void> _syncOrConnect() async {
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      final success =
          await ref.read(healthSyncProvider.notifier).connectAndSync();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Health Connect was not connected. Open More for source details.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navigationProvider);
    final sync = ref.watch(healthSyncProvider);
    final app = ref.watch(appStateProvider);

    const screens = [
      HomeScreen(),
      ActivityScreen(),
      SleepScreen(),
      BodyScreen(),
      MoreScreen(),
    ];

    const titles = [
      'Healthy Me',
      'Activity',
      'Sleep',
      'Body',
      'Sources & Plan',
    ];

    return Scaffold(
      appBar: AppBar(
        leading: index == 0
            ? null
            : IconButton(
                tooltip: 'Back to Home',
                onPressed: () => ref.read(navigationProvider.notifier).go(0),
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
        title: Text(titles[index]),
        centerTitle: index != 0,
        actions: [
          if (index == 0)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(
                Icons.wb_sunny_rounded,
                color: AppTheme.amber,
                size: 23,
              ),
            ),
          if (sync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else if (index == 0)
            IconButton(
              tooltip: app.health.authorized
                  ? 'Sync Health Connect'
                  : 'Connect Health Connect',
              onPressed: _syncOrConnect,
              icon: Icon(
                app.health.authorized
                    ? Icons.sync_rounded
                    : Icons.add_link_rounded,
                size: 23,
              ),
            ),
          if (index == 0)
            IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              icon: const Icon(Icons.settings_rounded, size: 21),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: index,
          children: screens,
        ),
      ),
      bottomNavigationBar: _HealthyMeBottomNav(
        index: index,
        onChanged: ref.read(navigationProvider.notifier).go,
      ),
    );
  }
}

class _HealthyMeBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _HealthyMeBottomNav({
    required this.index,
    required this.onChanged,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.directions_run_rounded, 'Activity'),
    (Icons.bedtime_rounded, 'Sleep'),
    (Icons.monitor_weight_outlined, 'Body'),
    (Icons.more_horiz_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF061C28),
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.7)),
      ),
      padding: EdgeInsets.only(
        top: 9,
        bottom: 6 + MediaQuery.paddingOf(context).bottom * 0.45,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _items[i].$1,
                        color: i == index
                            ? AppTheme.cyan
                            : AppTheme.textSecondary,
                        size: 23,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _items[i].$2,
                        style: TextStyle(
                          color: i == index
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: i == index
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: i == index ? 18 : 4,
                        height: 2,
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppTheme.cyan
                              : Colors.transparent,
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
