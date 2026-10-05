import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/module_menu_button.dart';
import 'diet_home_screen.dart';
import 'diet_menu_screen.dart';
import 'diet_planning_screen.dart';
import 'grocery_list_screen.dart';

class DietPalette {
  static const background = AppTheme.background;
  static const surface = AppTheme.surface;
  static const surfaceHigh = AppTheme.surfaceHigh;
  static const border = AppTheme.border;
  static const accent = AppTheme.amber;
  static const accentWarm = AppTheme.rose;
  static const green = AppTheme.mint;
  static const textPrimary = AppTheme.textPrimary;
  static const textSecondary = AppTheme.textSecondary;
  static const textMuted = AppTheme.textMuted;
}

class DietShell extends StatefulWidget {
  const DietShell({super.key});
  @override
  State<DietShell> createState() => _DietShellState();
}

class _DietShellState extends State<DietShell> {
  int _index = 0;
  static const _pages = [DietHomeScreen(), DietMenuScreen(), DietPlanningScreen(), GroceryListScreen()];
  static const _titles = ['Today', 'Meals', 'Plan', 'Grocery'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: DietPalette.background),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('SALUS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
            Text('DIET • ${_titles[_index].toUpperCase()}', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ]),
          actions: [HealthyMeModuleMenuButton(current: HealthyMeModule.diet, onSelected: (module) {
            switch (module) {
              case HealthyMeModule.fitness: Navigator.of(context).popUntil((route) => route.isFirst); break;
              case HealthyMeModule.diet: break;
              case HealthyMeModule.health: Navigator.of(context).pushReplacementNamed('/health'); break;
            }
          }), const SizedBox(width: 6)],
        ),
        body: SafeArea(top: false, child: IndexedStack(index: _index, children: _pages)),
        bottomNavigationBar: _DietBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),
      ),
    );
  }
}

class _DietBottomNav extends StatelessWidget {
  final int index; final ValueChanged<int> onChanged;
  const _DietBottomNav({required this.index, required this.onChanged});
  static const _items = [(Icons.today_outlined, 'Today'), (Icons.restaurant_menu_rounded, 'Meals'), (Icons.calendar_month_outlined, 'Plan'), (Icons.shopping_cart_outlined, 'Grocery')];
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: AppTheme.backgroundDeep, border: Border(top: BorderSide(color: AppTheme.border, width: 0.8))),
    padding: EdgeInsets.only(top: 8, bottom: 6 + MediaQuery.paddingOf(context).bottom * 0.45),
    child: Row(children: [for (var i=0;i<_items.length;i++) Expanded(child: InkWell(onTap: () => onChanged(i), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_items[i].$1, color: i==index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72), size: 22),
      const SizedBox(height: 4), Text(_items[i].$2, style: TextStyle(color: i==index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72), fontSize: 12, fontWeight: i==index ? FontWeight.w700 : FontWeight.w500)),
      const SizedBox(height: 4), AnimatedContainer(duration: const Duration(milliseconds: 160), width: i==index ? 22 : 4, height: 2, decoration: BoxDecoration(color: i==index ? AppTheme.cyan : Colors.transparent, borderRadius: BorderRadius.circular(99))),
    ]))))]),
  );
}

class DietPlaceholderCard extends StatelessWidget {
  final IconData icon; final String title; final String detail; final Color accent;
  const DietPlaceholderCard({super.key, required this.icon, required this.title, required this.detail, this.accent = DietPalette.accent});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF8EEDB), Color(0xFFEEDBB8)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: DietPalette.border.withValues(alpha: 0.75))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent, size: 25)),
      const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: DietPalette.textPrimary, fontSize: 19, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(detail, style: const TextStyle(color: DietPalette.textSecondary, fontSize: 13.5, height: 1.4))]))
    ]),
  );
}
