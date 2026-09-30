import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bloodwork_result.dart';

class LabsNotifier extends Notifier<List<BloodworkResult>> {
  @override
  List<BloodworkResult> build() => const [];

  void add(BloodworkResult result) {
    state = [...state, result];
  }

  void addAll(Iterable<BloodworkResult> results) {
    state = [...state, ...results];
  }

  void replaceAt(int index, BloodworkResult result) {
    final copy = [...state];
    copy[index] = result;
    state = copy;
  }

  void removeAt(int index) {
    final copy = [...state]..removeAt(index);
    state = copy;
  }
}

final labsProvider =
    NotifierProvider<LabsNotifier, List<BloodworkResult>>(LabsNotifier.new);
