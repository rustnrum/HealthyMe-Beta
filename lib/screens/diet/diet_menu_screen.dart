import 'package:flutter/material.dart';
import 'diet_shell.dart';

class DietMenuScreen extends StatelessWidget {
  const DietMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: const [
        Text('Menu', style: TextStyle(color: DietPalette.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text('Saved meals and reusable menus will live here.', style: TextStyle(color: DietPalette.textSecondary, fontSize: 14)),
        SizedBox(height: 18),
        DietPlaceholderCard(
          icon: Icons.menu_book_rounded,
          title: 'Menu library',
          detail: 'Placeholder only for now. This page will hold reusable meals, recipes and menu sets.',
          accent: DietPalette.accentWarm,
        ),
      ],
    );
  }
}
