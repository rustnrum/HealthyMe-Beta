import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum HealthyMeModule { fitness, diet, health }

class HealthyMeModuleMenuButton extends StatelessWidget {
  final HealthyMeModule current;
  final ValueChanged<HealthyMeModule> onSelected;

  const HealthyMeModuleMenuButton({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HealthyMeModule>(
      tooltip: 'Healthy Me sections',
      icon: const Icon(Icons.apps_rounded, size: 22),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<HealthyMeModule>(
          enabled: false,
          child: Text(
            'Healthy Me sections',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        _item(
          module: HealthyMeModule.fitness,
          current: current,
          icon: Icons.monitor_heart_rounded,
          color: AppTheme.mint,
          title: 'Fitness',
          subtitle: 'Activity • Sleep • Body • Recovery',
        ),
        const PopupMenuDivider(),
        _item(
          module: HealthyMeModule.diet,
          current: current,
          icon: Icons.restaurant_menu_rounded,
          color: AppTheme.amber,
          title: 'Diet',
          subtitle: 'Today • Meals • Plan • Grocery',
        ),
        const PopupMenuDivider(),
        _item(
          module: HealthyMeModule.health,
          current: current,
          icon: Icons.health_and_safety_rounded,
          color: AppTheme.purple,
          title: 'Health',
          subtitle: 'Overview • Vitals • Labs',
        ),
      ],
    );
  }

  static PopupMenuItem<HealthyMeModule> _item({
    required HealthyMeModule module,
    required HealthyMeModule current,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final selected = module == current;
    return PopupMenuItem<HealthyMeModule>(
      value: module,
      enabled: !selected,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  selected ? 'Current section' : subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_rounded, color: color, size: 21),
        ],
      ),
    );
  }
}
