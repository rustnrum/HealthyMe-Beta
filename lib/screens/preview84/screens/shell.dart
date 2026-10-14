import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'health_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  static const items = <List<Object>>[
    ['Home', Icons.home_rounded, Icons.home_outlined],
    ['Training', Icons.self_improvement_rounded, Icons.self_improvement_outlined],
    ['Health', Icons.favorite_rounded, Icons.favorite_border_rounded],
    ['Discover', Icons.explore_rounded, Icons.explore_outlined],
  ];

  Widget _page() {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 2:
        return const HealthScreen();
      default:
        return Center(child: Text('${items[index][0]} - coming soon', style: ts(16, color: C.sub)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: _page(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080C12),
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i == 1) {
                        Navigator.of(context).pushNamed('/workout');
                      } else if (i == 3) {
                        Navigator.of(context).pushNamed('/sources');
                      } else {
                        setState(() => index = i);
                      }
                    },
                    child: _NavItem(
                      label: items[i][0] as String,
                      icon: (index == i ? items[i][1] : items[i][2]) as IconData,
                      selected: index == i,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  const _NavItem({required this.label, required this.icon, required this.selected});
  @override
  Widget build(BuildContext context) {
    final color = selected ? C.blue : C.sub;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        decoration: selected
            ? BoxDecoration(boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .55), blurRadius: 18, spreadRadius: -4)])
            : null,
        child: Icon(icon, color: color, size: 26),
      ),
      const SizedBox(height: 3),
      Text(label, style: ts(11, w: selected ? 600 : 400, color: color)),
    ]);
  }
}


/// Design-only preview: all mock values are examples, NOT measured device readings.
class PreviewShell extends StatelessWidget {
  const PreviewShell({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: buildTheme(),
    child: Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        foregroundColor: Colors.white,
        toolbarHeight: 44,
        automaticallyImplyLeading: false,
        title: Text('DESIGN PREVIEW · SAMPLE DATA',
          style: ts(10, w: 600, color: C.sub, ls: .6)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 16, color: C.cyan),
            label: Text('Original Home', style: ts(11, color: C.cyan)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const Shell(),
    ),
  );
}
