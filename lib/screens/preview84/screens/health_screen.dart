import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets/common.dart';
import 'trends_screen.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  int tab = 0;
  static const tabs = ['Overview', 'Sleep', 'Recovery', 'Vitals'];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Column(children: [
      SizedBox(height: top + 12),
      Text('Health', style: ts(17, w: 600)),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i == 2) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrendsScreen()));
                    return;
                  }
                  setState(() => tab = i);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: tab == i
                      ? BoxDecoration(
                          color: const Color(0xFF0F2A3D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.cyan.withValues(alpha: .55)),
                          boxShadow: [BoxShadow(color: C.cyan.withValues(alpha: .18), blurRadius: 12)],
                        )
                      : null,
                  child: Text(tabs[i], style: ts(13, w: tab == i ? 600 : 400, color: tab == i ? Colors.white : C.sub)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: tab == 0
            ? const _Overview()
            : Center(child: Text('${tabs[tab]} - coming soon', style: ts(15, color: C.sub))),
      ),
    ]);
  }
}

class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
      const _SleepCard(),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Expanded(
          child: _VitalCard(
            icon: Icon(Icons.favorite_rounded, color: C.red, size: 18),
            title: 'Resting Heart Rate',
            value: Data.rhr, unit: ' bpm', up: false, delta: Data.rhrDelta, spark: 'assets/preview84/img/spark_rhr.png',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _VitalCard(
            icon: Icon(Icons.monitor_heart_outlined, color: C.purple, size: 18),
            title: 'HRV',
            value: Data.hrv, unit: ' ms', up: true, delta: Data.hrvDelta, spark: 'assets/preview84/img/spark_hrv.png',
            chevron: true,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      const _BatteryCard(),
      const SizedBox(height: 12),
      Row(children: const [
        Expanded(
          child: _RingStat(
            icon: Icon(Icons.directions_walk_rounded, color: C.cyan, size: 18),
            title: 'Steps', value: Data.steps, sub: Data.stepsGoal, ring: 'assets/preview84/img/ring_steps.png',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _RingStat(
            icon: Icon(Icons.local_fire_department_rounded, color: C.orange, size: 18),
            title: 'Calories', value: Data.calories, sub: Data.rmr, ring: 'assets/preview84/img/ring_calories.png',
          ),
        ),
      ]),
    ]);
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard();
  Widget legend(Color c, String l, String v) => Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: ts(12, color: C.sub)),
          Text(v, style: ts(13, w: 600)),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    return SCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardHeader(icon: Icon(Icons.nightlight_round, color: C.blue, size: 20), title: 'Sleep'),
        const SizedBox(height: 8),
        const BigValue(parts: [
          [Data.sleepHours, 'big'], ['h ', 'unit'], [Data.sleepMins, 'big'], ['m', 'unit'],
        ], big: 36, unit: 19),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(Data.sleepScore, style: ts(12.5, w: 500, color: C.green))),
          Text(Data.sleepWindow, style: ts(11, color: C.sub)),
        ]),
        const SizedBox(height: 12),
        AspectRatio(aspectRatio: 1000 / 64, child: Image.asset('assets/preview84/img/sleep_bar.png', fit: BoxFit.fill)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          legend(C.indigo, 'Deep', Data.deep),
          legend(C.blue, 'Core', Data.core),
          legend(C.purple, 'REM', Data.rem),
          const SizedBox(width: 4),
        ]),
      ]),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final Widget icon;
  final String title, value, unit, delta, spark;
  final bool up, chevron;
  const _VitalCard({
    required this.icon, required this.title, required this.value, required this.unit,
    required this.up, required this.delta, required this.spark, this.chevron = false,
  });
  @override
  Widget build(BuildContext context) {
    return SCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          icon,
          const SizedBox(width: 7),
          Expanded(child: Text(title, style: ts(12.5, w: 500), overflow: TextOverflow.ellipsis)),
          if (chevron) const Icon(Icons.chevron_right_rounded, color: C.sub, size: 18),
        ]),
        const SizedBox(height: 8),
        BigValue(parts: [[value, 'big'], [unit, 'unit']], big: 32, unit: 15),
        const SizedBox(height: 4),
        Delta(up: up, text: delta),
        const SizedBox(height: 8),
        AspectRatio(aspectRatio: 520 / 180, child: Image.asset(spark, fit: BoxFit.fill)),
      ]),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard();
  @override
  Widget build(BuildContext context) {
    return SCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardHeader(icon: Icon(Icons.bolt_rounded, color: C.blue, size: 20), title: 'Body Battery'),
        const SizedBox(height: 6),
        const BigValue(parts: [[Data.battery, 'big'], [' / 100', 'unit']], big: 32, unit: 20),
        const SizedBox(height: 8),
        AspectRatio(aspectRatio: 1000 / 300, child: Image.asset('assets/preview84/img/body_battery.png', fit: BoxFit.fill)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final l in ['12AM', '6AM', '12PM', '6PM', '12AM']) Text(l, style: ts(11, color: C.sub)),
        ]),
      ]),
    );
  }
}

class _RingStat extends StatelessWidget {
  final Widget icon;
  final String title, value, sub, ring;
  const _RingStat({required this.icon, required this.title, required this.value, required this.sub, required this.ring});
  @override
  Widget build(BuildContext context) {
    // Folded phones give each of the two cards about 158 px. Allow the
    // text column to flex rather than forcing its header past the ring.
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 200;
      final ringSize = compact ? 46.0 : 56.0;
      return SCard(
        padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 14, compact ? 8 : 12, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                icon,
                SizedBox(width: compact ? 4 : 6),
                Flexible(child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(13, w: 500),
                )),
              ]),
              const SizedBox(height: 10),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: ts(compact ? 24 : 26, w: 600, h: 1.1)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: ts(11.5, color: C.sub)),
            ]),
          ),
          SizedBox(width: ringSize, height: ringSize,
              child: Image.asset(ring, fit: BoxFit.contain,
                  filterQuality: FilterQuality.high)),
        ]),
      );
    });
  }
}
