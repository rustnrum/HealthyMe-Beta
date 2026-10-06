import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SalusAssets {
  static const String root = 'lib/assets/salus';

  // Legacy assets kept so existing screens continue to compile while the visual
  // system migrates to the new Salus language.
  static const String paperTexture = '$root/paper_texture.png';
  static const String leatherTexture = '$root/dark_texture.png';
  static const String headerBranch = '$root/branch_gold.png';
  static const String metricWeight = '$root/metric_weight.png';
  static const String metricSleep = '$root/metric_sleep.png';
  static const String metricSteps = '$root/metric_steps.png';
  static const String metricRecovery = '$root/metric_recovery.png';
  static const String tileBody = '$root/tile_body.png';
  static const String tileSleep = '$root/tile_sleep.png';
  static const String tileActivity = '$root/tile_activity.png';
  static const String tileNotes = '$root/tile_notes.png';
  static const String artBody = '$root/art_body.png';
  static const String artSleep = '$root/art_sleep.png';
  static const String artActivity = '$root/art_activity.png';
  static const String artNotes = '$root/art_notes.png';
  static const String sourceWatch = '$root/source_watch.png';
  static const String sourceRing = '$root/source_ring.png';
  static const String sourceScale = '$root/source_scale.png';
  static const String sourcePhone = '$root/source_phone.png';
  static const String sourceHealth = '$root/source_health.png';
  static const String sourceLabs = '$root/source_labs.png';
  static const String botanicalSprig = '$root/botanical_sprig.png';
  static const String calloutAllInOne = '$root/callout_all_in_one.png';
  static const String calloutSmallSteps = '$root/callout_small_steps.png';
  static const String calloutSameMe = '$root/callout_same_me.png';

  // Salus v25 visual reference assets.
  static const String profileHero = '$root/salus_profile_hero.png';
  static const String aiOrb = '$root/salus_ai_orb.png';
  static const String sourcesOrbit = '$root/salus_sources_orbit.png';
  static const String deviceRing = '$root/salus_device_ring.png';
  static const String deviceWatch = '$root/salus_device_watch.png';
  static const String deviceScale = '$root/salus_device_scale.png';
  static const String deviceCpap = '$root/salus_device_cpap.png';
}

class SalusPageBackground extends StatelessWidget {
  final Widget child;
  final Widget? art;

  const SalusPageBackground({super.key, required this.child, this.art});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.pageGlow),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SalusLandscapePainter()),
            ),
          ),
          Positioned(
            top: -170,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.cyan.withValues(alpha: 0.12),
                      AppTheme.blue.withValues(alpha: 0.035),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -180,
            child: IgnorePointer(
              child: Container(
                width: 430,
                height: 430,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.teal.withValues(alpha: 0.09),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (art != null) art!,
          child,
        ],
      ),
    );
  }
}

