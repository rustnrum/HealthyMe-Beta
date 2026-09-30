import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_data.dart';
import '../services/storage_service.dart';

class HealthDataNotifier extends Notifier<HealthDataState> {
  final _storage = StorageService();

  @override
  HealthDataState build() => ref.read(bootstrapDataProvider).healthData;

  void seedWeight(double weightLb) {
    if (state.weightHistory.isNotEmpty) return;
    state = state.copyWith(
      weightHistory: [
        WeightEntry(date: DateTime.now(), weightLb: weightLb),
      ],
    );
    unawaited(_storage.saveHealthData(state));
  }

  void addWeight(double weightLb) {
    final next = [...state.weightHistory];
    final now = DateTime.now();

    if (next.isNotEmpty) {
      final last = next.last;
      final sameDay = last.date.year == now.year &&
          last.date.month == now.month &&
          last.date.day == now.day;
      if (sameDay) {
        next[next.length - 1] = WeightEntry(date: now, weightLb: weightLb);
      } else {
        next.add(WeightEntry(date: now, weightLb: weightLb));
      }
    } else {
      next.add(WeightEntry(date: now, weightLb: weightLb));
    }

    state = state.copyWith(weightHistory: next);
    unawaited(_storage.saveHealthData(state));
  }

  void updateMeasurements(BodyMeasurements measurements) {
    state = state.copyWith(measurements: measurements);
    unawaited(_storage.saveHealthData(state));
  }
}

final healthDataProvider =
    NotifierProvider<HealthDataNotifier, HealthDataState>(
  HealthDataNotifier.new,
);
