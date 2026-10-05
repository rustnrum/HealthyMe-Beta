import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus_widgets.dart';
import '../labs_screen.dart';
import 'health_home_screen.dart';
import 'health_vitals_screen.dart';

class HealthPalette {
  static const background = AppTheme.background;
  static const surface = AppTheme.surface;
  static const surfaceHigh = AppTheme.surfaceHigh;
  static const border = AppTheme.border;
  static const accent = AppTheme.mint;
  static const blue = AppTheme.blue;
  static const mint = AppTheme.mint;
  static const textPrimary = AppTheme.textPrimary;
  static const textSecondary = AppTheme.textSecondary;
  static const textMuted = AppTheme.textMuted;
}

class HealthShell extends StatefulWidget {
  const HealthShell({super.key});
  @override
  State<HealthShell> createState() => _HealthShellState();
}

class _HealthShellState extends State<HealthShell> {
  int _index = 0;
  static const _pages = [HealthHomeScreen(), HealthVitalsScreen(), LabsScreen(embedded: true)];
  static const _titles = ['Health', 'Vitals', 'Labs'];

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(scaffoldBackgroundColor: HealthPalette.background),
    child: Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage(SalusAssets.leatherTexture), fit: BoxFit.cover, opacity: 0.88))),
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
        title: Row(children: [
          Opacity(opacity: 0.82, child: Image.asset(SalusAssets.headerBranch, width: 30, height: 44, fit: BoxFit.contain)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('SALUS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
          Text('HEALTH • ${_titles[_index].toUpperCase()}', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        ])]),
        actions: [HealthyMeModuleMenuButton(current: HealthyMeModule.health, onSelected: (module) {
          switch (module) {
            case HealthyMeModule.fitness: Navigator.of(context).popUntil((route) => route.isFirst); break;
            case HealthyMeModule.diet: Navigator.of(context).pushReplacementNamed('/diet'); break;
            case HealthyMeModule.health: break;
          }
        }), const SizedBox(width: 6)],
      ),
      body: SafeArea(top: false, child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: _HealthBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),
    ),
  );
}

class _HealthBottomNav extends StatelessWidget {
  final int index; final ValueChanged<int> onChanged;
  const _HealthBottomNav({required this.index, required this.onChanged});
  static const _items = [(Icons.health_and_safety_outlined, 'Health'), (Icons.monitor_heart_outlined, 'Vitals'), (Icons.science_outlined, 'Labs')];
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: AppTheme.backgroundDeep, image: DecorationImage(image: AssetImage(SalusAssets.leatherTexture), fit: BoxFit.cover, opacity: 0.82), border: Border(top: BorderSide(color: AppTheme.border, width: 0.8))),
    padding: EdgeInsets.only(top: 8, bottom: 6 + MediaQuery.paddingOf(context).bottom * 0.45),
    child: Row(children: [for (var i=0;i<_items.length;i++) Expanded(child: InkWell(onTap: () => onChanged(i), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_items[i].$1, color: i==index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72), size: 22),
      const SizedBox(height: 4), Text(_items[i].$2, style: TextStyle(color: i==index ? AppTheme.cyan : AppTheme.creamText.withValues(alpha: 0.72), fontSize: 12, fontWeight: i==index ? FontWeight.w700 : FontWeight.w500)),
      const SizedBox(height: 4), AnimatedContainer(duration: const Duration(milliseconds: 160), width: i==index ? 22 : 4, height: 2, decoration: BoxDecoration(color: i==index ? AppTheme.cyan : Colors.transparent, borderRadius: BorderRadius.circular(99))),
    ]))))]),
  );
}
