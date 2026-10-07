import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SalusMountainBackground extends StatelessWidget {
  final Widget child;

  const SalusMountainBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'lib/assets/images/hero_mountains.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.26, 0.52, 0.74, 1.0],
                colors: [
                  Color(0x4202070B),
                  Color(0x7202070B),
                  Color(0xC103080D),
                  Color(0xF205090D),
                  Color(0xFF03070A),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 70,
          left: -90,
          right: -90,
          child: IgnorePointer(
            child: Container(
              height: 340,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppTheme.cyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
