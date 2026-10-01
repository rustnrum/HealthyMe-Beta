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
          'Diet',
          style: TextStyle(
            color: DietPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'A separate Healthy Me module for food, calories and nutrition planning.',
          style: TextStyle(color: DietPalette.textSecondary, fontSize: 14, height: 1.4),
        ),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.restaurant_rounded,
          title: 'Diet dashboard',
          detail: 'The module shell is ready. Food logging and nutrition analysis will be added later.',
        ),
        SizedBox(height: 12),
        DietPlaceholderCard(
          icon: Icons.sync_alt_rounded,
          title: 'Fitness connection',
          detail: 'Future planned meals and calories will feed the daily fitness/body picture without duplicating entry.',
          accent: DietPalette.green,
        ),
      ],
    );
  }
}