class _SalusLandscapePainter extends CustomPainter {
  const _SalusLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.blue.withValues(alpha: 0.16),
          AppTheme.cyan.withValues(alpha: 0.055),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.52, size.height * 0.38),
          radius: size.width * 0.74,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final mountainBack = Path()
      ..moveTo(0, size.height * 0.34)
      ..lineTo(size.width * 0.12, size.height * 0.29)
      ..lineTo(size.width * 0.22, size.height * 0.33)
      ..lineTo(size.width * 0.37, size.height * 0.24)
      ..lineTo(size.width * 0.49, size.height * 0.31)
      ..lineTo(size.width * 0.66, size.height * 0.21)
      ..lineTo(size.width * 0.78, size.height * 0.29)
      ..lineTo(size.width * 0.92, size.height * 0.23)
      ..lineTo(size.width, size.height * 0.28)
      ..lineTo(size.width, size.height * 0.48)
      ..lineTo(0, size.height * 0.48)
      ..close();
    canvas.drawPath(
      mountainBack,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D2332).withValues(alpha: 0.82),
            const Color(0xFF07121B).withValues(alpha: 0.28),
          ],
        ).createShader(Offset.zero & size),
    );

    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppTheme.blue.withValues(alpha: 0.18);
    final ridgePath = Path()
      ..moveTo(0, size.height * 0.34)
      ..lineTo(size.width * 0.12, size.height * 0.29)
      ..lineTo(size.width * 0.22, size.height * 0.33)
      ..lineTo(size.width * 0.37, size.height * 0.24)
      ..lineTo(size.width * 0.49, size.height * 0.31)
      ..lineTo(size.width * 0.66, size.height * 0.21)
      ..lineTo(size.width * 0.78, size.height * 0.29)
      ..lineTo(size.width * 0.92, size.height * 0.23)
      ..lineTo(size.width, size.height * 0.28);
    canvas.drawPath(ridgePath, ridge);

    // Dotted biometric landscape inspired by the locked Salus reference.
    final dot = Paint();
    final baseY = size.height * 0.47;
    final xStep = math.max(9.0, size.width / 44).toDouble();
    for (var layer = 0; layer < 6; layer++) {
      final phase = layer * 0.72;
      final amplitude = 16.0 + layer * 8.0;
      final yOffset = layer * 24.0;
      final alpha = 0.32 - layer * 0.035;
      for (double x = -8; x <= size.width + 8; x += xStep) {
        final wave = math.sin((x / size.width) * math.pi * 3.1 + phase);
        final wave2 = math.sin((x / size.width) * math.pi * 6.4 - phase) * 0.34;
        final y = baseY + yOffset + (wave + wave2) * amplitude;
        final centerBias = (1.0 - ((x - size.width / 2).abs() / (size.width / 2)).clamp(0.0, 1.0)).toDouble();
        dot.color = AppTheme.cyan.withValues(alpha: alpha * (0.62 + centerBias * 0.38));
        canvas.drawCircle(Offset(x, y), 1.25 + centerBias * 0.65, dot);
      }
    }

    // Fine glow line across the front wave.
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppTheme.cyan.withValues(alpha: 0.22);
    final wavePath = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final y = baseY + 10 + math.sin((x / size.width) * math.pi * 3.0) * 28;
      if (x == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _SalusLandscapePainter oldDelegate) => false;
}

class SalusWeekStrip extends StatelessWidget {
  const SalusWeekStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(18, 3, 18, 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDeep.withValues(alpha: 0.90),
        border: Border(
          top: BorderSide(color: AppTheme.border.withValues(alpha: 0.52)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              '${monthNames[now.month - 1]} ${now.day}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = start.add(Duration(days: i));
                        final selected = day.year == now.year &&
                            day.month == now.month &&
                            day.day == now.day;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayNames[i],
                              style: TextStyle(
                                color: selected ? AppTheme.cyan : AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 25,
                              height: 25,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppTheme.cyan.withValues(alpha: 0.11)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected ? AppTheme.cyan : Colors.transparent,
                                  width: 1.0,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.cyan.withValues(alpha: 0.18),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: selected
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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

class SalusPaper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool glow;

  const SalusPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: glow
              ? AppTheme.cyan.withValues(alpha: 0.54)
              : AppTheme.border.withValues(alpha: 0.92),
          width: glow ? 1.15 : 0.85,
        ),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: AppTheme.cyan.withValues(alpha: 0.11),
              blurRadius: 28,
              spreadRadius: -4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: box),
    );
  }
}

class SalusSectionTitle extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;

  const SalusSectionTitle({super.key, required this.title, this.eyebrow, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SalusMetric extends StatelessWidget {
  final IconData? icon;
  final String? asset;
  final String value;
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  const SalusMetric({
    super.key,
    this.icon,
    this.asset,
    required this.value,
    required this.label,
    this.tint = AppTheme.mint,
    this.onTap,
  }) : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.09),
              border: Border.all(color: tint.withValues(alpha: 0.17)),
            ),
            child: asset != null
                ? Padding(
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(asset!, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                  )
                : Icon(icon, color: tint, size: 23),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, maxLines: 1, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: content),
    );
  }
}

class SalusModuleRow extends StatelessWidget {
  final IconData? icon;
  final String? tileAsset;
  final String? artAsset;
  final Color tint;
  final String title;
  final String line1;
  final String? line2;
  final VoidCallback? onTap;

