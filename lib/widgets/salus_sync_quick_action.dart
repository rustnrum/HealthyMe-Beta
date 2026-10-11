import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/health_sync_provider.dart';

/// Real sync state drives animation. No decorative or simulated spinner.
class SalusSyncQuickAction extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const SalusSyncQuickAction({super.key, required this.onTap});

  @override
  ConsumerState<SalusSyncQuickAction> createState() => _SalusSyncQuickActionState();
}

class _SalusSyncQuickActionState extends ConsumerState<SalusSyncQuickAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncing = ref.watch(healthSyncProvider).isLoading;
    // AnimationController notifies listeners, so change it after the build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (syncing && !_rotation.isAnimating) {
        _rotation.repeat();
      } else if (!syncing && _rotation.isAnimating) {
        _rotation.stop();
        _rotation.reset();
      }
    });
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: syncing ? null : widget.onTap,
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
                RotationTransition(
                  turns: _rotation,
                  child: const Icon(Icons.sync_rounded, color: AppTheme.cyan, size: 22),
                ),
                const SizedBox(height: 5),
                Text(syncing ? 'Syncing' : 'Sync',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
