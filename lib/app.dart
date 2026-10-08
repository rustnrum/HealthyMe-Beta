import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'screens/connections_screen.dart';
import 'screens/cpap_screen_v38.dart';
import 'screens/daily_state_screen.dart';
import 'screens/diet/diet_shell.dart';
import 'screens/health/health_shell.dart';
import 'screens/home_shell.dart';
import 'screens/device_gallery_screen.dart';
import 'screens/sleep_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/metric_detail_screen.dart';
import 'screens/labs_screen.dart';
import 'screens/body_visual_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/recovery_detail_screen.dart';
import 'screens/sources_screen.dart';
import 'screens/spo2_history_screen.dart';
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
        '/metric-heart-rate': (_) => const MetricDetailScreen(metric: 'Heart rate'),
        '/metric-resting-heart-rate': (_) => const MetricDetailScreen(metric: 'Resting heart rate'),
        '/metric-hrv': (_) => const MetricDetailScreen(metric: 'HRV'),
        '/metric-respiratory-rate': (_) => const MetricDetailScreen(metric: 'Respiratory rate'),
        '/metric-steps': (_) => const MetricDetailScreen(metric: 'Steps'),
        '/metric-active-calories': (_) => const MetricDetailScreen(metric: 'Active calories'),
        '/metric-distance': (_) => const MetricDetailScreen(metric: 'Distance'),
        '/metric-weight': (_) => const MetricDetailScreen(metric: 'Weight'),
        '/labs': (_) => const LabsScreen(),
        '/body-visual': (_) => const BodyVisualScreen(),
        '/device-gallery': (_) => const DeviceGalleryScreen(),
        '/sleep-detail': (_) => Scaffold(
          appBar: AppBar(title: const Text('Sleep')),
          body: const SleepScreen(),
        ),
        '/activity-detail': (_) => Scaffold(
          appBar: AppBar(title: const Text('Activity')),
          body: const ActivityScreen(),
        ),
        '/spo2-history': (_) => const SpO2HistoryScreen(),
        '/recovery': (_) => const RecoveryDetailScreen(),
        '/daily-state': (_) => const DailyStateScreen(),
        '/sources': (_) => const ConnectionsScreen(),
        '/sources-debug': (_) => const SourcesScreen(),
        '/cpap': (_) => const CpapScreenV38(),
        '/watch-device': (_) => const WatchDeviceScreen(),
        '/coach': (_) => Scaffold(
          appBar: AppBar(title: const Text('Salus AI')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Salus AI is not available in this beta. Your health data and '
                'manual tracking still work without an AI connection.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      },
      home: state.profile.completed
          ? const MorningCheckInGate(child: HomeShell())
          : const OnboardingScreen(),
    );
  }
}
