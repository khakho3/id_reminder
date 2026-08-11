import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/registered_id.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';

enum _RepeatPreset { once, weekdays, everyDay, custom }

class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({
    super.key,
    this.reminder,
    required this.registeredIds,
  });

  final Reminder? reminder;
  final List<RegisteredId> registeredIds;

  bool get isEditing => reminder != null;

  @override
  State<CreateReminderScreen> createState() => _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reminderService = ReminderService();
  final _notifications = NotificationService.instance;
  late final TextEditingController _labelController;
  late TimeOfDay _time;
  late Set<int> _repeatDays;
  late _RepeatPreset _repeatPreset;
  late bool _vibrate;
  late bool _enabled;
  late String _selectedRegisteredIdId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _labelController = TextEditingController(
      text: reminder?.label ?? 'Remember your school ID',
    );
    _time = reminder?.time ?? const TimeOfDay(hour: 6, minute: 30);
    _repeatDays = {...?reminder?.repeatDays};
    _repeatPreset = _presetFor(_repeatDays);
    _vibrate = reminder?.vibrate ?? true;
    _enabled = reminder?.isEnabled ?? true;
    _selectedRegisteredIdId =
        reminder?.registeredIdId ?? widget.registeredIds.first.id;
    if (reminder == null) _loadDefaultVibration();
  }

  Future<void> _loadDefaultVibration() async {
    final defaultVibration = await StorageService().getDefaultVibrate();
    if (mounted) setState(() => _vibrate = defaultVibration);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  void _setRepeatPreset(_RepeatPreset preset) {
    setState(() {
      _repeatPreset = preset;
      switch (preset) {
        case _RepeatPreset.once:
          _repeatDays = {};
        case _RepeatPreset.weekdays:
          _repeatDays = {1, 2, 3, 4, 5};
        case _RepeatPreset.everyDay:
          _repeatDays = {1, 2, 3, 4, 5, 6, 7};
        case _RepeatPreset.custom:
          if (_repeatDays.isEmpty) _repeatDays = {1, 2, 3, 4, 5};
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final existing = widget.reminder;
    final reminder = Reminder(
      id: existing?.id ?? 'reminder_${DateTime.now().microsecondsSinceEpoch}',
      label: _labelController.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      repeatDays: _repeatDays.toList()..sort(),
      isEnabled: _enabled,
      vibrate: _vibrate,
      sound: 'Default Alarm',
      createdAt: existing?.createdAt ?? DateTime.now(),
      registeredIdId: _selectedRegisteredIdId,
    );

    try {
      final messenger = ScaffoldMessenger.of(context);
      var notificationAllowed = true;
      var exactAlarmAllowed = true;
      var fullScreenAllowed = true;
      if (_enabled) {
        notificationAllowed = await _notifications
            .requestNotificationPermission();
        exactAlarmAllowed = await _notifications.requestExactAlarmPermission();
        fullScreenAllowed = await _notifications
            .requestFullScreenIntentPermission();
      }
      final result = await _reminderService.save(reminder);
      if (!mounted) return;
      final time = MaterialLocalizations.of(context).formatTimeOfDay(_time);
      Navigator.of(context).pop(true);
      final message = !notificationAllowed
          ? 'Reminder saved. Allow notifications in Settings to receive it.'
          : !fullScreenAllowed
          ? 'Reminder saved. Allow full-screen alarms so it opens automatically.'
          : result == ReminderScheduleResult.inexactFallback
          ? exactAlarmAllowed
                ? 'Reminder set for $time. Timing may vary slightly.'
                : 'Reminder set for $time. Allow exact alarms for precise timing.'
          : result == ReminderScheduleResult.failed
          ? 'Reminder saved, but Android blocked alarm scheduling. Check Settings.'
          : 'Reminder set for $time. It will open the ID check when allowed.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      debugPrint('Reminder save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this reminder. Please try again.'),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final reminder = widget.reminder;
    if (reminder == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        title: const Text('Delete reminder?'),
        content: const Text('This will cancel the scheduled ID reminder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _reminderService.delete(reminder.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(_time);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Reminder' : 'New Reminder'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _SectionTitle(title: 'TIME'),
              const SizedBox(height: 10),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            time,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                          ),
                        ),
                        const Icon(Icons.edit_outlined),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle(title: 'REPEAT'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'Once',
                    selected: _repeatPreset == _RepeatPreset.once,
                    onSelected: () => _setRepeatPreset(_RepeatPreset.once),
                  ),
                  _PresetChip(
                    label: 'Weekdays',
                    selected: _repeatPreset == _RepeatPreset.weekdays,
                    onSelected: () => _setRepeatPreset(_RepeatPreset.weekdays),
                  ),
                  _PresetChip(
                    label: 'Every day',
                    selected: _repeatPreset == _RepeatPreset.everyDay,
                    onSelected: () => _setRepeatPreset(_RepeatPreset.everyDay),
                  ),
                  _PresetChip(
                    label: 'Custom',
                    selected: _repeatPreset == _RepeatPreset.custom,
                    onSelected: () => _setRepeatPreset(_RepeatPreset.custom),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final day = index + 1;
                  final isSelected = _repeatDays.contains(day);
                  return Semantics(
                    label: 'Repeat ${labels[index]}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _repeatPreset = _RepeatPreset.custom;
                          if (isSelected) {
                            _repeatDays.remove(day);
                          } else {
                            _repeatDays.add(day);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              _SectionTitle(title: 'REMINDER NAME'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _labelController,
                maxLength: 60,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  hintText: 'Remember your school ID',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a reminder name.'
                    : null,
              ),
              const SizedBox(height: 22),
              _SectionTitle(title: 'ID CARD'),
              const SizedBox(height: 10),
              Card(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRegisteredIdId,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: widget.registeredIds
                      .map(
                        (registeredId) => DropdownMenuItem(
                          value: registeredId.id,
                          child: Text(
                            '${registeredId.displayName} - ${registeredId.schoolName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRegisteredIdId = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(title: 'ALARM'),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.volume_up_outlined),
                      title: Text('Sound'),
                      subtitle: Text('Default Alarm'),
                    ),
                    const Divider(indent: 18, endIndent: 18),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_rounded),
                      title: const Text('Vibrate'),
                      subtitle: const Text(
                        'Vibrate when the reminder activates',
                      ),
                      value: _vibrate,
                      onChanged: (value) => setState(() => _vibrate = value),
                    ),
                    const Divider(indent: 18, endIndent: 18),
                    SwitchListTile(
                      secondary: const Icon(Icons.alarm_on_rounded),
                      title: const Text('Reminder enabled'),
                      subtitle: const Text('Schedule this reminder now'),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'For the most reliable timing, allow “Alarms & reminders” access in Settings after saving.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  widget.isEditing ? 'SAVE CHANGES' : 'SAVE REMINDER',
                ),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('DELETE REMINDER'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}

_RepeatPreset _presetFor(Set<int> days) {
  if (days.isEmpty) {
    return _RepeatPreset.once;
  }
  if (days.length == 5 && days.every((day) => day <= 5)) {
    return _RepeatPreset.weekdays;
  }
  if (days.length == 7) {
    return _RepeatPreset.everyDay;
  }
  return _RepeatPreset.custom;
}
