import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/body_status_service.dart';
import '../state/app_state.dart';
import '../state/navigation_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/status_widgets.dart';
import 'heart_screen.dart';
import 'labs_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final report = BodyStatusService.build(app);
    final color = _overallColor(report.overall);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          '${_greeting()}, ${app.profile.firstName}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          _today(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF103B4B),
                Color(0xFF0B2937),
                Color(0xFF09212E),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: app.health.authorized ? 0.78 : 0.35,
                      strokeWidth: 9,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      color: color,
                    ),
                    Center(
                      child: Icon(
                        report.overall == 'Watch'
                            ? Icons.visibility_outlined
                            : Icons.eco_outlined,
                        color: color,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Body Status',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.overall,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(report.summary),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: report.systems.map((system) {
                return SizedBox(
                  width: width,
                  height: 124,
                  child: SubsystemTile(
                    system: system,
                    onTap: () => _openSystem(context, ref, system.name),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        _sectionTitle(context, 'What changed today'),
        const SizedBox(height: 9),
        CommandCard(
          child: Column(
            children: [
              for (var i = 0; i < report.changes.length; i++) ...[
                _ChangeRow(change: report.changes[i]),
                if (i != report.changes.length - 1)
                  const Divider(height: 20),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Data freshness'),
        const SizedBox(height: 9),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FreshnessTile(
                icon: Icons.bedtime_outlined,
                label: 'Sleep',
                value: relativeAge(app.health.freshness['Sleep']),
                color: AppTheme.purple,
              ),
              _FreshnessTile(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                value: relativeAge(app.health.freshness['Weight']),
                color: AppTheme.mint,
              ),
              _FreshnessTile(
                icon: Icons.favorite_outline,
                label: 'Heart',
                value: relativeAge(app.health.freshness['Heart rate']),
                color: AppTheme.rose,
              ),
              _FreshnessTile(
                icon: Icons.science_outlined,
                label: 'Labs',
                value: _labFreshness(app),
                color: AppTheme.amber,
              ),
            ],
          ),
        ),
        if (app.health.error != null) ...[
          const SizedBox(height: 14),
          CommandCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Health sync: ${app.health.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openSystem(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) {
    switch (name) {
      case 'Activity':
        ref.read(navigationProvider.notifier).go(1);
        break;
      case 'Sleep':
      case 'Recovery':
        ref.read(navigationProvider.notifier).go(2);
        break;
      case 'Body':
        ref.read(navigationProvider.notifier).go(3);
        break;
      case 'Cardio':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HeartScreen()),
        );
        break;
      case 'Labs':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LabsScreen()),
        );
        break;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _today() {
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Color _overallColor(String value) {
    switch (value) {
      case 'Good':
        return AppTheme.mint;
      case 'Fair':
        return AppTheme.amber;
      case 'Watch':
        return AppTheme.rose;
      default:
        return AppTheme.cyan;
    }
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w900),
      );

  String _labFreshness(HealthyMeState app) {
    final dated = app.labs.where((lab) => lab.date != null).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    if (dated.isEmpty) return 'No date';
    return '${DateTime.now().difference(dated.first.date!).inDays} days';
  }
}

class _ChangeRow extends StatelessWidget {
  final DailyChange change;

  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(change.level);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.insights_outlined, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                change.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                change.detail,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FreshnessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _FreshnessTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      margin: const EdgeInsets.only(right: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
