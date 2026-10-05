import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/salus_widgets.dart';
import 'diet_shell.dart';

class DietMenuScreen extends StatelessWidget {
  const DietMenuScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
    children: const [
      SalusSectionTitle(title: 'Meals', eyebrow: 'Saved and repeatable'),
      SizedBox(height: 5),
      Text('Build a reusable food library so repeated meals become fast, accurate entries.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4)),
      SizedBox(height: 16),
      DietPlaceholderCard(icon: Icons.restaurant_menu_rounded, title: 'Saved meals', detail: 'Recipes, favorites, recent foods and frequently repeated meals will live here.', accent: DietPalette.accentWarm),
    ],
  );
}
