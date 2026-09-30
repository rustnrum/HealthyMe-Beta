import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';

class HealthyMeApp extends ConsumerWidget {
  const HealthyMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthy Me',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: state.profile.completed
          ? const HomeShell()
          : const OnboardingScreen(),
    );
  }
}
