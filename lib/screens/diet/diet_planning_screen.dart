import 'package:flutter/material.dart';
import 'diet_shell.dart';

class DietPlanningScreen extends StatelessWidget {
  const DietPlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text('Planning', style: TextStyle(color: DietPalette.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text('Plan meals by day before calories are consumed.', style: TextStyle(color: DietPalette.textSecondary, fontSize: 14)),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.calendar_month_rounded,
          title: 'Meal planning',
          detail: 'Future daily plans will calculate planned calories/macros and make those planned values available to the Fitness module.',
        ),
      ],
    );
  }
}
