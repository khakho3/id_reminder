import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../models/registered_id.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import 'registration_flow.dart';
import 'registration_success_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.registeredIds,
    required this.onRegisteredIdsChanged,
    required this.onIdRemoved,
    required this.onThemeModeChanged,
  });

  final List<RegisteredId> registeredIds;
  final ValueChanged<List<RegisteredId>> onRegisteredIdsChanged;
  final VoidCallback onIdRemoved;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _reminders = ReminderService();
  final _notifications = NotificationService.instance;
  ThemeMode _themeMode = ThemeMode.system;
  Future<PermissionStatus>? _notificationStatus;
  bool _exactAlarmRequested = false;
  bool _rescanning = false;
  bool _defaultVibrate = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _notificationStatus = _notifications.notificationPermissionStatus();
  }

  Future<void> _loadSettings() async {
    final saved = await _storage.getThemeMode();
    final defaultVibrate = await _storage.getDefaultVibrate();
    if (!mounted) return;
    setState(() {
      _themeMode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _defaultVibrate = defaultVibrate;
    });
  }

  Future<void> _setDefaultVibration(bool value) async {
    setState(() => _defaultVibrate = value);
    await _storage.saveDefaultVibrate(value);
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _storage.saveThemeMode(mode.name);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _requestNotifications() async {
    await _notifications.requestNotificationPermission();
    if (mounted) {
      setState(
        () =>
            _notificationStatus = _notifications.notificationPermissionStatus(),
      );
    }
  }

  Future<void> _requestExactAlarm() async {
    final granted = await _notifications.requestExactAlarmPermission();
    if (mounted) setState(() => _exactAlarmRequested = granted);
  }

  Future<void> _requestFullScreenIntent() async {
    await _notifications.requestFullScreenIntentPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review full-screen alarm access in Android settings.'),
      ),
    );
  }

  Future<void> _addId() async {
    if (_rescanning) return;
    setState(() => _rescanning = true);
    RegisteredId? updated;
    try {
      updated = await startIdRegistration(context);
    } finally {
      if (mounted) setState(() => _rescanning = false);
    }
    final registeredId = updated;
    if (registeredId == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegistrationSuccessScreen(registeredId: registeredId),
      ),
    );
    final registeredIds = await _storage.getRegisteredIds();
    if (mounted) widget.onRegisteredIdsChanged(registeredIds);
  }

  Future<void> _removeAllIds() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove all ID cards?'),
        content: const Text(
          'This removes every saved ID card. You will need to register a card again before verification can work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final reminders = await _reminders.getReminders();
    for (final reminder in reminders) {
      await _reminders.delete(reminder.id);
    }
    await _storage.removeRegisteredId();
    if (mounted) widget.onIdRemoved();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up the app the way you prefer.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        const _SettingsSection(label: 'GENERAL'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dark_mode_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Theme',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (value) => _setTheme(value.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const _SettingsSection(label: 'REMINDER'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: _defaultVibrate,
                onChanged: _setDefaultVibration,
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('Default vibration'),
                subtitle: const Text('Use this setting for new reminders'),
              ),
              const Divider(indent: 18, endIndent: 18),
              FutureBuilder<PermissionStatus>(
                future: _notificationStatus,
                builder: (context, snapshot) {
                  final granted = snapshot.data?.isGranted ?? false;
                  return ListTile(
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: granted ? AppColors.success : AppColors.warning,
                    ),
                    title: const Text('Notifications'),
                    subtitle: Text(granted ? 'Allowed' : 'Permission needed'),
                    trailing: TextButton(
                      onPressed: _requestNotifications,
                      child: Text(granted ? 'CHECK' : 'ALLOW'),
                    ),
                  );
                },
              ),
              const Divider(indent: 18, endIndent: 18),
              ListTile(
                leading: Icon(
                  Icons.alarm_on_rounded,
                  color: _exactAlarmRequested
                      ? AppColors.success
                      : AppColors.warning,
                ),
                title: const Text('Exact alarm access'),
                subtitle: Text(
                  _exactAlarmRequested
                      ? 'Allowed on this session'
                      : 'Review Alarms & reminders access',
                ),
                trailing: TextButton(
                  onPressed: _requestExactAlarm,
                  child: const Text('OPEN'),
                ),
              ),
              const Divider(indent: 18, endIndent: 18),
              ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('Full-screen alarm display'),
                subtitle: const Text(
                  'Allow Android to show alarms over the lock screen',
                ),
                trailing: TextButton(
                  onPressed: _requestFullScreenIntent,
                  child: const Text('OPEN'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _SettingsSection(label: 'ID'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Add another ID card'),
                subtitle: Text(
                  '${widget.registeredIds.length} saved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _rescanning ? null : _addId,
              ),
              const Divider(indent: 18, endIndent: 18),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text('Remove all ID cards'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _rescanning ? null : _removeAllIds,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _SettingsSection(label: 'ABOUT'),
        const SizedBox(height: 10),
        Card(
          child: const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('ID Reminder'),
            subtitle: Text('Verify your school ID before you go'),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );
}
