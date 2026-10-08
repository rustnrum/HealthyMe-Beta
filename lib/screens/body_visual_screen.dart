import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/salus_widgets.dart';

/// A source-honest illustrated view of entered tape measurements.
/// Measurements are not derived from the illustration.
class BodyVisualScreen extends ConsumerWidget {
  const BodyVisualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final m = app.measurements;
    final values = <(String, double?)>[
      ('Neck', m.neck), ('Chest', m.chest), ('Waist', m.waist),
      ('Hips', m.hips), ('Left arm', m.leftArm), ('Right arm', m.rightArm),
      ('Left thigh', m.leftThigh), ('Right thigh', m.rightThigh),
      ('Left calf', m.leftCalf), ('Right calf', m.rightCalf),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Body measurements')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
        const SalusSectionTitle(title: 'Body overview',
            eyebrow: 'Your measurements'),
        const SizedBox(height: 6),
        const Text('A visual reference for your real tape measurements. This image does not estimate fat, muscle or body shape.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
        const SizedBox(height: 14),
        SalusPaper(child: Column(children: [
          SizedBox(height: 395,
            child: Image.asset('assets/illustrations/body_front_back.webp',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(Icons.accessibility_new_rounded,
                    size: 110, color: AppTheme.mint))),
          ),
          const SizedBox(height: 10),
          const Text('Measurement reference • not a scan',
              style: TextStyle(color: AppTheme.textSecondary)),
        ])),
        const SizedBox(height: 15),
        const SalusSectionTitle(title: 'Tape measurements',
            eyebrow: 'Manual entries'),
        const SizedBox(height: 10),
        SalusPaper(child: Column(children: [
          for (var i = 0; i < values.length; i++) ...[
            _measurement(values[i].$1, values[i].$2),
            if (i < values.length - 1) const Divider(height: 12),
          ],
        ])),
        const SizedBox(height: 12),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device-based composition',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            _measurement('Body fat', app.health.bodyFatPercent, unit: '%'),
            _measurement('Body water', app.health.bodyWaterMassKg, unit: 'kg'),
            _measurement('Lean mass', app.health.leanBodyMassKg, unit: 'kg'),
            const SizedBox(height: 6),
            const Text('Only compatible measured readings are shown. Segmental body composition is not inferred.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5)),
          ],
        )),
      ]),
    );
  }

  Widget _measurement(String label, double? value, {String unit = 'in'}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 14))),
          Text(value == null ? 'Not recorded' :
              '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(color: AppTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w700)),
        ]));
}
