class LabMarkers {
  static const common = [
    'A1C',
    'Fasting glucose',
    'Total cholesterol',
    'LDL cholesterol',
    'HDL cholesterol',
    'Triglycerides',
    'Vitamin D',
    'Ferritin',
    'Iron',
    'Hemoglobin',
    'Hematocrit',
    'Vitamin B12',
    'Folate',
    'TSH',
    'Free T4',
    'AST',
    'ALT',
    'Creatinine',
    'eGFR',
    'Sodium',
    'Potassium',
    'Magnesium',
    'hs-CRP',
    'Cortisol',
  ];

  static const male = [
    'Total testosterone',
    'Free testosterone',
    'SHBG',
    'Estradiol',
  ];

  static const female = [
    'Estradiol',
    'Progesterone',
    'FSH',
    'LH',
    'Total testosterone',
    'Free testosterone',
    'SHBG',
  ];

  static List<String> forSex(String sex) {
    final set = <String>{
      ...common,
      ...(sex == 'Female' ? female : male),
    }.toList()
      ..sort();
    return set;
  }
}
