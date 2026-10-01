import 'package:flutter/material.dart';

import 'diet_home_screen.dart';
import 'diet_menu_screen.dart';
import 'diet_planning_screen.dart';
import 'grocery_list_screen.dart';

class DietPalette {
  static const background = Color(0xFF1B1209);
  static const surface = Color(0xFF2B1D0E);
  static const surfaceHigh = Color(0xFF382613);
  static const border = Color(0xFF65451F);
  static const accent = Color(0xFFFFB23D);
  static const accentWarm = Color(0xFFFF7A45);
  static const green = Color(0xFFA9DE67);
  static const textPrimary = Color(0xFFFFF6EB);
  static const textSecondary = Color(0xFFD9C8B6);
  static const textMuted = Color(0xFF9F8973);
}

class DietShell extends StatefulWidget {
  const DietShell({super.key});

  @override
  State<DietShell> createState() => _DietShellState();
}

class _DietShellState extends State<DietShell> {
  int _index = 0;

  static const _pages = [
    DietHomeScreen(),
    DietMenuScreen(),
    DietPlanningScreen(),
    GroceryListScreen(),
  ];

  static const _titles = ['Diet', 'Menu', 'Planning', 'Grocery List'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: DietPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: DietPalette.background,
          foregroundColor: DietPalette.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: DietPalette.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Healthy Me • ${_titles[_index]}'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Healthy Me sections',
              icon: const Icon(Icons.apps_rounded),
              onSelected: (value) {
                if (value == 'fitness') Navigator.of(context).pop();
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'fitness',
                  child: Row(
                    children: [
                      Icon(Icons.monitor_heart_rounded, color: Color(0xFF28DDB8)),
                      SizedBox(width: 10),
                      Text('Fitness'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_menu_rounded, color: DietPalette.accent),
                      SizedBox(width: 10),
                      Text('Diet'),
                      Spacer(),
                      Icon(Icons.check_rounded, color: DietPalette.accent),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _index, children: _pages),
        ),
        bottomNavigationBar: _DietBottomNav(
          index: _index,
          onChanged: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}

class _DietBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _DietBottomNav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.restaurant_rounded, 'Diet'),
    (Icons.menu_book_rounded, 'Menu'),
    (Icons.calendar_month_rounded, 'Planning'),
    (Icons.shopping_cart_outlined, 'Grocery List'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF24170B),
        border: Border(top: BorderSide(color: DietPalette.border, width: 0.8)),
      ),
      padding: EdgeInsets.only(
        top: 9,
        bottom: 6 + MediaQuery.paddingOf(context).bottom * 0.45,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _items[i].$1,
                        color: i == index ? DietPalette.accent : DietPalette.textSecondary,
                        size: 23,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == index ? DietPalette.textPrimary : DietPalette.textSecondary,
                          fontSize: 12,
                          fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: i == index ? 18 : 4,
                        height: 2,
                        decoration: BoxDecoration(
                          color: i == index ? DietPalette.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DietPlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color accent;

  const DietPlaceholderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.accent = DietPalette.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DietPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DietPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: DietPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    color: DietPalette.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
