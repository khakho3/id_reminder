import 'package:flutter/material.dart';

import '../models/id_scan_result.dart';
import '../models/registered_id.dart';
import '../services/storage_service.dart';

class IdReviewOutcome {
  const IdReviewOutcome.scanAgain() : scanAgain = true, registeredId = null;

  const IdReviewOutcome.registered(this.registeredId) : scanAgain = false;

  final bool scanAgain;
  final RegisteredId? registeredId;
}

class IdReviewScreen extends StatefulWidget {
  const IdReviewScreen({super.key, required this.scanResult});

  final IdScanResult scanResult;

  @override
  State<IdReviewScreen> createState() => _IdReviewScreenState();
}

class _IdReviewScreenState extends State<IdReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  late final TextEditingController _schoolController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _studentNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _schoolController = TextEditingController(
      text: widget.scanResult.schoolName,
    );
    _studentIdController = TextEditingController(
      text: widget.scanResult.studentId,
    );
    _studentNameController = TextEditingController(
      text: widget.scanResult.studentName,
    );
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _studentIdController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }
    setState(() => _isSaving = true);

    final registeredId = RegisteredId(
      id: RegisteredId.newId(),
      schoolName: _schoolController.text.trim(),
      studentId: _studentIdController.text.trim(),
      studentName: _studentNameController.text.trim(),
      registeredAt: DateTime.now(),
    );

    try {
      await _storageService.saveRegisteredId(registeredId);
      if (mounted) {
        Navigator.pop(context, IdReviewOutcome.registered(registeredId));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your ID. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHECK YOUR DETAILS')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            children: [
              Text(
                'Review what was read from your card',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OCR can make mistakes. Correct any field before registering.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _schoolController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Student Name (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: const Text('Recognized text'),
                  subtitle: const Text('Useful when checking OCR results'),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.scanResult.rawText.isEmpty
                          ? 'No text was returned.'
                          : widget.scanResult.rawText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _confirm,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('CONFIRM & REGISTER'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(
                          context,
                          const IdReviewOutcome.scanAgain(),
                        ),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('SCAN AGAIN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }
}
