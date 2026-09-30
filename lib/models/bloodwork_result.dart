class BloodworkResult {
  final String id;
  final String testName;
  final String resultValue;
  final String unit;
  final DateTime? collectionDate;
  final String labSource;

  const BloodworkResult({
    required this.id,
    required this.testName,
    required this.resultValue,
    this.unit = '',
    this.collectionDate,
    this.labSource = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'testName': testName,
        'resultValue': resultValue,
        'unit': unit,
        'collectionDate': collectionDate?.toIso8601String(),
        'labSource': labSource,
      };

  factory BloodworkResult.fromJson(Map<String, dynamic> json) {
    return BloodworkResult(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      testName: json['testName']?.toString() ?? '',
      resultValue: json['resultValue']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      collectionDate:
          DateTime.tryParse(json['collectionDate']?.toString() ?? ''),
      labSource: json['labSource']?.toString() ?? '',
    );
  }

  BloodworkResult copyWith({
    String? testName,
    String? resultValue,
    String? unit,
    DateTime? collectionDate,
    String? labSource,
  }) {
    return BloodworkResult(
      id: id,
      testName: testName ?? this.testName,
      resultValue: resultValue ?? this.resultValue,
      unit: unit ?? this.unit,
      collectionDate: collectionDate ?? this.collectionDate,
      labSource: labSource ?? this.labSource,
    );
  }
}
