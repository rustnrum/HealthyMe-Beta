import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_shell.dart';

class HealthyMeApp extends StatelessWidget {
  const HealthyMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthy Me',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
