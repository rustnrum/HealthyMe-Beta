import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/salus_widgets.dart';
import 'diet_shell.dart';

class DietPlanningScreen extends StatelessWidget {
  const DietPlanningScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
    children: const [
      SalusSectionTitle(title: 'Plan', eyebrow: 'A week with intention'),
      SizedBox(height: 5),
      Text('Plan meals before they happen and connect nutrition targets to the rest of Salus.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4)),
      SizedBox(height: 16),
      DietPlaceholderCard(icon: Icons.calendar_month_outlined, title: 'Weekly meal plan', detail: 'Breakfast, lunch, dinner and snacks will calculate planned nutrition only from foods you actually select.', accent: DietPalette.accent),
    ],
  );
}
