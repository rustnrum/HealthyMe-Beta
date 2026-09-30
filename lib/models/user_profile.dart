class UserProfile {
  final bool completed;
  final String firstName;
  final String sex;
  final DateTime? birthday;
  final double? heightIn;
  final double? startingWeightLb;
  final double? currentWeightLb;
  final double? goalWeightLb;
  final String primaryGoal;
  final String activityLevel;

  const UserProfile({
    this.completed = false,
    this.firstName = '',
    this.sex = 'Male',
    this.birthday,
    this.heightIn,
    this.startingWeightLb,
    this.currentWeightLb,
    this.goalWeightLb,
    this.primaryGoal = 'Fat loss',
    this.activityLevel = 'Mostly seated',
  });

  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    var value = now.year - birthday!.year;
    final passed = now.month > birthday!.month ||
        (now.month == birthday!.month && now.day >= birthday!.day);
    if (!passed) value--;
    return value;
  }

  double? get remainingWeightLb {
    final current = currentWeightLb;
    final goal = goalWeightLb;
    if (current == null || goal == null) return null;
    return current - goal;
  }

  Map<String, dynamic> toJson() => {
        'completed': completed,
        'firstName': firstName,
        'sex': sex,
        'birthday': birthday?.toIso8601String(),
        'heightIn': heightIn,
        'startingWeightLb': startingWeightLb,
        'currentWeightLb': currentWeightLb,
        'goalWeightLb': goalWeightLb,
        'primaryGoal': primaryGoal,
        'activityLevel': activityLevel,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      completed: json['completed'] == true,
      firstName: json['firstName']?.toString() ?? '',
      sex: json['sex']?.toString() ?? 'Male',
      birthday: DateTime.tryParse(json['birthday']?.toString() ?? ''),
      heightIn: (json['heightIn'] as num?)?.toDouble(),
      startingWeightLb: (json['startingWeightLb'] as num?)?.toDouble(),
      currentWeightLb: (json['currentWeightLb'] as num?)?.toDouble(),
      goalWeightLb: (json['goalWeightLb'] as num?)?.toDouble(),
      primaryGoal: json['primaryGoal']?.toString() ?? 'Fat loss',
      activityLevel: json['activityLevel']?.toString() ?? 'Mostly seated',
    );
  }

  UserProfile copyWith({
    bool? completed,
    String? firstName,
    String? sex,
    DateTime? birthday,
    double? heightIn,
    double? startingWeightLb,
    double? currentWeightLb,
    double? goalWeightLb,
    String? primaryGoal,
    String? activityLevel,
  }) {
    return UserProfile(
      completed: completed ?? this.completed,
      firstName: firstName ?? this.firstName,
      sex: sex ?? this.sex,
      birthday: birthday ?? this.birthday,
      heightIn: heightIn ?? this.heightIn,
      startingWeightLb: startingWeightLb ?? this.startingWeightLb,
      currentWeightLb: currentWeightLb ?? this.currentWeightLb,
      goalWeightLb: goalWeightLb ?? this.goalWeightLb,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }
}
