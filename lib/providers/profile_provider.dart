import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => const UserProfile();

  void setBirthday(DateTime value) {
    state = state.copyWith(birthday: value);
  }

  void setSex(String value) {
    state = state.copyWith(sex: value);
  }

  void setWeights({double? current, double? goal}) {
    state = UserProfile(
      birthday: state.birthday,
      sex: state.sex,
      currentWeightLb: current ?? state.currentWeightLb,
      goalWeightLb: goal ?? state.goalWeightLb,
    );
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
