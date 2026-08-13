import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/registered_id.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.registeredIds,
    required this.dataVersion,
    required this.onCreateReminder,
    required this.onViewId,
    required this.onAddFirstCard,
  });

  final List<RegisteredId> registeredIds;
  final int dataVersion;
  final VoidCallback onCreateReminder;
  final VoidCallback onViewId;
  final VoidCallback onAddFirstCard;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _reminderService = ReminderService();
  late Future<List<Reminder>> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = _reminderService.getReminders();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataVersion != widget.dataVersion) {
      _reminders = _reminderService.getReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reminder>>(
      future: _reminders,
      builder: (context, snapshot) {
        final reminders =
            (snapshot.data ?? const <Reminder>[])
                .where((reminder) => reminder.isEnabled)
                .toList()
              ..sort(
                (first, second) =>
                    first.nextOccurrence().compareTo(second.nextOccurrence()),
              );
        final hasCards = widget.registeredIds.isNotEmpty;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _reminders = _reminderService.getReminders());
            await _reminders;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
            children: [
              _DashboardHeader(hasCards: hasCards),
              const SizedBox(height: 28),
              if (!hasCards) ...[
                _FirstRunCard(onAddFirstCard: widget.onAddFirstCard),
                const SizedBox(height: 18),
                const _PrivacyNote(),
              ] else ...[
                const _SectionLabel(label: 'YOUR ID CARDS'),
                const SizedBox(height: 10),
                _IdStatusCard(
                  registeredIds: widget.registeredIds,
                  onTap: widget.onViewId,
                ),
                const SizedBox(height: 28),
                const _SectionLabel(label: 'NEXT REMINDER'),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (reminders.isNotEmpty)
                  _NextReminderCard(reminder: reminders.first)
                else
                  _EmptyReminderCard(onCreate: widget.onCreateReminder),
                if (reminders.length > 1) ...[
                  const SizedBox(height: 28),
                  const _SectionLabel(label: 'UPCOMING REMINDERS'),
                  const SizedBox(height: 10),
                  ...reminders
                      .skip(1)
                      .take(3)
                      .map(
                        (reminder) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UpcomingReminderTile(reminder: reminder),
                        ),
                      ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.hasCards});

  final bool hasCards;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasCards
              ? 'Your cards and reminders are ready when you are.'
              : 'Start by adding the card you want to remember.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

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

class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard({required this.onAddFirstCard});

  final VoidCallback onAddFirstCard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        child: Column(
          children: [
            Container(
              width: 86,
              height: 86,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your space is ready',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an ID card to create reminders and verify it when an alarm goes off.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddFirstCard,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('ADD YOUR FIRST CARD'),
              ),
            ),
            const SizedBox(height: 22),
            const _SetupSteps(),
          ],
        ),
      ),
    );
  }
}

class _SetupSteps extends StatelessWidget {
  const _SetupSteps();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    const steps = [
      (Icons.document_scanner_outlined, 'Add a card'),
      (Icons.alarm_add_rounded, 'Set a reminder'),
      (Icons.verified_outlined, 'Verify when ready'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 3;
        return Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              SizedBox(
                width: itemWidth,
                child: Column(
                  children: [
                    Icon(steps[index].$1, size: 20, color: color),
                    const SizedBox(height: 7),
                    Text(
                      steps[index].$2,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (index != steps.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your card details are stored only on this device.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IdStatusCard extends StatelessWidget {
  const _IdStatusCard({required this.registeredIds, required this.onTap});

  final List<RegisteredId> registeredIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryId = registeredIds.first;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      registeredIds.length == 1
                          ? '1 card registered'
                          : '${registeredIds.length} cards registered',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _InfoText(label: 'Primary card', value: primaryId.displayName),
              const SizedBox(height: 16),
              _InfoText(label: 'School', value: primaryId.schoolName),
              if (primaryId.hasNfc) ...[
                const SizedBox(height: 16),
                const _InfoText(label: 'NFC', value: 'Linked'),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Manage cards'),
                  style: TextButton.styleFrom(foregroundColor: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _NextReminderCard extends StatelessWidget {
  const _NextReminderCard({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final next = reminder.nextOccurrence();
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(reminder.time);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateLabel = _sameDay(next, DateTime.now())
        ? 'Today'
        : _sameDay(next, tomorrow)
        ? 'Tomorrow'
        : localizations.formatMediumDate(next);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onPrimary.withValues(alpha: .74),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reminder.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            reminder.repeatSummary.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: .78),
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingReminderTile extends StatelessWidget {
  const _UpcomingReminderTile({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.alarm_rounded, color: AppColors.blue),
      ),
      title: Text(
        reminder.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('Next: ${_shortDay(reminder.nextOccurrence())}'),
      trailing: Text(
        MaterialLocalizations.of(context).formatTimeOfDay(reminder.time),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_alarm_rounded,
              color: AppColors.blue,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first reminder and we will help make sure you do not leave your card behind.',
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

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _shortDay(DateTime date) {
  if (_sameDay(date, DateTime.now())) {
    return 'Today';
  }
  if (_sameDay(date, DateTime.now().add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}
