import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SalusAssets {
  static const String root = 'lib/assets/salus';
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
  static const String sourceLabs = '$root/source_labs.png';
  static const String botanicalSprig = '$root/botanical_sprig.png';
  static const String calloutAllInOne = '$root/callout_all_in_one.png';
  static const String calloutSmallSteps = '$root/callout_small_steps.png';
  static const String calloutSameMe = '$root/callout_same_me.png';
}

class SalusPaper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  const SalusPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF6EBD3),
        image: const DecorationImage(
          image: AssetImage(SalusAssets.paperTexture),
          fit: BoxFit.cover,
          opacity: 0.36,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.72), width: 0.85),
        boxShadow: [
          BoxShadow(
            color: AppTheme.backgroundDeep.withValues(alpha: 0.055),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                    letterSpacing: 2.1,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
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
  const SalusMetric({
    super.key,
    this.icon,
    this.asset,
    required this.value,
    required this.label,
    this.tint = AppTheme.mint,
  }) : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (asset != null)
          ClipOval(
            child: Image.asset(asset!, width: 52, height: 52, fit: BoxFit.cover),
          )
        else
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.16)),
            child: Icon(icon, color: tint, size: 25),
          ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.45,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showArt = artAsset != null && constraints.maxWidth >= 330;
          return Row(
            children: [
              if (tileAsset != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(tileAsset!, width: 58, height: 58, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: tint.withValues(alpha: 0.28)),
                  ),
                  child: Icon(icon, color: tint, size: 28),
                ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(line1, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14.5)),
                    if (line2 != null)
                      Text(
                        line2!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (showArt) ...[
                const SizedBox(width: 5),
                Opacity(
                  opacity: 0.78,
                  child: Image.asset(artAsset!, width: 92, height: 64, fit: BoxFit.contain),
                ),
              ],
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 24),
            ],
          );
        },
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
        SizedBox(width: 34, height: 34, child: Image.asset(asset, fit: BoxFit.contain)),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
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
  const SalusQuickAction({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: AppTheme.backgroundDeep,
              image: const DecorationImage(image: AssetImage(SalusAssets.leatherTexture), fit: BoxFit.cover, opacity: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.85)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.cyan, size: 22),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: AppTheme.creamText, fontSize: 14.5, fontWeight: FontWeight.w600)),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
