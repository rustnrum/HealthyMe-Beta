import 'package:flutter/material.dart';
import 'diet_shell.dart';

class DietHomeScreen extends StatelessWidget {
  const DietHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text(
          'Today',
          style: TextStyle(
            color: DietPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Daily food and nutrition will live here. No calories or nutrients are guessed until real meal data exists.',
          style: TextStyle(
            color: DietPalette.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.add_a_photo_rounded,
          title: 'Add Food',
          detail: 'Planned entry methods: AI meal photo, barcode, food search, describe or voice entry, and saved meals. The logging engine is not enabled yet.',
        ),
        SizedBox(height: 12),
        DietPlaceholderCard(
          icon: Icons.pie_chart_rounded,
          title: 'Daily nutrition',
          detail: 'Calories, protein, carbs, fat, fiber and useful micronutrients will appear only after food has actually been logged.',
          accent: DietPalette.green,
        ),
      ],
    );
  }
}
