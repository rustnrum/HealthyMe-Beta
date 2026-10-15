import 'package:flutter/material.dart';
import 'connections_screen.dart';

/// Backward-compatible route: the same production Health Connect settings.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});
  @override Widget build(BuildContext context) => const ConnectionsScreen();
}
