// Salus Build 85: Home-only, artwork-first DESIGN PREVIEW.
// The displayed biometrics and insights deliberately come from the approved
// reference mockup; they are samples, not wearable or Health Connect records.
// Do not attach real data to fixed-progress PNGs. Replace that mechanism only
// after the design is approved and the real data architecture is ready.
import 'package:flutter/material.dart';

import '../preview84/data.dart';
import '../preview84/theme.dart';
import '../preview84/widgets/common.dart';

class SalusHome85 extends StatelessWidget {
  const SalusHome85({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, limits) {
      final wide = limits.maxWidth >= 650;
      final heroHeight = wide ? 352.0 : 288.0;
      return ColoredBox(
        color: C.bg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _MountainHero85(height: heroHeight, wide: wide),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: Column(
                    children: const [
                      _Recovery85(),
                      SizedBox(height: 14),
                      _Insight85(),
                      SizedBox(height: 14),
                      _Plan85(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MountainHero85 extends StatelessWidget {
  final double height;
  final bool wide;
  const _MountainHero85({required this.height, required this.wide});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/premium/salus_mountain_85.webp',
            fit: BoxFit.cover,
            alignment: const Alignment(0.28, -0.12),
            filterQuality: FilterQuality.high,
          ),
          // A dark left edge leaves the original greeting readable without
          // hiding the illuminated mountain peak at the right.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xCC07111D), Color(0x6A07111D), Color(0x1607111D)],
                stops: [0, 0.56, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x28050A12), Color(0x00050A12), C.bg],
                stops: [0, 0.50, 1],
              ),
            ),
          ),
          Positioned(
            left: wide ? 32 : 18,
            right: wide ? 32 : 18,
            top: 14,
            child: Row(
              children: [
                Text('SALUS', style: ts(wide ? 28 : 24, w: 300, ls: 5.1)),
                const Spacer(),
                const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 14),
                SizedBox(
                  width: 39,
                  height: 39,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 1.4),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/preview84/img/avatar.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: wide ? 106 : 85,
            left: wide ? 32 : 18,
            right: wide ? 32 : 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today, Jan 14',
                    style: ts(13, color: Colors.white.withValues(alpha: 0.90))),
                const SizedBox(height: 9),
                Text('Good morning,\nAlex',
                    style: ts(wide ? 36 : 31, w: 700, h: 1.09)),
                const SizedBox(height: 11),
                Text('Your body is showing strong\nrecovery. Keep the momentum.',
                    style: ts(wide ? 15 : 13.5,
                        color: Colors.white.withValues(alpha: 0.90), h: 1.36)),
              ],
            ),
          ),
          Positioned(
            right: 19,
            bottom: 10,
            child: Text('DESIGN PREVIEW  ·  SAMPLE DATA',
                style: ts(9, w: 600, ls: 0.8, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _Recovery85 extends StatelessWidget {
  const _Recovery85();

  static const icons = <IconData>[
    Icons.nightlight_round,
    Icons.monitor_heart_outlined,
    Icons.favorite_rounded,
    Icons.bolt_rounded,
    Icons.bar_chart_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tight = constraints.maxWidth < 355;
      final expanded = constraints.maxWidth >= 560;
      // SCard applies 12px/16px on either side plus a 1px border.
      // Reserve a real minimum for the five metric rows before assigning
      // space to the fixed-aspect ring. The old 133px ring left too little
      // room at 320 logical pixels and RenderFlex overflowed by 8.4px.
      final gap = tight ? 8.0 : 13.0;
      final cardSides = (tight ? 24.0 : 32.0) + 2.0;
      final minimumMetrics = tight ? 136.0 : 150.0;
      final roomForRing =
          constraints.maxWidth - cardSides - gap - minimumMetrics;
      final ringSize = expanded
          ? 185.0
          : tight
              ? roomForRing.clamp(100.0, 133.0).toDouble()
              : 151.0;
      return SCard(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Design preview: recovery readings are sample data, not health measurements.',
          )),
        ),
        padding: EdgeInsets.fromLTRB(tight ? 12 : 16, 16, tight ? 12 : 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                IconBadge(Icons.spa_rounded, C.green, filled: true, size: 19),
                SizedBox(width: 8),
                Expanded(child: Text('Recovery Score',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: Colors.white))),
                Icon(Icons.info_outline_rounded, color: C.sub, size: 16),
                SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: C.sub, size: 20),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                SizedBox(
                  key: const Key('home-recovery-ring'),
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset('assets/preview84/img/ring_recovery.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${Data.recovery}',
                              style: ts(expanded ? 54 : 44, w: 600, h: 1.0)),
                          const SizedBox(height: 3),
                          Text(Data.recoveryLabel,
                              style: ts(expanded ? 16 : 14, w: 500,
                                  color: C.green)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    key: const Key('home-recovery-metrics'),
                    children: [
                      for (var i = 0; i < Data.metrics.length; i++)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: tight ? 4.5 : 6.4),
                          child: Row(
                            children: [
                              Icon(icons[i], size: tight ? 14 : 16,
                                  color: Colors.white70),
                              SizedBox(width: tight ? 4 : 8),
                              Expanded(child: Text(Data.metrics[i][0],
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: ts(tight ? 10.5 : 12.5,
                                      color: Colors.white.withValues(alpha: .85)))),
                              const SizedBox(width: 3),
                              Text(Data.metrics[i][1],
                                  style: ts(tight ? 11.5 : 13.5, w: 600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _Insight85 extends StatelessWidget {
  const _Insight85();

  @override
  Widget build(BuildContext context) {
    return SCard(
      borderColor: const Color(0xFF234252),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF142238), Color(0xFF09212B)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFBD8AF9), size: 23),
              SizedBox(width: 8),
              Expanded(child: Text('AI Insight',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600,
                      color: Color(0xFFB8A2FE)))),
              Icon(Icons.chevron_right_rounded, color: C.sub, size: 21),
            ],
          ),
          const SizedBox(height: 12),
          Text(Data.insightLine1, style: ts(14, color: Colors.white.withValues(alpha: .91), h: 1.45)),
          const SizedBox(height: 11),
          Text(Data.insightLine2, style: ts(14, color: Colors.white.withValues(alpha: .91), h: 1.45)),
        ],
      ),
    );
  }
}

class _Plan85 extends StatelessWidget {
  const _Plan85();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed('/workout'),
        child: Container(
          height: 54,
          width: double.infinity,
          padding: const EdgeInsets.all(1.3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [C.teal, C.blue]),
            boxShadow: [BoxShadow(color: C.cyan.withValues(alpha: .22), blurRadius: 20)],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.7),
              gradient: const LinearGradient(
                colors: [Color(0xFF102C3B), Color(0xFF15334F)],
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The label must receive a bounded width. Flutter's Row
                // otherwise lays an inflexible Text out at its intrinsic
                // width, which overflows this CTA on a 320px viewport.
                Flexible(
                  child: Text("View Today's Plan",
                      key: const Key('home-plan-button-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: ts(15.5, w: 500)),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.arrow_forward_rounded, size: 19,
                    color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home-only navigation visuals. Other existing module pages retain their
/// original navigation, user data and all the current routes.
class SalusHome85Nav extends StatelessWidget {
  const SalusHome85Nav({
    super.key,
    required this.onTraining,
    required this.onHealth,
    required this.onDiscover,
  });

  final VoidCallback onTraining;
  final VoidCallback onHealth;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    const items = <(String, IconData, IconData)>[
      ('Home', Icons.home_rounded, Icons.home_outlined),
      ('Training', Icons.self_improvement_rounded, Icons.self_improvement_outlined),
      ('Health', Icons.favorite_rounded, Icons.favorite_border_rounded),
      ('Discover', Icons.explore_rounded, Icons.explore_outlined),
    ];
    final actions = <VoidCallback>[
      () {},
      onTraining,
      onHealth,
      onDiscover,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080C12),
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: actions[i],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(i == 0 ? items[i].$2 : items[i].$3,
                            color: i == 0 ? C.blue : C.sub, size: 25),
                        const SizedBox(height: 3),
                        Text(items[i].$1,
                            style: ts(11, w: i == 0 ? 600 : 400,
                                color: i == 0 ? C.blue : C.sub)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
