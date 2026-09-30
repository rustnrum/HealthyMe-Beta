import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/profile_provider.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';

class HealthyMeApp extends ConsumerWidget {
  const HealthyMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthy Me',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: profile.completed
          ? const HomeShell()
          : const OnboardingScreen(),
    );
  }
}
