import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Mounted once by MaterialApp.builder and available from every module.
/// It never listens until the user opens Voice and enables the microphone.
class SalusVoiceLauncher extends StatelessWidget {
  final VoidCallback onPressed;
  const SalusVoiceLauncher({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.cyan,
    shape: const CircleBorder(),
    elevation: 5,
    child: IconButton(
      tooltip: 'Talk to Salus',
      icon: const Icon(Icons.mic_none_rounded, color: Colors.black),
      onPressed: onPressed,
      iconSize: 26,
    ),
  );
}
