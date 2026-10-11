import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../state/diet_log_state.dart';
import '../../widgets/salus_widgets.dart';

/// Visual calories/macros without inventing calorie or macro goals.
/// Percent segments describe only known food values, never completeness.
class FoodVisualOverview extends StatelessWidget {
  final DietLogState log;
  final DateTime day;
  const FoodVisualOverview({super.key, required this.log, required this.day});

  @override
  Widget build(BuildContext context) {
    final count = log.forDay(day).length;
    final kcal = log.knownTotal(day, (f) => f.calories);
    final protein = log.knownTotal(day, (f) => f.protein);
    final carbs = log.knownTotal(day, (f) => f.carbs);
    final fat = log.knownTotal(day, (f) => f.fat);
    final incomplete = log.incomplete(day, (f) => f.calories) ||
        log.incomplete(day, (f) => f.protein) ||
        log.incomplete(day, (f) => f.carbs) ||
        log.incomplete(day, (f) => f.fat);
    final macroEnergy = [
      (protein ?? 0) * 4,
      (carbs ?? 0) * 4,
      (fat ?? 0) * 9,
    ];
    final totalMacro = macroEnergy.reduce((a, b) => a + b);
    final accents = [AppTheme.mint, AppTheme.cyan, AppTheme.amber];

    return SalusPaper(glow: true, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 60, height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [AppTheme.mint, AppTheme.cyan])),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: AppTheme.backgroundDeep, size: 30)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today’s intake', style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12.5)),
              Text(kcal == null ? 'No calories logged' : '${kcal.round()} kcal',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 28, fontWeight: FontWeight.w900)),
              Text('$count food ${count == 1 ? 'entry' : 'entries'} recorded',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ])),
        ]),
        const SizedBox(height: 16),
        if (totalMacro > 0) ...[
          ClipRRect(borderRadius: BorderRadius.circular(100),
            child: SizedBox(height: 13, child: Row(children: [
              for (var i = 0; i < macroEnergy.length; i++)
                if (macroEnergy[i] > 0)
                  Expanded(flex: math.max(1, (macroEnergy[i] / totalMacro * 1000).round()),
                    child: ColoredBox(color: accents[i])),
            ]))),
          const SizedBox(height: 6),
          const Text('Known macro energy split · not a daily goal',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
        ] else
          const Text('Log known protein, carbohydrate and fat values to see your macro split.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          _macro('Protein', protein, 'g', AppTheme.mint),
          _macro('Carbs', carbs, 'g', AppTheme.cyan),
          _macro('Fat', fat, 'g', AppTheme.amber),
        ]),
        if (incomplete) ...[
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.info_outline, size: 15, color: AppTheme.amber),
            SizedBox(width: 6),
            Expanded(child: Text('Partial totals: some foods lack nutrition values.',
                style: TextStyle(color: AppTheme.amber, fontSize: 11.5))),
          ]),
        ],
      ],
    ));
  }

  Widget _macro(String label, double? amount, String unit, Color color) =>
      Expanded(child: Row(children: [
        Container(width: 5, height: 30, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(5))),
        const SizedBox(width: 8),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textMuted,
                fontSize: 11)),
            Text(amount == null ? '—' : '${amount.round()} $unit',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ])),
      ]));
}

class FoodPicture extends StatelessWidget {
  final String imageUrl;
  final double size;
  const FoodPicture({super.key, required this.imageUrl, this.size = 48});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(width: size, height: size,
      child: imageUrl.isEmpty
        ? const ColoredBox(color: AppTheme.surfaceHigh,
            child: Icon(Icons.lunch_dining_rounded, color: AppTheme.mint))
        : Image.network(imageUrl, fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const ColoredBox(
              color: AppTheme.surfaceHigh,
              child: Icon(Icons.lunch_dining_rounded, color: AppTheme.mint))),
    ),
  );
}
