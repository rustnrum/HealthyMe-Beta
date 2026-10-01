import 'package:flutter/material.dart';
import 'diet_shell.dart';

class GroceryListScreen extends StatelessWidget {
  const GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text(
          'Grocery',
          style: TextStyle(
            color: DietPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'The shopping list will be generated from planned meals instead of becoming another place to re-enter food.',
          style: TextStyle(color: DietPalette.textSecondary, fontSize: 14),
        ),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.shopping_cart_outlined,
          title: 'Grocery list',
          detail: 'Planned ingredients will be consolidated by category and quantity, with manual household items supported alongside them.',
          accent: DietPalette.green,
        ),
      ],
    );
  }
}
