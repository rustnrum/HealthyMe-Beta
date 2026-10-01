import 'package:flutter/material.dart';
import 'diet_shell.dart';

class DietMenuScreen extends StatelessWidget {
  const DietMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text(
          'Meals',
          style: TextStyle(
            color: DietPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Reusable food lives here so repeated meals can become one-tap entries.',
          style: TextStyle(color: DietPalette.textSecondary, fontSize: 14),
        ),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.restaurant_menu_rounded,
          title: 'Saved meals',
          detail: 'Saved meals, recipes, favorite foods, recent foods and frequently repeated meals will share this library.',
          accent: DietPalette.accentWarm,
        ),
      ],
    );
  }
}
