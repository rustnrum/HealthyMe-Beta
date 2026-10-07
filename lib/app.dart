import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug_flags.dart';
import 'core/theme/app_theme.dart';
import 'screens/ai_coach_screen.dart';
import 'screens/connections_screen.dart';
import 'screens/cpap_screen.dart';
import 'screens/daily_state_screen.dart';
import 'screens/diet/diet_shell.dart';
import 'screens/health/health_shell.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/recovery_detail_screen.dart';
import 'screens/sources_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/watch_device_screen.dart';
import 'state/app_state.dart';
import 'widgets/morning_checkin_gate.dart';

class HealthyMeApp extends ConsumerWidget {
  const HealthyMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salus',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routes: {
        '/diet': (_) => const DietShell(),
        '/health': (_) => const HealthShell(),
        '/workout': (_) => const WorkoutScreen(),
        '/trends': (_) => const TrendsScreen(),
        '/recovery': (_) => const RecoveryDetailScreen(),
        '/daily-state': (_) => const DailyStateScreen(),
        '/sources': (_) => const ConnectionsScreen(),
        '/sources-debug': (_) => salusShowDeviceDebug
            ? const SourcesScreen()
            : const ConnectionsScreen(),
        '/cpap': (_) => const CpapScreen(),
        '/watch-device': (_) => const WatchDeviceScreen(),
        '/coach': (_) => const AiCoachScreen(),
      },
      home: state.profile.completed
          ? const MorningCheckInGate(child: HomeShell())
          : const OnboardingScreen(),
    );
  }
}
