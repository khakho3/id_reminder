import 'package:flutter/foundation.dart';

import '../models/reminder.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class ReminderService {
  ReminderService({StorageService? storage, NotificationService? notifications})
    : _storage = storage ?? StorageService(),
      _notifications = notifications ?? NotificationService.instance;

  final StorageService _storage;
  final NotificationService _notifications;

  Future<List<Reminder>> getReminders() => _storage.getReminders();

  Future<ReminderScheduleResult?> save(Reminder reminder) async {
    final reminders = await _storage.getReminders();
    final index = reminders.indexWhere((item) => item.id == reminder.id);
    if (index >= 0) {
      reminders[index] = reminder;
    } else {
      reminders.add(reminder);
    }
    await _storage.saveReminders(reminders);
    try {
      await _notifications.cancel(reminder.id);
    } catch (error, stackTrace) {
      debugPrint('Reminder cancel failed after save: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!reminder.isEnabled) return null;
    try {
      return await _notifications.schedule(reminder);
    } catch (error, stackTrace) {
      debugPrint('Reminder schedule failed after save: $error');
      debugPrintStack(stackTrace: stackTrace);
      return ReminderScheduleResult.failed;
    }
  }

  Future<void> delete(String reminderId) async {
    final reminders = await _storage.getReminders();
    reminders.removeWhere((reminder) => reminder.id == reminderId);
    await _storage.saveReminders(reminders);
    await _notifications.cancel(reminderId);
  }

  Future<ReminderScheduleResult?> setEnabled(Reminder reminder, bool enabled) {
    return save(reminder.copyWith(isEnabled: enabled));
  }

  Future<void> complete(Reminder reminder) async {
    await _notifications.cancel(reminder.id);
    final updated = reminder.repeats
        ? reminder
        : reminder.copyWith(isEnabled: false);
    await save(updated);
  }

  Future<void> syncEnabledReminders() async {
    final reminders = await _storage.getReminders();
    for (final reminder in reminders.where((item) => item.isEnabled)) {
      await _notifications.schedule(reminder);
    }
  }
}
