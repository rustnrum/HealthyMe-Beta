import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await StorageService().loadBootstrapData();

  runApp(
    ProviderScope(
      overrides: [
        bootstrapDataProvider.overrideWithValue(bootstrap),
      ],
      child: const HealthyMeApp(),
    ),
  );
}
