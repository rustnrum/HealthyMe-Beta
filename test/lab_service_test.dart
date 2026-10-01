import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/lab_service.dart';

void main() {
  test('common bloodwork includes CBC, CMP, lipids and A1c', () {
    final names = LabService.markersForSex('Male').map((e) => e.name).toSet();
    expect(names, containsAll(['WBC', 'Creatinine', 'LDL cholesterol', 'HbA1c']));
  });

  test('hormone panel changes with sex profile', () {
    final male = LabService.markersForSex('Male').map((e) => e.name).toSet();
    final female = LabService.markersForSex('Female').map((e) => e.name).toSet();
    expect(male, contains('Total testosterone'));
    expect(female, contains('Progesterone'));
  });
}
