class LabMarkerDefinition {
  final String name;
  final String unit;

  const LabMarkerDefinition(this.name, [this.unit = '']);
}

class LabPanelDefinition {
  final String name;
  final String description;
  final List<LabMarkerDefinition> markers;

  const LabPanelDefinition({
    required this.name,
    required this.description,
    required this.markers,
  });
}

class LabService {
  static const cbc = LabPanelDefinition(
    name: 'CBC',
    description: 'Blood cells and oxygen-carrying markers commonly included in a complete blood count.',
    markers: [
      LabMarkerDefinition('WBC', 'x10³/µL'),
      LabMarkerDefinition('RBC', 'x10⁶/µL'),
      LabMarkerDefinition('Hemoglobin', 'g/dL'),
      LabMarkerDefinition('Hematocrit', '%'),
      LabMarkerDefinition('MCV', 'fL'),
      LabMarkerDefinition('MCH', 'pg'),
      LabMarkerDefinition('MCHC', 'g/dL'),
      LabMarkerDefinition('RDW', '%'),
      LabMarkerDefinition('Platelets', 'x10³/µL'),
      LabMarkerDefinition('Neutrophils', '%'),
      LabMarkerDefinition('Lymphocytes', '%'),
      LabMarkerDefinition('Monocytes', '%'),
      LabMarkerDefinition('Eosinophils', '%'),
      LabMarkerDefinition('Basophils', '%'),
    ],
  );

  static const cmp = LabPanelDefinition(
    name: 'CMP / Metabolic',
    description: 'Common metabolic, kidney, electrolyte, protein and liver markers.',
    markers: [
      LabMarkerDefinition('Glucose', 'mg/dL'),
      LabMarkerDefinition('BUN', 'mg/dL'),
      LabMarkerDefinition('Creatinine', 'mg/dL'),
      LabMarkerDefinition('eGFR', 'mL/min/1.73m²'),
      LabMarkerDefinition('Sodium', 'mmol/L'),
      LabMarkerDefinition('Potassium', 'mmol/L'),
      LabMarkerDefinition('Chloride', 'mmol/L'),
      LabMarkerDefinition('CO₂ / Bicarbonate', 'mmol/L'),
      LabMarkerDefinition('Calcium', 'mg/dL'),
      LabMarkerDefinition('Total protein', 'g/dL'),
      LabMarkerDefinition('Albumin', 'g/dL'),
      LabMarkerDefinition('Globulin', 'g/dL'),
      LabMarkerDefinition('Total bilirubin', 'mg/dL'),
      LabMarkerDefinition('ALP', 'U/L'),
      LabMarkerDefinition('AST', 'U/L'),
      LabMarkerDefinition('ALT', 'U/L'),
    ],
  );

  static const lipids = LabPanelDefinition(
    name: 'Lipids',
    description: 'Common cholesterol and cardiometabolic markers.',
    markers: [
      LabMarkerDefinition('Total cholesterol', 'mg/dL'),
      LabMarkerDefinition('LDL cholesterol', 'mg/dL'),
      LabMarkerDefinition('HDL cholesterol', 'mg/dL'),
      LabMarkerDefinition('Triglycerides', 'mg/dL'),
      LabMarkerDefinition('Non-HDL cholesterol', 'mg/dL'),
      LabMarkerDefinition('ApoB', 'mg/dL'),
      LabMarkerDefinition('Lipoprotein(a)'),
    ],
  );

  static const glucose = LabPanelDefinition(
    name: 'Glucose control',
    description: 'Longer-term and fasting glucose context used alongside activity and nutrition trends.',
    markers: [
      LabMarkerDefinition('HbA1c', '%'),
      LabMarkerDefinition('Fasting glucose', 'mg/dL'),
      LabMarkerDefinition('Fasting insulin', 'µIU/mL'),
    ],
  );

  static const thyroid = LabPanelDefinition(
    name: 'Thyroid',
    description: 'Common thyroid markers that can add context to energy and metabolism trends.',
    markers: [
      LabMarkerDefinition('TSH', 'µIU/mL'),
      LabMarkerDefinition('Free T4', 'ng/dL'),
      LabMarkerDefinition('Free T3', 'pg/mL'),
    ],
  );

  static const nutrition = LabPanelDefinition(
    name: 'Iron & nutrients',
    description: 'Markers commonly useful when reviewing nutrition, energy and training context.',
    markers: [
      LabMarkerDefinition('Ferritin', 'ng/mL'),
      LabMarkerDefinition('Serum iron', 'µg/dL'),
      LabMarkerDefinition('TIBC', 'µg/dL'),
      LabMarkerDefinition('Transferrin saturation', '%'),
      LabMarkerDefinition('Vitamin D', 'ng/mL'),
      LabMarkerDefinition('Vitamin B12', 'pg/mL'),
      LabMarkerDefinition('Folate', 'ng/mL'),
      LabMarkerDefinition('Magnesium', 'mg/dL'),
    ],
  );

  static const maleHormones = LabPanelDefinition(
    name: 'Hormones',
    description: 'Sex-appropriate hormone markers when they are part of the user’s bloodwork.',
    markers: [
      LabMarkerDefinition('Total testosterone', 'ng/dL'),
      LabMarkerDefinition('Free testosterone'),
      LabMarkerDefinition('SHBG', 'nmol/L'),
      LabMarkerDefinition('Estradiol', 'pg/mL'),
      LabMarkerDefinition('LH', 'mIU/mL'),
      LabMarkerDefinition('FSH', 'mIU/mL'),
    ],
  );

  static const femaleHormones = LabPanelDefinition(
    name: 'Hormones',
    description: 'Sex-appropriate hormone markers when they are part of the user’s bloodwork.',
    markers: [
      LabMarkerDefinition('Estradiol', 'pg/mL'),
      LabMarkerDefinition('Progesterone', 'ng/mL'),
      LabMarkerDefinition('Total testosterone', 'ng/dL'),
      LabMarkerDefinition('Free testosterone'),
      LabMarkerDefinition('SHBG', 'nmol/L'),
      LabMarkerDefinition('LH', 'mIU/mL'),
      LabMarkerDefinition('FSH', 'mIU/mL'),
    ],
  );

  static const advanced = LabPanelDefinition(
    name: 'Advanced',
    description: 'Useful additional markers that are not part of every routine draw.',
    markers: [
      LabMarkerDefinition('hs-CRP', 'mg/L'),
      LabMarkerDefinition('Cortisol', 'µg/dL'),
      LabMarkerDefinition('CK', 'U/L'),
    ],
  );

  static List<LabPanelDefinition> panelsForSex(String sex) => [
        cbc,
        cmp,
        lipids,
        glucose,
        thyroid,
        nutrition,
        sex == 'Female' ? femaleHormones : maleHormones,
        advanced,
      ];

  static List<LabMarkerDefinition> markersForSex(String sex) {
    final seen = <String>{};
    final result = <LabMarkerDefinition>[];
    for (final panel in panelsForSex(sex)) {
      for (final marker in panel.markers) {
        if (seen.add(marker.name)) result.add(marker);
      }
    }
    return result;
  }

  static String defaultUnitFor(String sex, String markerName) {
    for (final marker in markersForSex(sex)) {
      if (marker.name == markerName) return marker.unit;
    }
    return '';
  }
}
