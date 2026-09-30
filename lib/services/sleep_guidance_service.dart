class SleepGuidanceService {
  static String targetForBirthday(DateTime? birthday) {
    if (birthday == null) return 'Add birthday for guidance';

    final now = DateTime.now();
    var age = now.year - birthday.year;
    final birthdayPassed = now.month > birthday.month ||
        (now.month == birthday.month && now.day >= birthday.day);
    if (!birthdayPassed) age--;

    if (age >= 65) return '7–8 hours';
    if (age >= 18) return '7–9 hours';
    if (age >= 13) return '8–10 hours';
    if (age >= 6) return '9–12 hours';
    return 'Ask a pediatric clinician';
  }
}
