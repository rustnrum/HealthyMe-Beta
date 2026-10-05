import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/salus_widgets.dart';
import 'diet_shell.dart';

class GroceryListScreen extends StatelessWidget {
  const GroceryListScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
    children: const [
      SalusSectionTitle(title: 'Grocery', eyebrow: 'One list, less friction'),
      SizedBox(height: 5),
      Text('The shopping list will be generated from planned meals instead of becoming another place to re-enter food.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4)),
      SizedBox(height: 16),
      DietPlaceholderCard(icon: Icons.shopping_cart_outlined, title: 'Grocery list', detail: 'Planned ingredients will be consolidated by category and quantity, with household items supported alongside them.', accent: DietPalette.green),
    ],
  );
}
