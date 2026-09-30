import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/connection_models.dart';
import 'package:healthy_me/models/user_profile.dart';
import 'package:healthy_me/services/recommendation_service.dart';

void main() {
  test('fat loss profile produces nutrition guidance', () {
    final items = RecommendationService.build(
      profile: UserProfile(
        completed: true,
        birthday: DateTime(1972, 1, 1),
        primaryGoal: 'Fat loss',
      ),
      labs: const [],
      connections: const ConnectionsState(),
    );

    expect(items.any((item) => item.category == 'Nutrition'), isTrue);
  });
}
