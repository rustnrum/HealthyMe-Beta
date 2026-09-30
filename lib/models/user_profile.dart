class UserProfile {
  final DateTime? birthday;
  final String sex;
  final double? currentWeightLb;
  final double? goalWeightLb;

  const UserProfile({
    this.birthday,
    this.sex = 'Male',
    this.currentWeightLb,
    this.goalWeightLb,
  });

  UserProfile copyWith({
    DateTime? birthday,
    String? sex,
    double? currentWeightLb,
    double? goalWeightLb,
    bool clearBirthday = false,
  }) {
    return UserProfile(
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      sex: sex ?? this.sex,
      currentWeightLb: currentWeightLb ?? this.currentWeightLb,
      goalWeightLb: goalWeightLb ?? this.goalWeightLb,
    );
  }
}
