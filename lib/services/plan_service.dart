import '../state/app_state.dart';
import 'body_status_service.dart';
import 'sleep_guidance_service.dart';

class PlanItem {
  final String title;
  final String detail;
  final String category;

  const PlanItem({
    required this.title,
    required this.detail,
    required this.category,
  });
}

class PlanService {
  static List<PlanItem> build(HealthyMeState app) {
    final report = BodyStatusService.build(app);
    final sleep = SleepGuidanceService.forAge(app.profile.age);
    final items = <PlanItem>[];

    final sleepSystem =
        report.systems.firstWhere((item) => item.name == 'Sleep');
    if (sleepSystem.level == StatusLevel.fair ||
        sleepSystem.level == StatusLevel.watch) {
      items.add(
        PlanItem(
          title: 'Prioritize sleep',
          detail:
              'Aim for ${sleep.label} tonight. Your current sleep signal is ${sleepSystem.value}.',
          category: 'Sleep',
        ),
      );
    } else {
      items.add(
        PlanItem(
          title: 'Protect your sleep window',
          detail:
              'Keep a consistent schedule around your ${sleep.label} age-based target.',
          category: 'Sleep',
        ),
      );
    }

    final recovery =
        report.systems.firstWhere((item) => item.name == 'Recovery');
    if (recovery.level == StatusLevel.watch) {
      items.add(
        const PlanItem(
          title: 'Keep training easy today',
          detail:
              'Recovery signals are off your recent pattern. A walk, mobility work or lighter strength session is a reasonable choice.',
          category: 'Training',
        ),
      );
    } else if (recovery.level == StatusLevel.fair) {
      items.add(
        const PlanItem(
          title: 'Keep today’s workout moderate',
          detail:
              'Recovery is mixed today. Use a session you can recover from instead of adding another hard training load.',
          category: 'Training',
        ),
      );
    } else {
      items.add(
        PlanItem(
          title: app.profile.primaryGoal == 'Build strength'
              ? 'Complete your planned strength work'
              : 'Get purposeful movement today',
          detail:
              'Use a session you can recover from and repeat consistently rather than chasing one perfect workout.',
          category: 'Training',
        ),
      );
    }

    if (app.profile.primaryGoal == 'Fat loss') {
      items.add(
        const PlanItem(
          title: 'Keep food simple today',
          detail:
              'Prioritize protein, high-fiber foods, vegetables and hydration. Exact calorie logging is optional, not required.',
          category: 'Nutrition',
        ),
      );
    } else {
      items.add(
        const PlanItem(
          title: 'Support the work you are doing',
          detail:
              'Use regular meals with adequate protein, produce and hydration rather than relying on perfect food logging.',
          category: 'Nutrition',
        ),
      );
    }

    if (app.labs.isNotEmpty) {
      final dated = app.labs.where((lab) => lab.date != null).toList()
        ..sort((a, b) => b.date!.compareTo(a.date!));
      if (dated.isNotEmpty) {
        final days = DateTime.now().difference(dated.first.date!).inDays;
        if (days > 300) {
          items.add(
            PlanItem(
              title: 'Lab picture is getting old',
              detail:
                  'Your newest dated lab result is $days days old. Treat it as historical context rather than a current snapshot.',
              category: 'Labs',
            ),
          );
        }
      }
    }

    if (!app.health.authorized) {
      items.add(
        const PlanItem(
          title: 'Connect body telemetry',
          detail:
              'Health Connect can give Salus real steps, sleep, heart, workout and body data so the daily report stops relying on gaps.',
          category: 'Data',
        ),
      );
    }

    return items;
  }
}
