// lib/models/schedule_model.dart

/// Represents the Smart Scheduler configuration — a custom feature
/// (not on the original AC remote) that tells the ESP32 when to
/// automatically turn the AC on/off based on internet time.
class ScheduleModel {
  final bool onEnabled;
  final String onTime; // stored as "HH:mm", 24-hour format

  final bool offEnabled;
  final String offTime; // stored as "HH:mm", 24-hour format

  const ScheduleModel({
    required this.onEnabled,
    required this.onTime,
    required this.offEnabled,
    required this.offTime,
  });

  factory ScheduleModel.initial() {
    return const ScheduleModel(
      onEnabled: false,
      onTime: '06:00',
      offEnabled: false,
      offTime: '22:00',
    );
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> data) {
    return ScheduleModel(
      onEnabled: data['onEnabled'] ?? false,
      onTime: data['onTime'] ?? '06:00',
      offEnabled: data['offEnabled'] ?? false,
      offTime: data['offTime'] ?? '22:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'onEnabled': onEnabled,
      'onTime': onTime,
      'offEnabled': offEnabled,
      'offTime': offTime,
    };
  }

  ScheduleModel copyWith({
    bool? onEnabled,
    String? onTime,
    bool? offEnabled,
    String? offTime,
  }) {
    return ScheduleModel(
      onEnabled: onEnabled ?? this.onEnabled,
      onTime: onTime ?? this.onTime,
      offEnabled: offEnabled ?? this.offEnabled,
      offTime: offTime ?? this.offTime,
    );
  }
}