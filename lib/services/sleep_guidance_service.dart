class SleepGuidance {
  final String target;
  final String sourceNote;

  const SleepGuidance({
    required this.target,
    required this.sourceNote,
  });
}

class SleepGuidanceService {
  static SleepGuidance forAge(int? age) {
    if (age == null) {
      return const SleepGuidance(
        target: 'Add birthday',
        sourceNote: 'Age is needed to suggest a sleep target.',
      );
    }

    if (age >= 65) {
      return const SleepGuidance(
        target: '7–8 hr',
        sourceNote: 'CDC guidance for adults 65+.',
      );
    }

    if (age >= 61) {
      return const SleepGuidance(
        target: '7–9 hr',
        sourceNote: 'CDC guidance for adults 61–64.',
      );
    }

    if (age >= 18) {
      return const SleepGuidance(
        target: '7+ hr',
        sourceNote: 'CDC/AASM guidance for adults 18–60.',
      );
    }

    if (age >= 13) {
      return const SleepGuidance(
        target: '8–10 hr',
        sourceNote: 'CDC guidance for teens 13–17.',
      );
    }

    if (age >= 6) {
      return const SleepGuidance(
        target: '9–12 hr',
        sourceNote: 'CDC guidance for children 6–12.',
      );
    }

    return const SleepGuidance(
      target: 'Age-specific',
      sourceNote: 'Pediatric sleep needs vary substantially by age.',
    );
  }
}
