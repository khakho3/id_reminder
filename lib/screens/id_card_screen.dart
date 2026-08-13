import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/registered_id.dart';
import '../services/nfc_card_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import 'registration_flow.dart';
import 'registration_success_screen.dart';

class IdCardScreen extends StatefulWidget {
  const IdCardScreen({
    super.key,
    required this.registeredIds,
    required this.onRegisteredIdsChanged,
    required this.onIdRemoved,
  });

  final List<RegisteredId> registeredIds;
  final ValueChanged<List<RegisteredId>> onRegisteredIdsChanged;
  final VoidCallback onIdRemoved;

  @override
  State<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends State<IdCardScreen> {
  final _storage = StorageService();
  final _reminders = ReminderService();
  final _nfc = const NfcCardService();
  bool _working = false;
  String? _scanningCardId;

  Future<void> _addCard() async {
    if (_working) return;
    setState(() => _working = true);
    RegisteredId? registeredId;
    try {
      registeredId = await startIdRegistration(context);
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (registeredId == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegistrationSuccessScreen(registeredId: registeredId!),
      ),
    );
    await _reloadCards();
  }

  Future<void> _addNfcCard() async {
    if (_working) return;
    setState(() => _working = true);
    NfcScanResult result;
    try {
      result = await _nfc.scan();
    } on NfcScanFailure catch (failure) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_nfcFailureMessage(failure.reason))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _working = false);
    final duplicate = widget.registeredIds.any(
      (item) => item.nfcTagId == result.tagId,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That NFC card is already saved.')),
      );
      return;
    }
    final registeredId = await _showNfcCardDetailsDialog(result.tagId);
    if (registeredId == null) return;
    await _storage.saveRegisteredId(registeredId);
    await _reloadCards();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('NFC card added.')));
  }

  Future<void> _linkNfc(RegisteredId registeredId) async {
    if (_working) return;
    setState(() {
      _working = true;
      _scanningCardId = registeredId.id;
    });
    NfcScanResult result;
    try {
      result = await _nfc.scan();
    } on NfcScanFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _scanningCardId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_nfcFailureMessage(failure.reason))),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _scanningCardId = null;
    });
    final duplicate = widget.registeredIds.any(
      (item) => item.id != registeredId.id && item.nfcTagId == result.tagId,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That NFC card is already linked.')),
      );
      return;
    }
    await _storage.saveRegisteredId(
      registeredId.copyWith(nfcTagId: result.tagId),
    );
    await _reloadCards();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('NFC card linked.')));
  }

  Future<void> _deleteCard(RegisteredId registeredId) async {
    final isLast = widget.registeredIds.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        title: Text('Delete ${registeredId.displayName}?'),
        content: Text(
          isLast
              ? 'This removes your last ID card and all reminders that use it.'
              : 'This removes the card and reminders that use it.',
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
    if (confirmed != true) return;

    final defaultCardId = widget.registeredIds.first.id;
    final reminders = await _reminders.getReminders();
    for (final reminder in reminders) {
      final belongsToCard =
          reminder.registeredIdId == registeredId.id ||
          (reminder.registeredIdId == null && registeredId.id == defaultCardId);
      if (belongsToCard) await _reminders.delete(reminder.id);
    }
    await _storage.removeRegisteredId(registeredId.id);

    final cards = await _storage.getRegisteredIds();
    if (!mounted) return;
    if (cards.isEmpty) {
      widget.onRegisteredIdsChanged(cards);
      widget.onIdRemoved();
      return;
    }
    widget.onRegisteredIdsChanged(cards);
  }

  Future<void> _reloadCards() async {
    final cards = await _storage.getRegisteredIds();
    if (mounted) widget.onRegisteredIdsChanged(cards);
  }

  Future<RegisteredId?> _showNfcCardDetailsDialog(String tagId) async {
    final nameController = TextEditingController(text: 'NFC card');
    final schoolController = TextEditingController(text: 'NFC');
    try {
      return showDialog<RegisteredId>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.nfc_rounded),
          title: const Text('Name this NFC card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Card name',
                  hintText: 'Wallet card, office card, bus card...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: schoolController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group / school (optional)',
                  hintText: 'School, Office, Transport...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  context,
                  RegisteredId(
                    id: RegisteredId.newId(),
                    schoolName: schoolController.text.trim().isEmpty
                        ? 'NFC'
                        : schoolController.text.trim(),
                    studentId: 'NFC-${tagId.substring(tagId.length - 6)}',
                    studentName: name,
                    registeredAt: DateTime.now(),
                    nfcTagId: tagId,
                  ),
                );
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      schoolController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCards = widget.registeredIds.isNotEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ID Cards',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
            ),
            if (hasCards)
              IconButton.filled(
                tooltip: 'Add ID card',
                onPressed: _working ? null : _addCard,
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasCards
              ? 'Scan OCR cards, link NFC cards, and choose which card each reminder verifies.'
              : 'Add an OCR or NFC card to begin using ID Reminder.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (!hasCards)
          _EmptyIdCardsState(
            working: _working,
            onScanId: _addCard,
            onAddNfc: _addNfcCard,
          )
        else ...[
          ...widget.registeredIds.map(
            (registeredId) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _IdCardTile(
                registeredId: registeredId,
                isPrimary: registeredId.id == widget.registeredIds.first.id,
                isScanningNfc: _scanningCardId == registeredId.id,
                onLinkNfc: () => _linkNfc(registeredId),
                onDelete: () => _deleteCard(registeredId),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _working ? null : _addCard,
            icon: _working
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_rounded),
            label: const Text('ADD ANOTHER ID CARD'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _working ? null : _addNfcCard,
            icon: _working
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.nfc_rounded),
            label: Text(_working ? 'HOLD CARD NEAR PHONE' : 'ADD NFC CARD'),
          ),
        ],
      ],
    );
  }
}

