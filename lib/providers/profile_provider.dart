import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileNotifier extends Notifier<UserProfile> {
  final _storage = StorageService();

  @override
  UserProfile build() => ref.read(bootstrapDataProvider).profile;

  void complete(UserProfile profile) {
    state = profile.copyWith(completed: true);
    unawaited(_storage.saveProfile(state));
  }

  void update(UserProfile profile) {
    state = profile;
    unawaited(_storage.saveProfile(state));
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
