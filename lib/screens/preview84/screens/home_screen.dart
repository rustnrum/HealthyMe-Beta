import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets/common.dart';
import 'trends_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListView(padding: EdgeInsets.zero, children: [
      _Hero(top: top),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(children: [
          const _RecoveryCard(),
          const SizedBox(height: 14),
          const _InsightCard(),
          const SizedBox(height: 14),
          const _PlanButton(),
        ]),
      ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  final double top;
  const _Hero({required this.top});
  @override
  Widget build(BuildContext context) {
    final h = top + 262;
    return SizedBox(
      height: h,
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/preview84/img/hero_mountain.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        Positioned(
          left: 18, right: 18, top: top + 14,
          child: Row(children: [
            Text('SALUS', style: ts(24, w: 300, ls: 5)),
            const Spacer(),
            const Icon(Icons.notifications_none_rounded, size: 24),
            const SizedBox(width: 14),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 1.5)),
              child: ClipOval(child: Image.asset('assets/preview84/img/avatar.png', fit: BoxFit.cover)),
            ),
          ]),
        ),
        Positioned(
          left: 18, right: 18, top: top + 82,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Data.today(), style: ts(14, color: Colors.white.withValues(alpha: .85))),
            const SizedBox(height: 8),
            Text('${Data.greeting()}\n${Data.name}', style: ts(31, w: 700, h: 1.08)),
            const SizedBox(height: 8),
            Text('Your body is showing strong\nrecovery. Keep the momentum.',
                style: ts(14, color: Colors.white.withValues(alpha: .75), h: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard();

  static const icons = <IconData>[
    Icons.nightlight_round,
    Icons.monitor_heart_outlined,
    Icons.favorite_rounded,
    Icons.bolt_rounded,
    Icons.bar_chart_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrendsScreen())),
      child: Column(children: [
        CardHeader(
          icon: const IconBadge(Icons.spa_rounded, C.green, filled: true, size: 20),
          title: 'Recovery Score',
          trailing: const Icon(Icons.info_outline_rounded, size: 14, color: C.sub),
        ),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 150, height: 150,
            child: Stack(alignment: Alignment.center, children: [
              Image.asset('assets/preview84/img/ring_recovery.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${Data.recovery}', style: ts(46, w: 500, h: 1.0)),
                const SizedBox(height: 2),
                Text(Data.recoveryLabel, style: ts(15, w: 500, color: C.green)),
              ]),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(children: [
              for (var i = 0; i < Data.metrics.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                  child: Row(children: [
                    Icon(icons[i], size: 16, color: C.sub),
                    const SizedBox(width: 9),
                    Expanded(child: Text(Data.metrics[i][0], style: ts(13, color: Colors.white.withValues(alpha: .85)))),
                    Text(Data.metrics[i][1], style: ts(14, w: 600)),
                  ]),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();
  @override
  Widget build(BuildContext context) {
    return SCard(
      borderColor: const Color(0xFF1F3A4A),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10202C), Color(0xFF0B1620)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardHeader(
          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C8CFF), size: 20),
          title: 'AI Insight',
        ),
        const SizedBox(height: 10),
        Text(Data.insightLine1, style: ts(14, color: Colors.white.withValues(alpha: .85), h: 1.4)),
        const SizedBox(height: 10),
        Text(Data.insightLine2, style: ts(14, color: Colors.white.withValues(alpha: .85), h: 1.4)),
      ]),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [C.teal, C.blue]),
        boxShadow: [BoxShadow(color: C.cyan.withValues(alpha: .25), blurRadius: 18)],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0B1B26), borderRadius: BorderRadius.circular(16.5)),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text("View Today's Plan", style: ts(16, w: 500)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ]),
      ),
      ),
    );
  }
}
