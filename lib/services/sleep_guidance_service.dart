class SleepGuidance {
  final int minimumMinutes;
  final int? upperMinutes;
  final String label;
  final String note;

  const SleepGuidance({
    required this.minimumMinutes,
    this.upperMinutes,
    required this.label,
    required this.note,
  });
}

class SleepGuidanceService {
  static SleepGuidance forAge(int? age) {
    if (age == null) {
      return const SleepGuidance(
        minimumMinutes: 0,
        label: 'Add birthday',
        note: 'Birthday is needed for age-based sleep guidance.',
      );
    }
    if (age >= 65) {
      return const SleepGuidance(
        minimumMinutes: 420,
        upperMinutes: 480,
        label: '7–8 hr',
        note: 'Age-based adult sleep guidance.',
      );
    }
    if (age >= 18) {
      return const SleepGuidance(
        minimumMinutes: 420,
        upperMinutes: 540,
        label: '7–9 hr',
        note: 'Age-based adult sleep guidance.',
      );
    }
    if (age >= 13) {
      return const SleepGuidance(
        minimumMinutes: 480,
        upperMinutes: 600,
        label: '8–10 hr',
        note: 'Age-based teen sleep guidance.',
      );
    }
    if (age >= 6) {
      return const SleepGuidance(
        minimumMinutes: 540,
        upperMinutes: 720,
        label: '9–12 hr',
        note: 'Age-based child sleep guidance.',
      );
    }
    return const SleepGuidance(
      minimumMinutes: 0,
      label: 'Guidance unavailable',
      note: 'Salus does not provide a sleep target for children under age 6.',
    );
  }
}
