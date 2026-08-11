import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcScanResult {
  const NfcScanResult({required this.tagId});

  final String tagId;
}

enum NfcScanFailureReason { unavailable, timeout, failed }

class NfcScanFailure implements Exception {
  const NfcScanFailure(this.reason);

  final NfcScanFailureReason reason;
}

class NfcCardService {
  const NfcCardService();

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  Future<NfcScanResult> scan({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (!await isAvailable()) {
      throw const NfcScanFailure(NfcScanFailureReason.unavailable);
    }
    final completer = Completer<NfcScanResult>();
    var completed = false;
    Timer? timer;

    Future<void> finish(
      NfcScanResult? result,
      NfcScanFailureReason? failure,
    ) async {
      if (completed) return;
      completed = true;
      timer?.cancel();
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      if (completer.isCompleted) return;
      if (result != null) {
        completer.complete(result);
      } else {
        completer.completeError(
          NfcScanFailure(failure ?? NfcScanFailureReason.failed),
        );
      }
    }

    timer = Timer(timeout, () => finish(null, NfcScanFailureReason.timeout));
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {NfcPollingOption.iso14443},
        onDiscovered: (tag) async {
          final tagId = _tagId(tag);
          await finish(
            tagId == null ? null : NfcScanResult(tagId: tagId),
            NfcScanFailureReason.failed,
          );
        },
      );
    } catch (_) {
      await finish(null, NfcScanFailureReason.failed);
    }

    return completer.future;
  }

  String? _tagId(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null || androidTag.id.isEmpty) return null;
    return _hex(androidTag.id);
  }

  String _hex(Uint8List bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}
