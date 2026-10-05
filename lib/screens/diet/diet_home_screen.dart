import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/salus_widgets.dart';
import 'diet_shell.dart';

class DietHomeScreen extends StatelessWidget {
  const DietHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const SalusSectionTitle(title: 'Today', eyebrow: 'Nourish with intention'),
        const SizedBox(height: 4),
        const Text('Food data stays empty until you actually log it. Salus will never invent calories or nutrients.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 14),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.eco_outlined, color: DietPalette.green), SizedBox(width: 8), Text('Daily nutrition', style: TextStyle(color: DietPalette.textPrimary, fontSize: 21, fontWeight: FontWeight.w700)), Spacer(), Text('No food logged yet', style: TextStyle(color: DietPalette.textMuted, fontSize: 12))]),
          const SizedBox(height: 16),
          Row(children: [for (final item in const [('—','Calories'),('—','Protein'),('—','Carbs'),('—','Fat'),('—','Fiber')]) Expanded(child: _Nutrient(value: item.$1, label: item.$2))]),
        ])),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(color: const Color(0xFF3C3C22), borderRadius: BorderRadius.circular(14), border: Border.all(color: DietPalette.border)),
          child: const Row(children: [CircleAvatar(radius: 24, backgroundColor: Color(0x335F4A21), child: Icon(Icons.add_a_photo_outlined, color: AppTheme.cyan, size: 25)), SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Add Food', style: TextStyle(color: AppTheme.creamText, fontSize: 21, fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('Photo, barcode, search, describe or voice', style: TextStyle(color: Color(0xFFD7C7A7), fontSize: 13))])), Icon(Icons.chevron_right_rounded, color: AppTheme.creamText)]),
        ),
        const SizedBox(height: 11),
        SalusPaper(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.flag_outlined, color: DietPalette.accent), SizedBox(width: 8), Text('Focus Today', style: TextStyle(color: DietPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))]),
          SizedBox(height: 9), Text('Choose whole, nourishing foods and stay hydrated.', style: TextStyle(color: DietPalette.textSecondary, fontSize: 15, fontStyle: FontStyle.italic)),
        ])),
        const SizedBox(height: 14),
        const SalusSectionTitle(title: 'Meals', eyebrow: 'Today'),
        const SizedBox(height: 9),
        for (final meal in const [('Breakfast', Icons.wb_sunny_outlined, AppTheme.mint), ('Lunch', Icons.light_mode_outlined, AppTheme.amber), ('Dinner', Icons.wb_twilight_outlined, AppTheme.rose), ('Snacks', Icons.bedtime_outlined, AppTheme.purple)]) ...[
          SalusPaper(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: meal.$3.withValues(alpha: 0.15)), child: Icon(meal.$2, color: meal.$3, size: 21)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(meal.$1, style: const TextStyle(color: DietPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)), const Text('No food logged yet', style: TextStyle(color: DietPalette.textMuted, fontSize: 12.5))])), const Icon(Icons.chevron_right_rounded, color: DietPalette.textSecondary)])),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Nutrient extends StatelessWidget {
  final String value, label;
  const _Nutrient({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DietPalette.border.withValues(alpha: 0.55), width: 5)), child: Text(value, style: const TextStyle(color: DietPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w700))), const SizedBox(height: 5), Text(label, style: const TextStyle(color: DietPalette.textSecondary, fontSize: 12))]);
}
