import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/state/diet_log_state.dart';

void main() {
  test('food entry roundtrips including source-like null nutrient fields', () {
    final original = FoodLogEntry(
      id: 'food-a', eatenAt: DateTime(2026, 10, 8, 9),
      slot: 'Breakfast', name: 'Eggs', portion: '2 large',
      calories: 140, protein: 12,
    );
    final restored = FoodLogEntry.fromJson(original.toJson());
    expect(restored.name, 'Eggs');
    expect(restored.calories, 140);
    expect(restored.protein, 12);
    expect(restored.carbs, isNull);
    expect(restored.eatenAt, original.eatenAt);
  });

  test('nutrient sums never impute a value for missing entries', () {
    final day = DateTime(2026, 10, 8);
    final state = DietLogState(loaded: true, entries: [
      FoodLogEntry(id: 'a', eatenAt: day, slot: 'Breakfast',
          name: 'Eggs', protein: 12),
      FoodLogEntry(id: 'b', eatenAt: day, slot: 'Lunch', name: 'Sandwich'),
    ]);
    expect(state.knownTotal(day, (e) => e.protein), 12);
    expect(state.incomplete(day, (e) => e.protein), isTrue);
    expect(state.knownTotal(day, (e) => e.calories), isNull);
  });

  test('grocery checkbox is persistent data not a UI-only decoration', () {
    final entry = GroceryEntry(id: '1', name: '2 onions');
    final restored = GroceryEntry.fromJson(entry.withChecked(true).toJson());
    expect(restored.checked, isTrue);
    expect(restored.name, '2 onions');
  });
}
