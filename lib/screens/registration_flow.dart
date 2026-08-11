import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/id_scan_result.dart';
import '../models/registered_id.dart';
import 'id_review_screen.dart';
import 'id_scanner_screen.dart';

enum _PermissionAction { cancel, retry, settings }

Future<RegisteredId?> startIdRegistration(BuildContext context) async {
  while (true) {
    final scanResult = await scanSchoolId(context);
    if (scanResult == null || !context.mounted) {
      return null;
    }

    final reviewOutcome = await Navigator.of(context).push<IdReviewOutcome>(
      MaterialPageRoute(builder: (_) => IdReviewScreen(scanResult: scanResult)),
    );
    if (reviewOutcome == null || !context.mounted) {
      return null;
    }
    if (reviewOutcome.registeredId != null) {
      return reviewOutcome.registeredId;
    }
    if (!reviewOutcome.scanAgain) {
      return null;
    }
  }
}

/// Opens the single, existing camera/OCR scanner after obtaining camera access.
/// Registration and alarm verification both use this path so scanner behavior
/// stays consistent.
Future<IdScanResult?> scanSchoolId(BuildContext context) async {
  var permissionStatus = await Permission.camera.status;

  while (!permissionStatus.isGranted) {
    permissionStatus = await Permission.camera.request();
    if (permissionStatus.isGranted) {
      break;
    }
    if (!context.mounted) {
      return null;
    }

    final permanentlyDenied =
        permissionStatus.isPermanentlyDenied || permissionStatus.isRestricted;
    final action = await _showPermissionDialog(
      context,
      permanentlyDenied: permanentlyDenied,
    );
    if (action == _PermissionAction.settings) {
      await openAppSettings();
      return null;
    }
    if (action != _PermissionAction.retry) {
      return null;
    }
  }

  if (!context.mounted) return null;
  return Navigator.of(context).push<IdScanResult>(
    MaterialPageRoute(builder: (_) => const IdScannerScreen()),
  );
}

Future<_PermissionAction?> _showPermissionDialog(
  BuildContext context, {
  required bool permanentlyDenied,
}) {
  return showDialog<_PermissionAction>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.camera_alt_outlined),
      title: const Text('Camera access needed'),
      content: Text(
        permanentlyDenied
            ? 'Camera access is turned off. Open this app in Settings and allow camera access to scan your school ID.'
            : 'ID Reminder only uses the camera while you scan your card. The card photo is not kept after OCR finishes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _PermissionAction.cancel),
          child: const Text('NOT NOW'),
        ),
        if (!permanentlyDenied)
          FilledButton(
            onPressed: () => Navigator.pop(context, _PermissionAction.retry),
            child: const Text('TRY AGAIN'),
          ),
        if (permanentlyDenied)
          FilledButton(
            onPressed: () => Navigator.pop(context, _PermissionAction.settings),
            child: const Text('OPEN SETTINGS'),
          ),
      ],
    ),
  );
}
