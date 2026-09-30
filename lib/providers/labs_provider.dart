import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bloodwork_result.dart';
import '../services/storage_service.dart';

class LabsNotifier extends Notifier<List<BloodworkResult>> {
  final _storage = StorageService();

  @override
  List<BloodworkResult> build() => ref.read(bootstrapDataProvider).labs;

  void add(BloodworkResult result) {
    state = [...state, result];
    unawaited(_storage.saveLabs(state));
  }

  void addAll(Iterable<BloodworkResult> results) {
    state = [...state, ...results];
    unawaited(_storage.saveLabs(state));
  }

  void update(BloodworkResult result) {
    state = [
      for (final item in state)
        if (item.id == result.id) result else item,
    ];
    unawaited(_storage.saveLabs(state));
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
    unawaited(_storage.saveLabs(state));
  }
}

final labsProvider =
    NotifierProvider<LabsNotifier, List<BloodworkResult>>(LabsNotifier.new);
