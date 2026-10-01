import 'package:flutter/material.dart';

import '../../widgets/module_menu_button.dart';
import '../labs_screen.dart';
import 'health_home_screen.dart';
import 'health_vitals_screen.dart';

class HealthPalette {
  static const background = Color(0xFF02131E);
  static const surface = Color(0xFF082A3C);
  static const surfaceHigh = Color(0xFF0B3449);
  static const border = Color(0xFF1C4960);
  static const accent = Color(0xFF8B6CFF);
  static const blue = Color(0xFF397CFF);
  static const mint = Color(0xFF28DDB8);
  static const textPrimary = Color(0xFFF2F5F8);
  static const textSecondary = Color(0xFFC0CAD3);
  static const textMuted = Color(0xFF8799A7);
}

class HealthShell extends StatefulWidget {
  const HealthShell({super.key});

  @override
  State<HealthShell> createState() => _HealthShellState();
}

class _HealthShellState extends State<HealthShell> {
  int _index = 0;

  static const _pages = [
    HealthHomeScreen(),
    HealthVitalsScreen(),
    LabsScreen(embedded: true),
  ];

  static const _titles = ['Health', 'Vitals', 'Labs'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: HealthPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: HealthPalette.background,
          foregroundColor: HealthPalette.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: HealthPalette.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Healthy Me • ${_titles[_index]}'),
          actions: [
            HealthyMeModuleMenuButton(
              current: HealthyMeModule.health,
              onSelected: (module) {
                switch (module) {
                  case HealthyMeModule.fitness:
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                  case HealthyMeModule.diet:
                    Navigator.of(context).pushReplacementNamed('/diet');
                    break;
                  case HealthyMeModule.health:
                    break;
                }
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _index, children: _pages),
        ),
        bottomNavigationBar: _HealthBottomNav(
          index: _index,
          onChanged: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}

class _HealthBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _HealthBottomNav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.health_and_safety_rounded, 'Health'),
    (Icons.monitor_heart_rounded, 'Vitals'),
    (Icons.science_rounded, 'Labs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF061C28),
        border: Border(top: BorderSide(color: HealthPalette.border, width: 0.8)),
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
                        color: i == index
                            ? HealthPalette.accent
                            : HealthPalette.textSecondary,
                        size: 23,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _items[i].$2,
                        style: TextStyle(
                          color: i == index
                              ? HealthPalette.textPrimary
                              : HealthPalette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: i == index
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: i == index ? 18 : 4,
                        height: 2,
                        decoration: BoxDecoration(
                          color: i == index
                              ? HealthPalette.accent
                              : Colors.transparent,
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