  const SalusModuleRow({
    super.key,
    this.icon,
    this.tileAsset,
    this.artAsset,
    required this.tint,
    required this.title,
    required this.line1,
    this.line2,
    this.onTap,
  }) : assert(icon != null || tileAsset != null);

  @override
  Widget build(BuildContext context) {
    return SalusPaper(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.10), border: Border.all(color: tint.withValues(alpha: 0.18))),
            child: tileAsset != null
                ? Padding(padding: const EdgeInsets.all(7), child: Image.asset(tileAsset!, fit: BoxFit.contain))
                : Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(line1, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
                if (line2 != null)
                  Text(line2!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 24),
        ],
      ),
    );
  }
}

class SalusSourceItem extends StatelessWidget {
  final String asset;
  final String label;
  final String status;
  final Color statusColor;

  const SalusSourceItem({
    super.key,
    required this.asset,
    required this.label,
    required this.status,
    this.statusColor = AppTheme.mint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceHigh, border: Border.all(color: AppTheme.border)),
          child: Padding(padding: const EdgeInsets.all(7), child: Image.asset(asset, fit: BoxFit.contain, filterQuality: FilterQuality.high)),
        ),
        const SizedBox(height: 7),
        Text(label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
            const SizedBox(width: 4),
            Text(status, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class SalusQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const SalusQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppTheme.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              gradient: AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SalusStatusDot extends StatelessWidget {
  final Color color;
  final String label;

  const SalusStatusDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)])),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class SalusRecoveryOrb extends StatelessWidget {
  final int? score;
  final String subtitle;
  final VoidCallback? onTap;

  const SalusRecoveryOrb({super.key, required this.score, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final value = score == null ? 0.0 : (score!.clamp(0, 100) / 100.0);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(250),
                painter: _RecoveryOrbPainter(progress: value),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'RECOVERY',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    score?.toString() ?? '—',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 62,
                      height: 0.95,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    score == null ? 'Building baseline' : '/100',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 280,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(140),
      child: content,
    );
  }
}

class _RecoveryOrbPainter extends CustomPainter {
  final double progress;

  const _RecoveryOrbPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.34;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.cyan.withValues(alpha: 0.16),
          AppTheme.blue.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.48));
    canvas.drawCircle(center, size.width * 0.47, glowPaint);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = AppTheme.border.withValues(alpha: 0.72);
    canvas.drawCircle(center, radius, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        colors: [AppTheme.teal, AppTheme.cyan, AppTheme.blue, AppTheme.teal],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * (progress <= 0 ? 0.06 : progress),
      false,
      arc,
    );

    final dotPaint = Paint()..color = AppTheme.cyan.withValues(alpha: 0.72);
    const dots = 76;
    final ringRadius = size.width * 0.43;
    for (var i = 0; i < dots; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / dots);
      final active = i / dots <= progress;
      final alpha = active ? 0.78 : 0.18;
      dotPaint.color = AppTheme.cyan.withValues(alpha: alpha);
      final p = Offset(center.dx + math.cos(angle) * ringRadius, center.dy + math.sin(angle) * ringRadius);
      canvas.drawCircle(p, active ? 2.4 : 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RecoveryOrbPainter oldDelegate) => oldDelegate.progress != progress;
}

class SalusGlassMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String status;
  final Color color;
  final VoidCallback? onTap;

  const SalusGlassMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SalusPaper(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.11),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  status,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SalusDeviceTypeCard extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;
  final bool highlighted;

  const SalusDeviceTypeCard({
    super.key,
    required this.asset,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? AppTheme.cyan : AppTheme.border, width: highlighted ? 1.2 : 0.8),
        boxShadow: highlighted ? [BoxShadow(color: AppTheme.cyan.withValues(alpha: 0.12), blurRadius: 22)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.asset(asset, width: 82, height: 66, fit: BoxFit.contain, filterQuality: FilterQuality.high)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.18)),
        ],
      ),
    );
  }
}
