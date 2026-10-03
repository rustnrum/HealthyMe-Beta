class DailyStateEntry {
  final DateTime date;
  final String status;
  final int? physicalCapability;
  final int? mentalCapability;
  final int? emotionalBalance;
  final int? overallRecovery;
  final int? muscularStress;
  final int? lackActivation;
  final int? negativeEmotionalState;
  final int? overallStress;
  final String? resetAction;
  final String? resetFeedback;

  const DailyStateEntry({
    required this.date,
    this.status = 'completed',
    this.physicalCapability,
    this.mentalCapability,
    this.emotionalBalance,
    this.overallRecovery,
    this.muscularStress,
    this.lackActivation,
    this.negativeEmotionalState,
    this.overallStress,
    this.resetAction,
    this.resetFeedback,
  });

  bool get isCompleted => status == 'completed';

  String get dayKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double? get recoveryAverage {
    if (!isCompleted) return null;
    final values = <int?>[
      physicalCapability,
      mentalCapability,
      emotionalBalance,
      overallRecovery,
    ];
    if (values.any((value) => value == null)) return null;
    return values.cast<int>().reduce((a, b) => a + b) / values.length;
  }

  double? get stressAverage {
    if (!isCompleted) return null;
    final values = <int?>[
      muscularStress,
      lackActivation,
      negativeEmotionalState,
      overallStress,
    ];
    if (values.any((value) => value == null)) return null;
    return values.cast<int>().reduce((a, b) => a + b) / values.length;
  }

  DailyStateEntry copyWith({
    DateTime? date,
    String? status,
    int? physicalCapability,
    int? mentalCapability,
    int? emotionalBalance,
    int? overallRecovery,
    int? muscularStress,
    int? lackActivation,
    int? negativeEmotionalState,
    int? overallStress,
    String? resetAction,
    String? resetFeedback,
  }) {
    return DailyStateEntry(
      date: date ?? this.date,
      status: status ?? this.status,
      physicalCapability: physicalCapability ?? this.physicalCapability,
      mentalCapability: mentalCapability ?? this.mentalCapability,
      emotionalBalance: emotionalBalance ?? this.emotionalBalance,
      overallRecovery: overallRecovery ?? this.overallRecovery,
      muscularStress: muscularStress ?? this.muscularStress,
      lackActivation: lackActivation ?? this.lackActivation,
      negativeEmotionalState:
          negativeEmotionalState ?? this.negativeEmotionalState,
      overallStress: overallStress ?? this.overallStress,
      resetAction: resetAction ?? this.resetAction,
      resetFeedback: resetFeedback ?? this.resetFeedback,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'status': status,
        'physicalCapability': physicalCapability,
        'mentalCapability': mentalCapability,
        'emotionalBalance': emotionalBalance,
        'overallRecovery': overallRecovery,
        'muscularStress': muscularStress,
        'lackActivation': lackActivation,
        'negativeEmotionalState': negativeEmotionalState,
        'overallStress': overallStress,
        'resetAction': resetAction,
        'resetFeedback': resetFeedback,
      };

  factory DailyStateEntry.fromJson(Map<String, dynamic> json) {
    int? rating(String key) {
      final value = (json[key] as num?)?.toInt();
      if (value == null) return null;
      return value.clamp(0, 6).toInt();
    }

    return DailyStateEntry(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'completed',
      physicalCapability: rating('physicalCapability'),
      mentalCapability: rating('mentalCapability'),
      emotionalBalance: rating('emotionalBalance'),
      overallRecovery: rating('overallRecovery'),
      muscularStress: rating('muscularStress'),
      lackActivation: rating('lackActivation'),
      negativeEmotionalState: rating('negativeEmotionalState'),
      overallStress: rating('overallStress'),
      resetAction: json['resetAction']?.toString(),
      resetFeedback: json['resetFeedback']?.toString(),
    );
  }
}
