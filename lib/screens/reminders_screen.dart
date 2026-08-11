import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    required this.dataVersion,
    required this.onEditReminder,
    required this.onChanged,
  });

  final int dataVersion;
  final ValueChanged<Reminder?> onEditReminder;
  final VoidCallback onChanged;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _reminderService = ReminderService();
  late Future<List<Reminder>> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = _reminderService.getReminders();
  }

  @override
  void didUpdateWidget(covariant RemindersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataVersion != widget.dataVersion) _load();
  }

  void _load() => setState(() => _reminders = _reminderService.getReminders());

  Future<void> _toggle(Reminder reminder, bool enabled) async {
    setState(() => _reminders = _reminderService.getReminders());
    await _reminderService.setEnabled(reminder, enabled);
    if (!mounted) return;
    _load();
    widget.onChanged();
  }

  Future<void> _delete(Reminder reminder) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        title: const Text('Delete reminder?'),
        content: Text(
          '“${reminder.label}” will be removed and its scheduled alarm will be cancelled.',
        ),
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
    if (shouldDelete != true) return;
    await _reminderService.delete(reminder.id);
    if (!mounted) return;
    _load();
    widget.onChanged();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reminder>>(
      future: _reminders,
      builder: (context, snapshot) {
        final reminders = snapshot.data ?? const <Reminder>[];
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => widget.onEditReminder(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add reminder'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              _load();
              await _reminders;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
              children: [
                Text(
                  'Reminders',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your scheduled ID checks.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (reminders.isEmpty)
                  _EmptyState(onCreate: () => widget.onEditReminder(null))
                else
                  ...reminders.map(
                    (reminder) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReminderCard(
                        reminder: reminder,
                        onTap: () => widget.onEditReminder(reminder),
                        onToggle: (enabled) => _toggle(reminder, enabled),
                        onEdit: () => widget.onEditReminder(reminder),
                        onDelete: () => _delete(reminder),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Reminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final next = reminder.nextOccurrence();
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(reminder.time);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const Spacer(),
                  Switch(value: reminder.isEnabled, onChanged: onToggle),
                  PopupMenuButton<String>(
                    tooltip: 'Reminder options',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                          ),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reminder.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                reminder.repeatSummary.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 14),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Next: ${_nextLabel(context, next)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!reminder.isEnabled) ...[
                    const Spacer(),
                    const Text(
                      'OFF',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.alarm_add_rounded, size: 44, color: AppColors.blue),
          const SizedBox(height: 16),
          Text(
            'No reminders yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            "Create your first ID reminder and we'll help make sure you don't leave your card behind.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('CREATE REMINDER'),
          ),
        ],
      ),
    ),
  );
}

String _nextLabel(BuildContext context, DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  final tomorrow = now.add(const Duration(days: 1));
  if (date.year == tomorrow.year &&
      date.month == tomorrow.month &&
      date.day == tomorrow.day) {
    return 'Tomorrow';
  }
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
