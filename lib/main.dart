import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initial = await StorageService().load();

  runApp(
    ProviderScope(
      overrides: [
        initialAppStateProvider.overrideWithValue(initial),
      ],
      child: const HealthyMeApp(),
    ),
  );
}
