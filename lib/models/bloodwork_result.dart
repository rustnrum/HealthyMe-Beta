class BloodworkResult {
  final String testName;
  final String resultValue;
  final String unit;
  final DateTime? collectionDate;
  final String labSource;

  const BloodworkResult({
    required this.testName,
    required this.resultValue,
    this.unit = '',
    this.collectionDate,
    this.labSource = '',
  });

  BloodworkResult copyWith({
    String? testName,
    String? resultValue,
    String? unit,
    DateTime? collectionDate,
    String? labSource,
  }) {
    return BloodworkResult(
      testName: testName ?? this.testName,
      resultValue: resultValue ?? this.resultValue,
      unit: unit ?? this.unit,
      collectionDate: collectionDate ?? this.collectionDate,
      labSource: labSource ?? this.labSource,
    );
  }
}
