import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/body_status_service.dart';
import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../state/navigation_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import '../widgets/status_widgets.dart';
import 'body_status_detail_screen.dart';
import 'heart_screen.dart';
import 'labs_screen.dart';
import 'plan_screen.dart';
import 'recovery_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final report = BodyStatusService.build(app);
    final color = _overallColor(report.overall);
    final known = report.systems
        .where((system) => system.level != StatusLevel.noData)
        .length;
    final coverage = (known / report.systems.length).clamp(0.0, 1.0);
    final focus = PlanService.build(app).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        Text(
          '${_greeting()}, ${app.profile.firstName.isEmpty ? 'there' : app.profile.firstName}',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
            letterSpacing: -0.55,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _today(),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _BodyStatusHero(
          report: report,
          color: color,
          coverage: coverage,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BodyStatusDetailScreen()),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 350 ? 3 : 2;
            const spacing = 10.0;
            final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final height = columns == 3 ? 132.0 : 138.0;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final system in report.systems)
                  SizedBox(
                    width: width,
                    height: height,
                    child: SubsystemTile(
                      system: system,
                      onTap: () => _openSystem(context, ref, system.name),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        HmSectionHeader(
          title: 'What changed today',
          action: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BodyStatusDetailScreen()),
          ),
        ),
        const SizedBox(height: 10),
        CommandCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < report.changes.length; i++) ...[
                _ChangeRow(change: report.changes[i]),
                if (i != report.changes.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        HmSectionHeader(
          title: "Today's focus",
          action: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlanScreen()),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: focus.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 184,
              child: _FocusCard(item: focus[index]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const HmSectionHeader(title: 'Data freshness'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FreshnessTile(
                icon: Icons.bedtime_rounded,
                label: 'Sleep',
                value: relativeAge(app.health.freshness['Sleep']),
                color: AppTheme.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FreshnessTile(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                value: relativeAge(app.health.freshness['Weight']),
                color: AppTheme.cyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FreshnessTile(
                icon: Icons.science_rounded,
                label: 'Labs',
                value: _labFreshness(app),
                color: AppTheme.amber,
              ),
            ),
          ],
        ),
        if (app.health.error != null) ...[
          const SizedBox(height: 14),
          CommandCard(
            color: AppTheme.surfaceMuted,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HmIconBadge(
                  icon: Icons.info_outline_rounded,
                  color: AppTheme.amber,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Health sync: ${app.health.error}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openSystem(BuildContext context, WidgetRef ref, String name) {
    switch (name) {
      case 'Activity':
        ref.read(navigationProvider.notifier).go(1);
        break;
      case 'Sleep':
        ref.read(navigationProvider.notifier).go(2);
        break;
      case 'Recovery':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecoveryDetailScreen()),
        );
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Color _overallColor(String value) {
    switch (value) {
      case 'Good':
        return AppTheme.mint;
      case 'Fair':
        return AppTheme.purple;
      case 'Watch':
        return AppTheme.rose;
      default:
        return AppTheme.cyan;
    }
  }

  String _labFreshness(HealthyMeState app) {
    final dated = app.labs.where((lab) => lab.date != null).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    if (dated.isEmpty) return 'No data';
    final days = DateTime.now().difference(dated.first.date!).inDays;
    return days == 0 ? 'Today' : '${days}d ago';
  }
}

class _BodyStatusHero extends StatelessWidget {
  final BodyReport report;
  final Color color;
  final double coverage;
  final VoidCallback onTap;

  const _BodyStatusHero({
    required this.report,
    required this.color,
    required this.coverage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 176,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'lib/assets/images/hero_mountains.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF073648).withValues(alpha: 0.80),
                        const Color(0xFF072A3A).withValues(alpha: 0.72),
                        const Color(0xFF031A27).withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 118,
                      height: 118,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: coverage,
                            strokeWidth: 10,
                            color: color,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            strokeCap: StrokeCap.round,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF062433).withValues(alpha: 0.70),
                                border: Border.all(color: color.withValues(alpha: 0.24)),
                              ),
                              child: Icon(
                                report.overall == 'Watch'
                                    ? Icons.visibility_rounded
                                    : Icons.eco_rounded,
                                color: color,
                                size: 47,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 19),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Body Status',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.textSecondary,
                                size: 17,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.overall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            report.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final DailyChange change;

  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(change.level);
    final icon = change.title.toLowerCase().contains('sleep')
        ? Icons.bedtime_rounded
        : change.title.toLowerCase().contains('heart')
            ? Icons.favorite_rounded
            : change.title.toLowerCase().contains('breathing')
                ? Icons.air_rounded
                : change.title.toLowerCase().contains('weight')
                    ? Icons.monitor_weight_outlined
                    : change.title.toLowerCase().contains('activity')
                        ? Icons.directions_run_rounded
                        : Icons.insights_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  change.detail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMuted,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  final PlanItem item;

  const _FocusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = switch (item.category) {
      'Sleep' => AppTheme.purple,
      'Training' => AppTheme.mint,
      'Nutrition' => AppTheme.amber,
      'Labs' => AppTheme.cyan,
      _ => AppTheme.cyan,
    };
    final icon = switch (item.category) {
      'Sleep' => Icons.bedtime_rounded,
      'Training' => Icons.directions_run_rounded,
      'Nutrition' => Icons.restaurant_rounded,
      'Labs' => Icons.science_rounded,
      _ => Icons.check_circle_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(icon: icon, color: color, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
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
