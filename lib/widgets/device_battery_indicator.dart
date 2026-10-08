import 'package:flutter/material.dart';

/// Works for any saved device type, not specific manufacturers.
class SalusDeviceBatteryIndicator extends StatelessWidget {
  const SalusDeviceBatteryIndicator({
    super.key,
    required this.deviceKind,
    required this.percentage,
    this.color = const Color(0xFF66CFA9),
  });
  final String deviceKind;
  final double percentage;
  final Color color;

  static IconData iconForKind(String kind) {
    final k = kind.toLowerCase();
    if (k.contains('ring')) return Icons.radio_button_unchecked_rounded;
    if (k.contains('watch') || k.contains('band')) return Icons.watch_rounded;
    if (k.contains('scale')) return Icons.monitor_weight_outlined;
    return Icons.devices_other_rounded;
  }

  static IconData iconForPercent(double percent) {
    final v = percent.clamp(0.0, 100.0);
    if (v <= 10) return Icons.battery_alert_rounded;
    if (v <= 25) return Icons.battery_1_bar_rounded;
    if (v <= 50) return Icons.battery_3_bar_rounded;
    if (v <= 75) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final value = percentage.clamp(0.0, 100.0);
    final tint = value <= 15 ? const Color(0xFFFF7474) : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconForKind(deviceKind), size: 17, color: color),
        const SizedBox(width: 4),
        Icon(iconForPercent(value), size: 20, color: tint),
        const SizedBox(width: 3),
        Text('${value.round()}%', style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
        )),
      ],
    );
  }
}
