import '../models/bloodwork_result.dart';
import '../models/connection_models.dart';
import '../models/user_profile.dart';
import 'sleep_guidance_service.dart';

class GuidanceItem {
  final String title;
  final String detail;
  final String category;

  const GuidanceItem({
    required this.title,
    required this.detail,
    required this.category,
  });
}

class RecommendationService {
  static List<GuidanceItem> build({
    required UserProfile profile,
    required List<BloodworkResult> labs,
    required ConnectionsState connections,
  }) {
    final items = <GuidanceItem>[];
    final sleep = SleepGuidanceService.forAge(profile.age);

    items.add(
      GuidanceItem(
        title: 'Protect your sleep window',
        detail:
            'Your age-based target is ${sleep.target}. Consistency matters more than chasing a perfect single night.',
        category: 'Sleep',
      ),
    );

    if (!connections.preferredSourceByMetric.containsKey('Steps')) {
      items.add(
        const GuidanceItem(
          title: 'Connect daily activity',
          detail:
              'Choose a steps source so Healthy Me can use your real movement trend instead of guessing.',
          category: 'Activity',
        ),
      );
    }

    switch (profile.primaryGoal) {
      case 'Build strength':
        items.add(
          const GuidanceItem(
            title: 'Build around repeatable strength work',
            detail:
                'Start with a schedule you can sustain and progress gradually rather than adding volume all at once.',
            category: 'Training',
          ),
        );
        break;
      case 'Improve fitness':
        items.add(
          const GuidanceItem(
            title: 'Build a repeatable activity base',
            detail:
                'Combine regular walking or cardio with strength work and increase volume gradually.',
            category: 'Training',
          ),
        );
        break;
      case 'Maintain health':
        items.add(
          const GuidanceItem(
            title: 'Keep the basics consistent',
            detail:
                'Prioritize regular movement, strength training, adequate sleep, and a balanced eating pattern.',
            category: 'Training',
          ),
        );
        break;
      default:
        items.add(
          const GuidanceItem(
            title: 'Make fat loss sustainable',
            detail:
                'Use a repeatable calorie deficit, adequate protein, high-fiber foods, and strength training to support long-term progress.',
            category: 'Nutrition',
          ),
        );
        break;
    }

    if (labs.isNotEmpty) {
      items.add(
        GuidanceItem(
          title: 'Use your lab history as context',
          detail:
              '${labs.length} lab result${labs.length == 1 ? '' : 's'} are stored. Healthy Me can use trends as context without diagnosing them.',
          category: 'Labs',
        ),
      );
    }

    return items;
  }
}