class _EmptyIdCardsState extends StatelessWidget {
  const _EmptyIdCardsState({
    required this.working,
    required this.onScanId,
    required this.onAddNfc,
  });

  final bool working;
  final VoidCallback onScanId;
  final VoidCallback onAddNfc;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.badge_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No ID cards yet',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a school or work ID with your camera, or add an NFC card directly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: working ? null : onScanId,
              icon: working
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_rounded),
              label: const Text('SCAN ID CARD'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: working ? null : onAddNfc,
              icon: const Icon(Icons.nfc_rounded),
              label: Text(working ? 'HOLD CARD NEAR PHONE' : 'ADD NFC CARD'),
            ),
          ),
        ],
      ),
    ),
  );
}

String _nfcFailureMessage(NfcScanFailureReason reason) {
  return switch (reason) {
    NfcScanFailureReason.unavailable =>
      'NFC is off or not available. Turn NFC on in Android Settings.',
    NfcScanFailureReason.timeout =>
      'No NFC card was read. Hold the card flat against the upper back of the phone.',
    NfcScanFailureReason.failed =>
      'NFC read failed. Move the card slowly around the back of the phone and try again.',
  };
}

class _IdCardTile extends StatelessWidget {
  const _IdCardTile({
    required this.registeredId,
    required this.isPrimary,
    required this.isScanningNfc,
    required this.onLinkNfc,
    required this.onDelete,
  });

  final RegisteredId registeredId;
  final bool isPrimary;
  final bool isScanningNfc;
  final VoidCallback onLinkNfc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.badge_rounded, color: AppColors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registeredId.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        registeredId.schoolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete card')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPrimary) const _StatusChip(label: 'Primary'),
                _StatusChip(
                  label: registeredId.hasNfc ? 'NFC linked' : 'OCR only',
                ),
                _StatusChip(label: _maskedId(registeredId.studentId)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isScanningNfc ? null : onLinkNfc,
              icon: isScanningNfc
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.nfc_rounded),
              label: Text(
                registeredId.hasNfc ? 'REPLACE NFC CARD' : 'LINK NFC CARD',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
}

String _maskedId(String value) {
  if (value.length <= 4) return value;
  return '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
}
