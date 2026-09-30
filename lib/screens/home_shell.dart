import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              'Health Connect was not connected. Open More → Devices & Sources for details.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Healthy Me',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (sync.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              tooltip: app.health.authorized
                  ? 'Sync Health Connect'
                  : 'Connect Health Connect',
              onPressed: _syncOrConnect,
              icon: Icon(
                app.health.authorized
                    ? Icons.sync_rounded
                    : Icons.add_link_rounded,
              ),
            ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(navigationProvider.notifier).go,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime_rounded),
            label: 'Sleep',
          ),
          NavigationDestination(
            icon: Icon(Icons.accessibility_new_outlined),
            selectedIcon: Icon(Icons.accessibility_new),
            label: 'Body',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
