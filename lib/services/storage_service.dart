import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/registered_id.dart';
import '../models/reminder.dart';

class StorageService {
  static const _registeredIdKey = 'registered_school_id';
  static const _registeredIdsKey = 'registered_school_ids';
  static const _remindersKey = 'id_reminders';
  static const _themeModeKey = 'theme_mode';
  static const _defaultVibrateKey = 'default_vibrate';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<RegisteredId?> getRegisteredId() async {
    final registeredIds = await getRegisteredIds();
    if (registeredIds.isNotEmpty) return registeredIds.first;
    return null;
  }

  Future<List<RegisteredId>> getRegisteredIds() async {
    final listValue = await _preferences.getString(_registeredIdsKey);
    if (listValue != null && listValue.isNotEmpty) {
      try {
        final decoded = jsonDecode(listValue);
        if (decoded is List<dynamic>) {
          final registeredIds = <RegisteredId>[];
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) continue;
            final registeredId = RegisteredId.fromJson(item);
            if (registeredId.schoolName.isEmpty ||
                registeredId.studentId.isEmpty) {
              continue;
            }
            registeredIds.add(registeredId);
          }
          registeredIds.sort(
            (first, second) =>
                first.registeredAt.compareTo(second.registeredAt),
          );
          if (registeredIds.isNotEmpty) return registeredIds;
        }
      } catch (_) {
        // Fall through to the legacy single-card key.
      }
    }

    final value = await _preferences.getString(_registeredIdKey);
    if (value == null || value.isEmpty) {
      return <RegisteredId>[];
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return <RegisteredId>[];
      }
      final registeredId = RegisteredId.fromJson(decoded);
      if (registeredId.schoolName.isEmpty || registeredId.studentId.isEmpty) {
        return <RegisteredId>[];
      }
      await saveRegisteredIds([registeredId]);
      return [registeredId];
    } catch (_) {
      return <RegisteredId>[];
    }
  }

  Future<void> saveRegisteredId(RegisteredId registeredId) async {
    final registeredIds = await getRegisteredIds();
    final index = registeredIds.indexWhere(
      (item) => item.id == registeredId.id,
    );
    if (index >= 0) {
      registeredIds[index] = registeredId;
    } else {
      registeredIds.add(registeredId);
    }
    await saveRegisteredIds(registeredIds);
  }

  Future<void> saveRegisteredIds(List<RegisteredId> registeredIds) async {
    await _preferences.setString(
      _registeredIdsKey,
      jsonEncode(registeredIds.map((id) => id.toJson()).toList()),
    );
    if (registeredIds.isNotEmpty) {
      await _preferences.setString(
        _registeredIdKey,
        jsonEncode(registeredIds.first.toJson()),
      );
    } else {
      await _preferences.remove(_registeredIdKey);
    }
  }

  Future<void> removeRegisteredId([String? id]) async {
    if (id == null) {
      await saveRegisteredIds(<RegisteredId>[]);
      return;
    }
    final registeredIds = await getRegisteredIds();
    registeredIds.removeWhere((item) => item.id == id);
    await saveRegisteredIds(registeredIds);
  }

  Future<List<Reminder>> getReminders() async {
    final value = await _preferences.getString(_remindersKey);
    if (value == null || value.isEmpty) return <Reminder>[];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List<dynamic>) return <Reminder>[];
      final reminders = <Reminder>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final reminder = Reminder.fromJson(item);
          if (reminder.id.isNotEmpty) reminders.add(reminder);
        } catch (_) {
          continue;
        }
      }
      reminders.sort(
        (first, second) =>
            first.nextOccurrence().compareTo(second.nextOccurrence()),
      );
      return reminders;
    } catch (_) {
      return <Reminder>[];
    }
  }

  Future<void> saveReminders(List<Reminder> reminders) {
    return _preferences.setString(
      _remindersKey,
      jsonEncode(reminders.map((reminder) => reminder.toJson()).toList()),
    );
  }

  Future<String> getThemeMode() async {
    return await _preferences.getString(_themeModeKey) ?? 'system';
  }

  Future<void> saveThemeMode(String mode) =>
      _preferences.setString(_themeModeKey, mode);

  Future<bool> getDefaultVibrate() async {
    return await _preferences.getBool(_defaultVibrateKey) ?? true;
  }

  Future<void> saveDefaultVibrate(bool value) =>
      _preferences.setBool(_defaultVibrateKey, value);
}
