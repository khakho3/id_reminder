import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

enum ReminderScheduleResult { exact, inexactFallback, failed }

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'id_reminder_alarms';
  static const _channelName = 'ID reminders';
  static const _channelDescription =
      'Verification reminders for your school ID';
  static const _flagInsistent = 4;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<String?> activeReminderId = ValueNotifier<String?>(null);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // UTC is a safe fallback; the app will try the device time zone again on
      // the next launch rather than failing to schedule an alarm.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _openPayload(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<ReminderScheduleResult> schedule(Reminder reminder) async {
    await initialize();
    final scheduledDate = _asZoned(reminder.nextOccurrence());
    final details = _detailsFor(reminder);
    await cancel(reminder.id);
    try {
      await _plugin.zonedSchedule(
        id: _notificationId(reminder.id),
        title: 'Time to verify your ID',
        body: reminder.label,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        payload: _payloadFor(reminder.id),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return ReminderScheduleResult.exact;
    } catch (error, stackTrace) {
      debugPrint('Exact reminder scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await _plugin.zonedSchedule(
          id: _notificationId(reminder.id),
          title: 'Time to verify your ID',
          body: reminder.label,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          payload: _payloadFor(reminder.id),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return ReminderScheduleResult.inexactFallback;
      } catch (fallbackError, fallbackStackTrace) {
        debugPrint('Inexact reminder scheduling failed: $fallbackError');
        debugPrintStack(stackTrace: fallbackStackTrace);
        return ReminderScheduleResult.failed;
      }
    }
  }

  Future<void> cancel(String reminderId) async {
    await _plugin.cancel(id: _notificationId(reminderId));
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ??
          await Permission.notification.isGranted;
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return true;
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestExactAlarmsPermission() ?? false;
    } catch (error, stackTrace) {
      debugPrint('Exact alarm permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> requestFullScreenIntentPermission() async {
    if (kIsWeb) return true;
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestFullScreenIntentPermission() ?? false;
    } catch (error, stackTrace) {
      debugPrint('Full screen intent permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<PermissionStatus> notificationPermissionStatus() {
    return Permission.notification.status;
  }

  void clearActiveReminder() => activeReminderId.value = null;

  void _onNotificationResponse(NotificationResponse response) {
    _openPayload(response.payload);
  }

  void _openPayload(String? payload) {
    if (payload == null || !payload.startsWith('reminder:')) return;
    final id = payload.substring('reminder:'.length);
    if (id.isNotEmpty) activeReminderId.value = id;
  }

  NotificationDetails _detailsFor(Reminder reminder) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: false,
        enableVibration: reminder.vibrate,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        additionalFlags: Int32List.fromList([_flagInsistent]),
      ),
    );
  }

  tz.TZDateTime _asZoned(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  String _payloadFor(String reminderId) => 'reminder:$reminderId';

  int _notificationId(String reminderId) {
    var hash = 5381;
    for (final codeUnit in reminderId.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
    }
    return hash & 0x7fffffff;
  }
}
