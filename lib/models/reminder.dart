import 'package:flutter/material.dart';

class Reminder {
  const Reminder({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.isEnabled,
    required this.vibrate,
    required this.sound,
    required this.createdAt,
    this.registeredIdId,
  });

  final String id;
  final String label;
  final int hour;
  final int minute;

  /// ISO weekday values: Monday is 1 and Sunday is 7. An empty list means once.
  final List<int> repeatDays;
  final bool isEnabled;
  final bool vibrate;
  final String sound;
  final DateTime createdAt;
  final String? registeredIdId;

  bool get repeats => repeatDays.isNotEmpty;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  Reminder copyWith({
    String? label,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    bool? isEnabled,
    bool? vibrate,
    String? sound,
    String? registeredIdId,
  }) {
    return Reminder(
      id: id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      isEnabled: isEnabled ?? this.isEnabled,
      vibrate: vibrate ?? this.vibrate,
      sound: sound ?? this.sound,
      createdAt: createdAt,
      registeredIdId: registeredIdId ?? this.registeredIdId,
    );
  }

  DateTime nextOccurrence([DateTime? after]) {
    final reference = after ?? DateTime.now();
    for (var offset = 0; offset <= 8; offset++) {
      final day = DateTime(
        reference.year,
        reference.month,
        reference.day + offset,
      );
      final candidate = DateTime(day.year, day.month, day.day, hour, minute);
      if (!candidate.isAfter(reference)) continue;
      if (!repeats || repeatDays.contains(candidate.weekday)) return candidate;
    }
    // A validated repeating reminder always returns from the loop. This keeps
    // the method safe if malformed persisted data is encountered.
    return DateTime(
      reference.year,
      reference.month,
      reference.day + 1,
      hour,
      minute,
    );
  }

  String get repeatSummary {
    if (repeatDays.isEmpty) return 'Once';
    if (_sameDays(repeatDays, const [1, 2, 3, 4, 5])) return 'Weekdays';
    if (_sameDays(repeatDays, const [1, 2, 3, 4, 5, 6, 7])) return 'Every day';
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return repeatDays.map((day) => labels[day - 1]).join('  ');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'hour': hour,
    'minute': minute,
    'repeatDays': repeatDays,
    'isEnabled': isEnabled,
    'vibrate': vibrate,
    'sound': sound,
    'createdAt': createdAt.toIso8601String(),
    'registeredIdId': registeredIdId,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final days =
        (json['repeatDays'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<num>()
            .map((value) => value.toInt())
            .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
            .toSet()
            .toList()
          ..sort();
    return Reminder(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Remember your school ID',
      hour: (json['hour'] as num?)?.toInt().clamp(0, 23) ?? 6,
      minute: (json['minute'] as num?)?.toInt().clamp(0, 59) ?? 30,
      repeatDays: days,
      isEnabled: json['isEnabled'] as bool? ?? true,
      vibrate: json['vibrate'] as bool? ?? true,
      sound: json['sound'] as String? ?? 'Default Alarm',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      registeredIdId: json['registeredIdId'] as String?,
    );
  }

  static bool _sameDays(List<int> first, List<int> second) {
    return first.length == second.length && first.every(second.contains);
  }
}
