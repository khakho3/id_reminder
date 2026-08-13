import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/registered_id.dart';
import '../models/reminder.dart';
import '../services/id_verification_service.dart';
import '../services/nfc_card_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import 'registration_flow.dart';

class AlarmGateScreen extends StatefulWidget {
  const AlarmGateScreen({
    super.key,
    required this.reminder,
    required this.registeredId,
    required this.onCompleted,
  });

  final Reminder reminder;
  final RegisteredId registeredId;
  final FutureOr<void> Function() onCompleted;

  @override
  State<AlarmGateScreen> createState() => _AlarmGateScreenState();
}

class _AlarmGateScreenState extends State<AlarmGateScreen> {
  final _reminderService = ReminderService();
  final _verificationService = const IdVerificationService();
  final _nfcService = const NfcCardService();
  final _audioPlayer = AudioPlayer();
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _isScanning = false;
  bool _isScanningNfc = false;
  bool _isVerified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _startAlarmSound();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startAlarmSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(BytesSource(_alarmTone()));
    } catch (_) {}
  }

  Future<void> _scan() async {
    if (_isScanning || _isVerified) return;
    setState(() {
      _isScanning = true;
      _error = null;
    });
    final scan = await scanSchoolId(context);
    if (!mounted) return;
    if (scan == null) {
      setState(() => _isScanning = false);
      return;
    }
    final result = _verificationService.verify(
      registeredId: widget.registeredId,
      scannedId: scan,
    );
    if (!result.isVerified) {
      setState(() {
        _isScanning = false;
        _error = result.message;
      });
      return;
    }
    await _completeVerification();
  }

  Future<void> _scanNfc() async {
    if (_isScanningNfc || _isVerified) return;
    if (!widget.registeredId.hasNfc) {
      setState(() => _error = 'This saved ID card has no NFC card linked.');
      return;
    }
    setState(() {
      _isScanningNfc = true;
      _error = null;
    });
    NfcScanResult result;
    try {
      result = await _nfcService.scan();
    } on NfcScanFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isScanningNfc = false;
        _error = _nfcFailureMessage(failure.reason);
      });
      return;
    }
    if (!mounted) return;
    if (result.tagId != widget.registeredId.nfcTagId) {
      setState(() {
        _isScanningNfc = false;
        _error = "That isn't the NFC card linked to this ID.";
      });
      return;
    }
    await _completeVerification();
  }

  Future<void> _completeVerification() async {
    setState(() {
      _isScanning = false;
      _isScanningNfc = false;
      _isVerified = true;
    });
    await _audioPlayer.stop();
    await _reminderService.complete(widget.reminder);
    NotificationService.instance.clearActiveReminder();
    await widget.onCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(_now));
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: _isVerified
                ? _VerifiedView(onDone: () => Navigator.of(context).pop())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 640;
                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'ID REMINDER',
                                style: TextStyle(
                                  color: Color(0xFFBFDBFE),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, contentConstraints) {
                                return SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: contentConstraints.maxHeight,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: compact ? 10 : 18,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              time,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: compact ? 52 : 68,
                                                    letterSpacing: compact
                                                        ? -2
                                                        : -3,
                                                  ),
                                            ),
                                            SizedBox(height: compact ? 10 : 18),
                                            Text(
                                              widget.reminder.label
                                                  .toUpperCase(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: .5,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Before you continue, verify ${widget.registeredId.displayName}.',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: .72,
                                                ),
                                                fontSize: compact ? 14 : 16,
                                                height: 1.4,
                                              ),
                                            ),
                                            SizedBox(height: compact ? 22 : 34),
                                            Container(
                                              width: compact ? 108 : 124,
                                              height: compact ? 80 : 92,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF172554),
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF60A5FA,
                                                  ),
                                                  width: 1.4,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.badge_rounded,
                                                size: compact ? 42 : 50,
                                                color: const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            SizedBox(height: compact ? 18 : 24),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.danger
                                                      .withValues(alpha: .2),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: AppColors.danger
                                                        .withValues(alpha: .55),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'ID NOT VERIFIED',
                                                  style: TextStyle(
                                                    color: Color(0xFFFCA5A5),
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: .8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_error != null) ...[
                                              const SizedBox(height: 14),
                                              Text(
                                                _error!,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Color(0xFFFCA5A5),
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isScanning ? null : _scan,
                              icon: _isScanning
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.document_scanner_rounded),
                              label: Text(
                                _error == null
                                    ? 'SCAN WITH CAMERA'
                                    : 'TRY CAMERA AGAIN',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: .45),
                                ),
                              ),
                              onPressed:
                                  widget.registeredId.hasNfc && !_isScanningNfc
                                  ? _scanNfc
                                  : null,
                              icon: _isScanningNfc
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.nfc_rounded),
                              label: Text(
                                widget.registeredId.hasNfc
                                    ? 'TAP NFC CARD'
                                    : 'NFC NOT LINKED',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 12),
                            Text(
                              'The alarm sound stops only after the right card verifies.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .52),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'ID VERIFIED',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "You're good to go.\nHave a great day.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .74),
              fontSize: 17,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 180,
            child: FilledButton(onPressed: onDone, child: const Text('DONE')),
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

Uint8List _alarmTone() {
  const sampleRate = 44100;
  const durationSeconds = 1;
  const frequency = 880.0;
  const amplitude = 0.65;
  final sampleCount = sampleRate * durationSeconds;
  final dataSize = sampleCount * 2;
  final bytes = ByteData(44 + dataSize);

  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < sampleCount; i++) {
    final envelope = (i % 11025) < 8500 ? 1.0 : 0.12;
    final wave = math.sin(2 * math.pi * frequency * i / sampleRate);
    final sample = (wave * amplitude * envelope * 32767).round();
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }

  return bytes.buffer.asUint8List();
}
