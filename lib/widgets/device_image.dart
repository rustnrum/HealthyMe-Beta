import 'package:flutter/material.dart';

/// Stock icon art is mapped by device type, never by manufacturer name.
class DeviceImage extends StatelessWidget {
  final String deviceKind;
  final double size;
  const DeviceImage({super.key, required this.deviceKind, this.size = 70});

  static String imageFor(String kind) {
    final v = kind.toLowerCase();
    if (v.contains('ring')) return 'ring';
    if (v.contains('band')) return 'band';
    if (v.contains('watch')) return 'watch';
    if (v.contains('scale') || v.contains('weight')) return 'scale';
    if (v.contains('blood pressure') || v.contains('bp')) return 'bp';
    if (v.contains('thermo') || v.contains('temperature')) return 'thermometer';
    if (v.contains('oxygen') || v.contains('oximeter')) return 'oximeter';
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/devices/${imageFor(deviceKind)}.png',
    height: size, width: size, fit: BoxFit.contain,
    errorBuilder: (context, error, stack) =>
        Icon(Icons.devices_rounded, size: size * .7),
  );
}
