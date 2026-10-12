"""Build 69: AI meal discovery, recipe-to-calendar approval, food preferences,
week/month meal calendar. No migrations to previously stored plan or food logs.
"""
from pathlib import Path


def replace(path: str, old: str, new: str) -> None:
    p = Path(path)
    existing = p.read_text(encoding='utf-8')
    if new in existing:
        return
    count = existing.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one unique patch anchor, found {count}: {old[:80]}')
    p.write_text(existing.replace(old, new, 1), encoding='utf-8')


replace('pubspec.yaml', 'version: 0.21.30+68', 'version: 0.21.31+69')

replace('lib/screens/diet/diet_shell.dart',
'''import 'diet_home_screen.dart';
import 'diet_menu_screen.dart';
import 'diet_planning_screen.dart';
import 'grocery_list_screen.dart';''',
'''import 'diet_home_screen.dart';
import 'diet_menu_screen.dart';
import 'ai_meal_discovery_screen.dart';
import 'meal_calendar_screen.dart';
import 'grocery_list_screen.dart';''')

replace('lib/screens/diet/diet_shell.dart',
'''  static const _pages = [DietHomeScreen(), DietMenuScreen(), DietPlanningScreen(), GroceryListScreen()];
  static const _titles = ['Today', 'Meals', 'Plan', 'Grocery'];''',
'''  static const _titles = ['Today', 'Discover', 'My Meals', 'Calendar', 'Grocery'];''')

replace('lib/screens/diet/diet_shell.dart',
'''        body: SafeArea(top: false, child: IndexedStack(index: _index, children: _pages)),''',
'''        body: SafeArea(top: false, child: IndexedStack(index: _index, children: [
          const DietHomeScreen(), const AiMealDiscoveryScreen(),
          const DietMenuScreen(),
          MealCalendarScreen(onDiscover: () => setState(() => _index = 1)),
          const GroceryListScreen(),
        ])),''')

replace('lib/screens/diet/diet_shell.dart',
'''  static const _items = [(Icons.today_outlined, 'Today'), (Icons.restaurant_menu_rounded, 'Meals'), (Icons.calendar_month_outlined, 'Plan'), (Icons.shopping_cart_outlined, 'Grocery')];''',
'''  static const _items = [(Icons.today_outlined, 'Today'), (Icons.auto_awesome_outlined, 'Discover'), (Icons.restaurant_menu_rounded, 'Meals'), (Icons.calendar_month_outlined, 'Calendar'), (Icons.shopping_cart_outlined, 'Grocery')];''')

replace('lib/screens/diet/diet_shell.dart',
'''fontSize: 12, fontWeight: i==index ? FontWeight.w700 : FontWeight.w500''',
'''fontSize: 10.5, fontWeight: i==index ? FontWeight.w700 : FontWeight.w500''')
