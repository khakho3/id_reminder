import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'models/registered_id.dart';
import 'screens/main_shell.dart';
import 'services/storage_service.dart';

class IdReminderApp extends StatefulWidget {
  const IdReminderApp({super.key});

  @override
  State<IdReminderApp> createState() => _IdReminderAppState();
}

class _IdReminderAppState extends State<IdReminderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await StorageService().getThemeMode();
    if (!mounted) return;
    setState(() {
      _themeMode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ID Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _StartupScreen(
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen({required this.onThemeModeChanged});

  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  late Future<List<RegisteredId>> _registeredIds;

  @override
  void initState() {
    super.initState();
    _registeredIds = StorageService().getRegisteredIds();
  }

  void _reloadRegistration() {
    setState(() => _registeredIds = StorageService().getRegisteredIds());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RegisteredId>>(
      future: _registeredIds,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        // A new installation begins inside the app shell with no saved cards
        // or reminders. This makes the first-run experience discoverable and
        // lets people explore the app before they decide to add a card.
        return MainShell(
          registeredIds: snapshot.data ?? const <RegisteredId>[],
          onIdRemoved: _reloadRegistration,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      },
    );
  }
}
