import 'package:flutter/material.dart';

import '../models/registered_id.dart';
import 'registration_flow.dart';
import 'registration_success_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onRegistered, this.onThemeModeChanged});

  final VoidCallback? onRegistered;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _registrationInProgress = false;

  Future<void> _registerId() async {
    if (_registrationInProgress) return;
    setState(() => _registrationInProgress = true);

    RegisteredId? registeredId;
    try {
      registeredId = await startIdRegistration(context);
    } finally {
      if (mounted) {
        setState(() => _registrationInProgress = false);
      }
    }
    if (registeredId == null || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegistrationSuccessScreen(registeredId: registeredId!),
      ),
    );
    if (!mounted) return;
    widget.onRegistered?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'ID Reminder',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Register your school ID so we can verify that you have it when your reminders activate.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _registrationInProgress ? null : _registerId,
                      icon: _registrationInProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner_outlined),
                      label: const Text('REGISTER MY ID'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Your ID details stay on this device',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
