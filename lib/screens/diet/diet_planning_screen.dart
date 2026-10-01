import 'package:flutter/material.dart';
import 'diet_shell.dart';

class DietPlanningScreen extends StatelessWidget {
  const DietPlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text(
          'Plan',
          style: TextStyle(
            color: DietPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Plan the week before food is consumed and connect nutrition targets to the rest of Healthy Me.',
          style: TextStyle(color: DietPalette.textSecondary, fontSize: 14),
        ),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.calendar_month_rounded,
          title: 'Weekly meal plan',
          detail: 'Breakfast, lunch, dinner and snacks will calculate planned calories and macros and eventually feed those planned values into the daily body picture.',
        ),
      ],
    );
  }
}
