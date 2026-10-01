import 'package:flutter/material.dart';
import 'diet_shell.dart';

class GroceryListScreen extends StatelessWidget {
  const GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text('Grocery List', style: TextStyle(color: DietPalette.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text('Shopping will eventually be generated from the meal plan.', style: TextStyle(color: DietPalette.textSecondary, fontSize: 14)),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.shopping_cart_outlined,
          title: 'Grocery list',
          detail: 'Placeholder only. Planned menus will later roll ingredients into one organized shopping list.',
          accent: DietPalette.green,
        ),
      ],
    );
  }
}
