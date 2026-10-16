// Salus Home Build 90: scrollable approved composition, real stored data only.
// Only presentation and links here: Nutrition, Training, and Health retain their
// existing providers, storage keys, and modules. No demo health readings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../models/workout_models.dart';
import '../../services/home_insight_service.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../services/salus_recipe_photo_service.dart';
import '../../services/hrv_source_service.dart';
import '../../services/recovery_service.dart';
import '../../services/salus_energy_service.dart';
import '../../state/app_state.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus77_design.dart';
import '../../widgets/salus_premium_ui.dart';
import 'salus87_ui.dart';
import 'salus_home_ai_card.dart';
import 'salus_workout_portrait_92.dart';

class SalusHome87 extends ConsumerStatefulWidget {
  const SalusHome87({super.key});
  @override
  ConsumerState<SalusHome87> createState() => _SalusHome87State();
}

class _SalusHome87State extends ConsumerState<SalusHome87> {
  Map<String, double> _goals = const {};
  Map<String, SalusMealIdea> _plannedRecipes = const {};
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadNutritionGoals();
  }

  Future<void> _loadNutritionGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recipes = await const SalusMealPlannerService().loadRecipeAssignments();
      final values = <String, double>{};
      for (final metric in ['Calories', 'Protein', 'Carbs', 'Fat', 'Fiber']) {
        final v = prefs.getDouble('salus_nutrition_target_$metric');
        if (v != null && v > 0 && v.isFinite) values[metric] = v;
      }
      if (mounted) setState(() { _goals = values; _plannedRecipes = recipes; });
    } catch (_) {
      // Never silently replace unknown targets with invented defaults.
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _date(DateTime? value) => value == null
      ? 'Not recorded'
      : '${_months[value.month - 1]} ${value.day}, ${value.year}';

  void _go(String route) => Navigator.of(context).pushNamed(route);

  void _openNutrition() {
    Navigator.of(context).pushNamed('/diet').then((_) {
      if (mounted) _loadNutritionGoals();
    });
  }


  // Determine the next planned item from the existing daily meal calendar.
  // A meal already logged in that slot is no longer an upcoming meal today.
  (DateTime, String, String)? _nextPlannedMeal(TodayPlanState plan,
      List<FoodLogEntry> todayFoods, DateTime now) {
    const slots = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      final entries = plan.mealsFor(date);
      for (final slot in slots) {
        final name = entries[slot]?.trim() ?? '';
        if (name.isEmpty) continue;
        if (offset == 0 && ((slot == 'Breakfast' && now.hour >= 11) ||
            (slot == 'Lunch' && now.hour >= 16) ||
            (slot == 'Dinner' && now.hour >= 22))) continue;
        if (offset == 0 && todayFoods.any((item) =>
            item.slot == slot && item.name.trim().toLowerCase() == name.toLowerCase())) continue;
        return (date, slot, name);
      }
    }
    return null;
  }

  LabResult? _lab(List<LabResult> records, List<String> terms) {
    final matches = records.where((r) {
      final n = r.name.trim().toLowerCase();
      return terms.any((t) => n.contains(t));
    }).toList()
      ..sort((a, b) => (b.date ?? DateTime(1900))
          .compareTo(a.date ?? DateTime(1900)));
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final work = ref.watch(workoutStateProvider);
    final diet = ref.watch(dietLogStateProvider);
    final plan = ref.watch(todayPlanStateProvider);
    final now = DateTime.now();
    final rec = RecoveryService.build(app, completedWorkouts: work.history);
    final energy = SalusEnergyService.estimate(h, app.profile);
    final hrv = HrvSourceService.resolve(
      health: h, selectedSource: app.metricSources['HRV']);
    final insight = HomeInsightService.build(app);
    final name = app.profile.firstName.trim().isEmpty
        ? 'there' : app.profile.firstName.trim().split(' ').first;
    final greeting = now.hour < 12 ? 'Good morning' :
        now.hour < 17 ? 'Good afternoon' : 'Good evening';
    final sleep = h.sleepMinutes > 0
        ? '${h.sleepMinutes ~/ 60}h ${h.sleepMinutes % 60}m' : '—';
    final hr = h.restingHeartRate == null
        ? '—' : '${h.restingHeartRate!.round()} bpm';
    final hrvValue = hrv.displayedValue;
    final load = rec.contributors.where((c) => c.name == 'Training load').first;
    final activity = load.reading ?? (load.score == null ? '—' : '${load.score} est.');
    final stepsKnown = h.resolvedSources.containsKey('Steps');
    final dayFoods = diet.forDay(now);
    final kcal = diet.knownTotal(now, (e) => e.calories);
    final protein = diet.knownTotal(now, (e) => e.protein);
    final carbs = diet.knownTotal(now, (e) => e.carbs);
    final fat = diet.knownTotal(now, (e) => e.fat);
    final fiber = diet.knownTotal(now, (e) => e.fiber);
    final nextMeal = _nextPlannedMeal(plan, dayFoods, now);
    final recipeKey = nextMeal == null ? '' :
        '${salusDayKey(nextMeal.$1)}|${nextMeal.$2}';
    final plannedRecipe = _plannedRecipes[recipeKey];
    final nextMealPhoto = plannedRecipe?.name == nextMeal?.$3
        ? (plannedRecipe?.imagePath ?? '') : '';
    final todayAiEvidence = [
      'Sleep: $sleep; timestamp ${h.freshness['Sleep']?.toIso8601String() ?? 'unknown'}',
      'Resting heart rate: $hr; timestamp ${h.freshness['Resting heart rate']?.toIso8601String() ?? 'unknown'}',
      'Heart rate: ${h.latestHeartRate?.toStringAsFixed(0) ?? 'unavailable'} bpm',
      'HRV RMSSD: ${h.hrvMs?.toStringAsFixed(0) ?? 'unavailable'} ms',
      'SpO2: ${h.bloodOxygenPercent?.toStringAsFixed(0) ?? 'unavailable'}%',
      'Respiratory rate: ${h.respiratoryRate?.toStringAsFixed(1) ?? 'unavailable'} /min',
      'Steps: ${h.resolvedSources.containsKey('Steps') ? h.stepsToday : 'unavailable'}',
      'Nutrition: ${kcal == null ? 'not logged' : '${kcal.round()} kcal recorded'}',
      'Scheduled workouts today: ${work.scheduled.where((w) => _sameDay(w.scheduledFor, now)).map((w) => w.name).join(', ')}',
      'Recent lab results: ${app.labs.isEmpty ? 'unavailable' : app.labs.take(6).map((e) => '${e.name} ${e.value} ${e.unit} on ${e.date?.toIso8601String() ?? 'unknown date'}').join('; ')}',
      'Other metrics missing are unmeasured, not zero.',
    ].join('\n');
    final scheduledToday = work.scheduled.where((w) => _sameDay(w.scheduledFor, now)).toList();
    final completedToday = work.history.where((w) => _sameDay(w.completedAt, now)).toList();
    final workout = scheduledToday.isNotEmpty ? scheduledToday.first : null;
    final workoutTitle = workout?.name ?? (completedToday.isNotEmpty
        ? completedToday.first.name : 'No workout scheduled');
    final exercises = workout?.exercises.length ??
        (completedToday.isNotEmpty ? completedToday.first.exercises.length : 0);
    final displayExercises = workout?.exercises ??
        (completedToday.isNotEmpty ? completedToday.first.exercises : const <WorkoutExercise>[]);
    final totalSets = displayExercises.fold<int>(0, (sum, e) => sum + e.sets);
    final workoutFocus = workout?.focus.trim() ?? '';
    final duration = workout?.plannedMinutes;
    final segmentCounts = <String, int>{
      for (final part in ['Warm-up', 'Main', 'Cool-down'])
        part: displayExercises.where((e) => e.phase == part).length,
    };
    final lastBp = _lab(app.labs, ['blood pressure', 'systolic', 'bp reading']);
    final lastA1c = _lab(app.labs, ['a1c', 'hba1c', 'hemoglobin a1c']);
    final lastLdl = _lab(app.labs, ['ldl', 'low density lipoprotein']);
    final weight = h.weightLb ?? app.profile.manualCurrentWeightLb;
    final age = app.profile.age;
    final sex = app.profile.sex.trim().toLowerCase();
    final suggestions = <String>[
      'Annual wellness visit',
      if (age != null && age >= 45 && age <= 75) 'Colorectal screening',
      if (age != null && age >= 50 && age <= 69 && sex == 'male') 'Discuss prostate screening',
      if (age != null && age >= 40 && age <= 74 && sex == 'female') 'Discuss breast screening',
      'Immunizations and preventive care',
    ];

    return ColoredBox(
      color: S87.bg,
      child: ListView(
        key: const PageStorageKey<String>('salus-scrollable-home-90'),
        padding: EdgeInsets.zero,
        children: [
          // Keep actual SALUS lettering and the existing approved mountain asset.
          // A minimum height maintains the mountain hero composition. The
          // content determines the actual height so large fonts cannot clip.
          ConstrainedBox(
            key: const Key('salus-home-hero-90'),
            constraints: const BoxConstraints(minHeight: 206),
            child: Stack(children: [
              Positioned.fill(child: Image.asset(
                'assets/premium/salus_mountain_85.webp',
                fit: BoxFit.cover, alignment: Alignment.centerRight)),
              const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: [0, .42, 1],
                  colors: [Color(0xAC060A10), Color(0x46060A10), S87.bg],
                ),
              ))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Image.asset('assets/premium/salus_wordmark_90.png',
                      height: 34, width: 145, fit: BoxFit.contain,
                      semanticLabel: 'SALUS'),
                    const Spacer(),
                    IconButton(tooltip: 'Health updates',
                      onPressed: () => _go('/health'),
                      icon: const Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 28)),
                    IconButton(tooltip: 'Profile and settings',
                      onPressed: () => _go('/health'),
                      icon: const CircleAvatar(radius: 19,
                        backgroundColor: Color(0xFF304356),
                        child: Icon(Icons.person_outline_rounded,
                          color: Colors.white, size: 25))),
                  ]),
                  // Fixed *spacing*, never a fixed hero height or flex spacer.
                  // On accessibility scaling, the entire header grows.
                  const SizedBox(height: 11),
                  Text('${_date(now)}',
                    style: const TextStyle(color: S87.ink, fontSize: 15)),
                  const SizedBox(height: 5),
                  Text('$greeting,\n$name',
                    style: const TextStyle(color: S87.ink,
                      fontSize: 27, fontWeight: FontWeight.w700, height: 1.08)),
                  const SizedBox(height: 7),
                  const Text('Your daily health, activity and plans in one place.',
                    style: TextStyle(color: S87.ink, fontSize: 15, height: 1.3)),
                  const SizedBox(height: 6),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              S87Panel(
                accent: S87.teal,
                onTap: () => _go('/recovery'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _sectionHeading('Recovery Score', Icons.data_usage_rounded,
                    'Details', S87.green, () => _go('/recovery')),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, c) {
                    // The approved Home keeps the dial BESIDE the five
                    // measurements on normal phone widths. Stack only when
                    // the display is exceptionally narrow or text is enlarged.
                    final beside = c.maxWidth >= 276 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18.5;
                    final ringSize = beside
                        ? (c.maxWidth * .36).clamp(102.0, 155.0).toDouble()
                        : 152.0;
                    final dial = Center(child: S87ArtworkRing(
                      asset: 'assets/preview84/img/ring_recovery.png',
                      size: ringSize,
                      value: rec.score?.toString() ?? '—',
                      caption: rec.score == null ? 'Building' : rec.label,
                      measured: rec.score != null,
                    ));
                    final stats = Column(children: [
                      _recoveryMetric('Sleep', sleep, Icons.bedtime_rounded, S87.purple),
                      _recoveryMetric('HRV', hrvValue, Icons.monitor_heart_rounded, S87.teal),
                      _recoveryMetric('Resting HR', hr, Icons.favorite_rounded, S87.red),
                      _recoveryMetric('Salus Energy', energy.score == null ? '—' : '${energy.score} est.',
                        Icons.bolt_rounded, S87.green),
                      _recoveryMetric('Activity Load', activity, Icons.bar_chart_rounded, S87.blue),
                    ]);
                    return beside
                        ? Row(key: const Key('salus-home-recovery-row'),
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(width: ringSize, child: dial),
                              const SizedBox(width: 10),
                              Expanded(child: stats),
                            ])
                        : Column(children: [dial, const SizedBox(height: 10), stats]);
                  }),
                  const SizedBox(height: 10),
                  Text('${rec.confidence}% signal coverage · ${rec.score == null ? 'Not enough data' : 'Wellness estimate, not a diagnosis'}',
                    style: const TextStyle(color: S87.muted, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 12),
              S87Panel(accent: S87.red, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sectionHeading('Daily Measurements', Icons.monitor_heart_rounded,
                  'Sources', S87.red, () => _go('/sources')),
                const SizedBox(height: 8),
                _metricLine('Steps', stepsKnown ? '${h.stepsToday}' : '—',
                  Icons.directions_walk_rounded, S87.green),
                _metricLine('Heart rate', h.latestHeartRate == null
                    ? '—' : '${h.latestHeartRate!.round()} bpm',
                  Icons.favorite_rounded, S87.red),
                _metricLine('Active calories',
                    h.resolvedSources.containsKey('Active calories')
                      ? '${h.activeCaloriesToday.round()} kcal' : '—',
                  Icons.local_fire_department_outlined, S87.orange),
                _metricLine('SpO₂', h.bloodOxygenPercent == null
                    ? '—' : '${h.bloodOxygenPercent!.round()}%',
                  Icons.water_drop_outlined, S87.blue),
                _metricLine('Respiratory rate', h.respiratoryRate == null
                    ? '—' : '${h.respiratoryRate!.toStringAsFixed(1)}/min',
                  Icons.air_rounded, S87.purple),
              ])),
              const SizedBox(height: 12),
              SalusHomeAiCard(
                dayKey: salusDayKey(now), evidence: todayAiEvidence,
                localSummary: insight.message),
              const SizedBox(height: 12),
              S87Panel(accent: S87.green, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sectionHeading("Today's Nutrition", Icons.restaurant_menu_rounded,
                  'See module', S87.green, _openNutrition),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final ring = S87ArtworkRing(
                    asset: 'assets/preview84/img/ring_calories.png',
                    size: 152,
                    value: kcal == null ? '—' : '${kcal.round()}',
                    caption: _goals['Calories'] == null
                        ? 'kcal logged' : 'of ${_goals['Calories']!.round()} kcal',
                    measured: kcal != null && _goals['Calories'] != null,
                  );
                  final macros = Column(children: [
                    _nutritionBar('Protein', protein, _goals['Protein'], S87.blue),
                    _nutritionBar('Carbs', carbs, _goals['Carbs'], S87.green),
                    _nutritionBar('Fat', fat, _goals['Fat'], S87.orange),
                    _nutritionBar('Fiber', fiber, _goals['Fiber'], S87.purple),
                  ]);
                  return constraints.maxWidth >= 480
                      ? Row(children: [ring, const SizedBox(width: 16),
                          Expanded(child: macros)])
                      : Column(children: [ring, const SizedBox(height: 8), macros]);
                }),
                const SizedBox(height: 9),
                const SizedBox(height: 5),
                Text('Meals logged today: ${dayFoods.length} · Hydration: not connected',
                  style: const TextStyle(color: S87.muted, fontSize: 14)),
                if (dayFoods.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text('Latest: ${dayFoods.last.name}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: S87.ink, fontSize: 14)),
                ),
                const SizedBox(height: 16),
                const Text('NEXT PLANNED MEAL', style: TextStyle(color: S87.muted,
                  fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                InkWell(onTap: _openNutrition, child: LayoutBuilder(builder: (context, c) {
                  final photoSize = c.maxWidth >= 540 ? 116.0 : 92.0;
                  return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    SalusRecipePhoto(imagePath: nextMealPhoto,
                      width: photoSize, height: photoSize),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(nextMeal == null ? 'No meal planned' : nextMeal.$3,
                        style: const TextStyle(color: S87.ink, fontSize: 17,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(nextMeal == null ? 'Open Nutrition to plan your meals.' :
                        '${nextMeal.$2} • ${_date(nextMeal.$1)}',
                        style: const TextStyle(color: S87.muted, fontSize: 14)),
                      if (nextMeal != null && nextMealPhoto.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 4),
                          child: Text('No meal photo attached',
                            style: TextStyle(color: S87.muted, fontSize: 12))),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: S87.blue),
                  ]);
                })),
              ])),
              const SizedBox(height: 12),
              S87Panel(accent: S87.blue, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sectionHeading("Today's Workout", Icons.fitness_center_rounded,
                  'See module', S87.blue, () => _go('/workout')),
                const SizedBox(height: 13),
                LayoutBuilder(builder: (context, constraints) {
                  // Wrap naturally on narrow folded screens. Artwork is a
                  // landscape portrait, shown in full rather than cropped.
                  final narrow = constraints.maxWidth < 300;
                  return Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SalusWorkoutPortrait92(
                        profileSex: app.profile.sex,
                        profileCompleted: app.profile.completed,
                        width: narrow ? 99 : 126, height: narrow ? 86 : 95),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(workoutTitle, style: const TextStyle(
                            color: S87.ink, fontSize: 18,
                            fontWeight: FontWeight.w700)),
                          const SizedBox(height: 7),
                          Text(workout == null && completedToday.isEmpty
                                ? 'Open Training to plan your session.'
                                : workoutFocus.isNotEmpty ? workoutFocus
                                : '$exercises exercises ${workout != null ? 'planned' : 'completed'}',
                            style: const TextStyle(color: S87.muted,
                              fontSize: 14, height: 1.3)),
                        ])),
                    ]);
                }),
                const SizedBox(height: 12),
                Wrap(spacing: 13, runSpacing: 9, children: [
                  _workoutMeta('Duration', duration != null && duration > 0
                      ? '$duration min' : 'Not set'),
                  _workoutMeta('Exercises', workout != null || completedToday.isNotEmpty
                      ? '$exercises' : 'Not planned'),
                  _workoutMeta('Total sets', workout != null || completedToday.isNotEmpty
                      ? '$totalSets' : 'Not planned'),
                ]),
                if (workout != null && displayExercises.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 12, runSpacing: 6, children: [
                    if (segmentCounts['Warm-up']! > 0)
                      _workoutSection('Warm-up', segmentCounts['Warm-up']!),
                    if (segmentCounts['Main']! > 0)
                      _workoutSection('Main workout', segmentCounts['Main']!),
                    if (segmentCounts['Cool-down']! > 0)
                      _workoutSection('Cool-down', segmentCounts['Cool-down']!),
                  ]),
                ],
                if (workout != null && workout.exercises.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final exercise in workout.exercises.take(5))
                    Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.check_circle_outline_rounded, color: S87.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '${exercise.phase == 'Main' ? '' : '${exercise.phase} · '}'
                          '${exercise.name} · ${exercise.sets} sets × ${exercise.reps} reps'
                          '${exercise.weight == null ? '' : ' · ${exercise.weight} lb'}'
                          ' · ${exercise.restSeconds}s rest',
                          style: const TextStyle(color: S87.ink, fontSize: 14,
                            height: 1.4))),
                      ])),
                  if (workout.exercises.length > 5)
                    Text('+ ${workout.exercises.length - 5} more exercises',
                      style: const TextStyle(color: S87.muted, fontSize: 13)),
                  if (workout.notes.trim().isNotEmpty)
                    Text(workout.notes, style: const TextStyle(color: S87.muted, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                  onPressed: () => _go('/workout'),
                  icon: const Icon(Icons.play_arrow_rounded, color: S87.teal),
                  label: Text(workout == null ? 'Open Training' : 'View Workout',
                    style: const TextStyle(fontSize: 16)),
                )),
              ])),
              const SizedBox(height: 12),
              S87Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sectionHeading('Recent Trends', Icons.show_chart_rounded,
                  'Details', S87.blue, () => _go('/trends')),
                const SizedBox(height: 12),
                const Text('Resting Heart Rate', style: TextStyle(
                  color: S87.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                S77RestingHeartChart(values: h.restingHeartRate30,
                  height: 112, color: S87.red),
                Align(alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => _go('/metric-resting-heart-rate'),
                    child: const Text('View resting heart rate history'))),
                const SizedBox(height: 13),
                const Text('HRV (RMSSD)', style: TextStyle(
                  color: S87.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (hrv.rmssdHistory.length >= 2)
                  PremiumLineChart(values: hrv.rmssdHistory,
                    height: 112, color: S87.blue, unit: 'ms')
                else const SizedBox(height: 70, child: Center(child: Text(
                  'No verified HRV trend yet', style: TextStyle(
                    color: S87.muted, fontSize: 14)))),
                const SizedBox(height: 8),
                Text('RHR: ${h.restingHeartRate30.length} readings · HRV: ${hrv.rmssdHistory.length} readings',
                  style: const TextStyle(color: S87.muted, fontSize: 13)),
                TextButton(onPressed: () => _go('/metric-hrv'),
                  child: const Text('Explore HRV history')),
              ])),
              const SizedBox(height: 12),
              S87Panel(accent: S87.orange, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sectionHeading('Key Health Metrics', Icons.health_and_safety_rounded,
                  'See labs', S87.red, () => _go('/labs')),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth >= 680;
                  final tiles = [
                    _healthTile('Blood Pressure', lastBp?.value, lastBp?.unit,
                      lastBp?.date, Icons.favorite_rounded, S87.red),
                    _healthTile('A1c', lastA1c?.value, lastA1c?.unit,
                      lastA1c?.date, Icons.water_drop_rounded, S87.blue),
                    _healthTile('LDL Cholesterol', lastLdl?.value, lastLdl?.unit,
                      lastLdl?.date, Icons.bloodtype_outlined, S87.orange),
                    _healthTile('Weight', weight?.toStringAsFixed(1),
                      weight == null ? null : 'lb',
                      h.weightHistory.isNotEmpty ? h.weightHistory.last.date : null,
                      Icons.monitor_weight_rounded, S87.purple),
                  ];
                  final columns = wide ? 4 : 2;
                  final tileWidth = (c.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final tile in tiles)
                      SizedBox(width: tileWidth, child: tile),
                  ]);
                }),
                const SizedBox(height: 11),
                const Text('Follow-up dates appear after a clinician or user interval is recorded.',
                  style: TextStyle(color: S87.muted, fontSize: 13, height: 1.35)),
              ])),
              const SizedBox(height: 12),
              S87Panel(accent: S87.blue, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sectionHeading('Upcoming Care', Icons.calendar_month_rounded,
                  'Health Records', S87.blue, () => _go('/health')),
                const SizedBox(height: 8),
                const Text('Recommendations to review · not scheduled appointments',
                  style: TextStyle(color: S87.muted, fontSize: 13)),
                const SizedBox(height: 5),
                for (final item in suggestions)
                  _careRow(item, () => _go('/health')),
                const SizedBox(height: 10),
                const Text('No clinician follow-up dates saved yet. Your doctor’s instructions should take priority.',
                  style: TextStyle(color: S87.muted, fontSize: 13, height: 1.38)),
              ])),
              const SizedBox(height: 16),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _workoutMeta(String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: S87.muted, fontSize: 12)),
      Text(value, style: const TextStyle(color: S87.ink, fontSize: 14,
        fontWeight: FontWeight.w700)),
    ],
  );

  Widget _workoutSection(String label, int count) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline_rounded, size: 15, color: S87.blue),
      const SizedBox(width: 5),
      Text('$label · $count', style: const TextStyle(
        color: S87.muted, fontSize: 13)),
    ],
  );

  Widget _sectionHeading(String title, IconData icon, String action,
      Color tint, VoidCallback onTap) => Row(children: [
    Icon(icon, size: 25, color: tint),
    const SizedBox(width: 10),
    Expanded(child: Text(title, style: const TextStyle(
      color: S87.ink, fontSize: 19, fontWeight: FontWeight.w800))),
    Tooltip(message: action, child: TextButton(onPressed: onTap,
      child: const Text('View', style: TextStyle(color: S87.blue, fontSize: 14)))),
    const Icon(Icons.chevron_right_rounded, size: 19, color: S87.blue),
  ]);

  // Compact Home-only metric row: accessible type without wasting the
  // horizontal space needed to display the Recovery ring beside the values.
  Widget _recoveryMetric(String label, String value, IconData icon, Color color) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(label, maxLines: 2,
            style: const TextStyle(color: S87.ink, fontSize: 13.5,
              height: 1.15))),
          const SizedBox(width: 5),
          Flexible(child: Text(value, maxLines: 2,
            textAlign: TextAlign.end,
            style: const TextStyle(color: S87.ink, fontSize: 14,
              fontWeight: FontWeight.w800))),
        ]));

  Widget _metricLine(String label, String value, IconData icon, Color color) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(
            color: S87.ink, fontSize: 15))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end,
            style: const TextStyle(color: S87.ink,
              fontSize: 16, fontWeight: FontWeight.w800))),
        ]));

  Widget _nutritionBar(String label, double? value, double? target,
      Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label,
            style: const TextStyle(color: S87.ink, fontSize: 14))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(minHeight: 9,
              value: value == null || target == null ? 0 :
                  (value / target).clamp(0.0, 1.0).toDouble(),
              backgroundColor: S87.border, color: color))),
          const SizedBox(width: 10),
          SizedBox(width: 78, child: Text(
            value == null ? '—' : target == null
                ? '${value.round()} g' : '${value.round()}/${target.round()} g',
            textAlign: TextAlign.end,
            style: const TextStyle(color: S87.ink, fontSize: 13))),
        ]),
      );

  Widget _healthTile(String title, String? value, String? unit,
      DateTime? recorded, IconData icon, Color tint) => InkWell(
    onTap: () => _go('/labs'),
    borderRadius: BorderRadius.circular(15),
    child: Container(padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFF0B1721),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: S87.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: tint, size: 19),
          const SizedBox(width: 6),
          Expanded(child: Text(title, maxLines: 2,
            style: const TextStyle(color: S87.ink,
              fontSize: 14, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 18),
        Text(value == null || value.trim().isEmpty ? '—'
            : '${value.trim()} ${unit ?? ''}'.trim(),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: S87.ink,
            fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(recorded == null ? 'Last: not recorded' : 'Last: ${_date(recorded)}',
          maxLines: 2, style: const TextStyle(color: S87.muted, fontSize: 12)),
        const Text('Next: not set', style: TextStyle(
          color: S87.muted, fontSize: 12)),
      ]),
    ),
  );

  Widget _careRow(String title, VoidCallback onTap) =>
      InkWell(onTap: onTap, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.event_note_rounded, color: S87.teal, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              color: S87.ink, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            const Wrap(spacing: 14, runSpacing: 4, children: [
              Text('Last: not recorded', style: TextStyle(
                color: S87.muted, fontSize: 13)),
              Text('Next: not set', style: TextStyle(
                color: S87.muted, fontSize: 13)),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded, color: S87.blue),
        ]),
      ));
}
