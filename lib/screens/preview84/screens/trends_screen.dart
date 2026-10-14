import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets/common.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int range = 0;
  static const ranges = ['7D', '30D', '90D', '1Y'];
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(padding: EdgeInsets.fromLTRB(16, top + 8, 16, 24), children: [
        SizedBox(
          height: 44,
          child: Stack(alignment: Alignment.center, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
            ),
            Text('Trends', style: ts(18, w: 600)),
          ]),
        ),
        const SizedBox(height: 10),
        _RangeBar(selected: range, labels: ranges, onChanged: (i) => setState(() => range = i)),
        const SizedBox(height: 14),
        SCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CardHeader(icon: IconBadge(Icons.spa_rounded, C.green, filled: true, size: 20), title: 'Recovery Score'),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${Data.recovery}', style: ts(36, w: 600, h: 1.0)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(text: '+12%', style: ts(12.5, w: 600, color: C.green)),
                    TextSpan(text: ' vs. previous 7 days', style: ts(12.5, color: C.sub)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            const ChartPanel(
              asset: 'assets/preview84/img/trend_recovery.png',
              aspect: 1000 / 420,
              yLabels: ['100', '75', '50'],
              yFrac: [0.0833, 0.5, 0.9167],
              xLabels: days,
              badge: '82',
              badgeX: 0.9286,
              badgeY: 0.383,
              badgeColor: C.green,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CardHeader(icon: Icon(Icons.thermostat_rounded, color: C.pink, size: 22), title: 'Skin Temperature'),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(children: [
                TextSpan(text: '+0.3', style: ts(34, w: 600, h: 1.1)),
                TextSpan(text: ' °C', style: ts(18, color: Colors.white.withValues(alpha: .85))),
              ]),
            ),
            const SizedBox(height: 2),
            Text('Slightly higher than your 30-day baseline', style: ts(12.5, color: C.sub)),
            const SizedBox(height: 12),
            const ChartPanel(
              asset: 'assets/preview84/img/trend_skin.png',
              aspect: 1000 / 420,
              yLabels: ['+1.0', '0', '-1.0'],
              yFrac: [0.115, 0.5, 0.885],
              xLabels: days,
              badge: '+0.3°C',
              badgeX: 0.9286,
              badgeY: 0.385,
              badgeColor: C.pink,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const _Factors(),
      ]),
    );
  }
}

class _RangeBar extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _RangeBar({required this.selected, required this.labels, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: selected == i
                    ? BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2F7BFF), Color(0xFF1D5FE0)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .45), blurRadius: 14)],
                      )
                    : null,
                child: Text(labels[i], style: ts(13.5, w: selected == i ? 600 : 500, color: selected == i ? Colors.white : C.sub)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Factors extends StatelessWidget {
  const _Factors();
  static const icons = <IconData>[
    Icons.nightlight_round,
    Icons.monitor_heart_outlined,
    Icons.favorite_rounded,
    Icons.bolt_rounded,
    Icons.thermostat_rounded,
  ];
  @override
  Widget build(BuildContext context) {
    return SCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Contributing Factors', style: ts(15, w: 600)),
        const SizedBox(height: 12),
        for (var i = 0; i < Data.factors.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Icon(icons[i], size: 16, color: Colors.white.withValues(alpha: .85)),
              const SizedBox(width: 10),
              SizedBox(width: 116, child: Text(Data.factors[i][0] as String, style: ts(12.5, color: Colors.white.withValues(alpha: .9)))),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final pos = Data.factors[i][3] as bool;
                  return Stack(children: [
                    Container(height: 8, decoration: BoxDecoration(color: const Color(0xFF18222D), borderRadius: BorderRadius.circular(4))),
                    Container(
                      height: 8,
                      width: c.maxWidth * (Data.factors[i][1] as double),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(colors: pos ? [const Color(0xFF16A34A), C.green] : [const Color(0xFF5B6470), const Color(0xFF8D98A6)]),
                      ),
                    ),
                  ]);
                }),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text(Data.factors[i][2] as String,
                    textAlign: TextAlign.right,
                    style: ts(12.5, w: 600, color: (Data.factors[i][3] as bool) ? C.green : C.sub)),
              ),
            ]),
          ),
      ]),
    );
  }
}
