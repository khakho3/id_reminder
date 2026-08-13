import 'package:flutter/material.dart';

import '../models/registered_id.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import 'alarm_gate_screen.dart';
import 'create_reminder_screen.dart';
import 'home_screen.dart';
import 'id_card_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.registeredIds,
    required this.onIdRemoved,
    required this.onThemeModeChanged,
  });

  final List<RegisteredId> registeredIds;
  final VoidCallback onIdRemoved;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _reminderService = ReminderService();
  late List<RegisteredId> _registeredIds;
  int _selectedIndex = 0;
  int _dataVersion = 0;
  String? _presentedAlarmId;

  @override
  void initState() {
    super.initState();
    _registeredIds = [...widget.registeredIds];
    NotificationService.instance.activeReminderId.addListener(_showActiveAlarm);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reminderService.syncEnabledReminders();
      _showActiveAlarm();
    });
  }

  @override
  void dispose() {
    NotificationService.instance.activeReminderId.removeListener(
      _showActiveAlarm,
    );
    super.dispose();
  }

  Future<void> _showActiveAlarm() async {
    final reminderId = NotificationService.instance.activeReminderId.value;
    if (!mounted || reminderId == null || reminderId == _presentedAlarmId) {
      return;
    }
    final reminders = await _reminderService.getReminders();
    final reminder = reminders
        .where((item) => item.id == reminderId)
        .firstOrNull;
    if (reminder == null || !mounted) {
      NotificationService.instance.clearActiveReminder();
      return;
    }
    final registeredId = _registeredIdForReminder(reminder);
    if (registeredId == null) {
      NotificationService.instance.clearActiveReminder();
      return;
    }
    _presentedAlarmId = reminderId;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlarmGateScreen(
          reminder: reminder,
          registeredId: registeredId,
          onCompleted: _refresh,
        ),
      ),
    );
    _presentedAlarmId = null;
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    final registeredIds = await StorageService().getRegisteredIds();
    if (!mounted) return;
    setState(() {
      _registeredIds = registeredIds;
      _dataVersion++;
    });
  }

  Future<void> _openEditor([Reminder? reminder]) async {
    if (_registeredIds.isEmpty) {
      setState(() => _selectedIndex = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an ID card before creating a reminder.'),
        ),
      );
      return;
    }
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateReminderScreen(
          reminder: reminder,
          registeredIds: _registeredIds,
        ),
      ),
    );
    if (didSave == true && mounted) _refresh();
  }

  void _updateRegisteredIds(List<RegisteredId> registeredIds) {
    setState(() {
      _registeredIds = registeredIds;
      _dataVersion++;
    });
  }

  void _openCards() {
    if (_selectedIndex != 2) {
      setState(() => _selectedIndex = 2);
    }
  }

  RegisteredId? _registeredIdForReminder(Reminder reminder) {
    if (_registeredIds.isEmpty) return null;
    final reminderCardId = reminder.registeredIdId;
    if (reminderCardId == null) return _registeredIds.first;
    return _registeredIds
        .where((item) => item.id == reminderCardId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_selectedIndex) {
      0 => HomeScreen(
        registeredIds: _registeredIds,
        dataVersion: _dataVersion,
        onCreateReminder: _openEditor,
        onViewId: _openCards,
        onAddFirstCard: _openCards,
      ),
      1 => RemindersScreen(
        dataVersion: _dataVersion,
        hasRegisteredIds: _registeredIds.isNotEmpty,
        onEditReminder: _openEditor,
        onChanged: _refresh,
        onAddIdCard: _openCards,
      ),
      2 => IdCardScreen(
        registeredIds: _registeredIds,
        onRegisteredIdsChanged: _updateRegisteredIds,
        onIdRemoved: widget.onIdRemoved,
      ),
      _ => SettingsScreen(
        registeredIds: _registeredIds,
        onRegisteredIdsChanged: _updateRegisteredIds,
        onIdRemoved: widget.onIdRemoved,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    };

    return Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => _selectedIndex = value),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.alarm_rounded),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_rounded),
            label: 'ID Card',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
