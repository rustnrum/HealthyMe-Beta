import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/body_status_service.dart';
import '../state/app_state.dart';
import '../state/navigation_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
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
    final known = report.systems
        .where((system) => system.level != StatusLevel.noData)
        .length;
    final coverage = (known / report.systems.length).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Text(
          '${_greeting()}, ${app.profile.firstName.isEmpty ? 'there' : app.profile.firstName}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _today(),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 13),
        _BodyStatusHero(
          report: report,
          color: color,
          coverage: coverage,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 330 ? 3 : 2;
            final spacing = 8.0;
            final width = (constraints.maxWidth - spacing * (columns - 1)) /
                columns;
            final height = columns == 3 ? 102.0 : 110.0;

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
        const SizedBox(height: 18),
        const HmSectionHeader(title: 'What changed today'),
        const SizedBox(height: 8),
        CommandCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
          child: Column(
            children: [
              for (var i = 0; i < report.changes.length; i++) ...[
                _ChangeRow(change: report.changes[i]),
                if (i != report.changes.length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const HmSectionHeader(title: 'Data freshness'),
        const SizedBox(height: 8),
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
            const SizedBox(width: 8),
            Expanded(
              child: _FreshnessTile(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                value: relativeAge(app.health.freshness['Weight']),
                color: AppTheme.cyan,
              ),
            ),
            const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          CommandCard(
            color: AppTheme.surfaceMuted,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HmIconBadge(
                  icon: Icons.info_outline_rounded,
                  color: AppTheme.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Health sync: ${app.health.error}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    if (dated.isEmpty) return 'No date';
    final days = DateTime.now().difference(dated.first.date!).inDays;
    return days == 0 ? 'Today' : '$days days';
  }
}

class _BodyStatusHero extends StatelessWidget {
  final BodyReport report;
  final Color color;
  final double coverage;

  const _BodyStatusHero({
    required this.report,
    required this.color,
    required this.coverage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D4254),
            Color(0xFF0A2B3D),
            Color(0xFF071F2F),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -42,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.cyan.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 70,
            bottom: -70,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.mint.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: coverage,
                        strokeWidth: 8,
                        color: color,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            report.overall == 'Watch'
                                ? Icons.visibility_rounded
                                : Icons.eco_rounded,
                            color: color,
                            size: 34,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.overall,
                        style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ],
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
            : change.title.toLowerCase().contains('weight')
                ? Icons.monitor_weight_outlined
                : Icons.insights_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HmIconBadge(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  change.detail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    height: 1.25,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
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
