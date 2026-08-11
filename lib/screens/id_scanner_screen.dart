import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/id_scan_result.dart';
import '../services/camera_service.dart';
import '../services/ocr_service.dart';
import '../services/scan_readiness_evaluator.dart';
import '../widgets/scanner_overlay.dart';

class IdScannerScreen extends StatefulWidget {
  const IdScannerScreen({super.key});

  @override
  State<IdScannerScreen> createState() => _IdScannerScreenState();
}

class _IdScannerScreenState extends State<IdScannerScreen>
    with WidgetsBindingObserver {
  static const _analysisInterval = Duration(milliseconds: 900);

  final CameraService _cameraService = CameraService();
  final OcrService _ocrService = OcrService();
  final ScanReadinessEvaluator _readinessEvaluator = ScanReadinessEvaluator();

  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInitializing = true;
  bool _isAnalyzing = false;
  bool _scanLocked = false;
  bool _torchEnabled = false;
  bool _resumeCamera = false;
  int _cameraGeneration = 0;
  String _statusMessage = 'Starting camera...';
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _resumeCamera = true;
      _cameraGeneration += 1;
      unawaited(_cameraService.dispose());
      if (mounted) {
        setState(() => _isInitializing = true);
      }
    } else if (state == AppLifecycleState.resumed && _resumeCamera) {
      _resumeCamera = false;
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    final generation = ++_cameraGeneration;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _fatalError = null;
        _statusMessage = 'Starting camera...';
        _torchEnabled = false;
      });
    }

    try {
      await _cameraService.initialize();
      if (!mounted || generation != _cameraGeneration) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Position your school ID inside the frame';
      });
      await _startScanning();
    } on CameraServiceException catch (error) {
      _showFatalError(error.message, generation);
    } on CameraException catch (_) {
      _showFatalError(
        'The camera could not be started. Check camera access and try again.',
        generation,
      );
    } catch (_) {
      _showFatalError(
        'The camera could not be started. Please try again.',
        generation,
      );
    }
  }

  void _showFatalError(String message, int generation) {
    if (!mounted || generation != _cameraGeneration) {
      return;
    }
    setState(() {
      _isInitializing = false;
      _fatalError = message;
    });
  }

  Future<void> _startScanning() async {
    _readinessEvaluator.reset();
    _scanLocked = false;
    _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
    await _cameraService.startImageStream(_onCameraImage);
  }

  void _onCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (_scanLocked ||
        _isAnalyzing ||
        now.difference(_lastAnalysis) < _analysisInterval) {
      return;
    }
    _lastAnalysis = now;
    _isAnalyzing = true;
    unawaited(
      _analyzeFrame(image).whenComplete(() {
        _isAnalyzing = false;
      }),
    );
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    final camera = _cameraService.camera;
    final controller = _cameraService.controller;
    if (camera == null || controller == null || !mounted) {
      return;
    }

    try {
      final text = await _ocrService.recognizeCameraImage(
        image: image,
        camera: camera,
        deviceOrientation: controller.value.deviceOrientation,
      );
      if (!mounted || _scanLocked) {
        return;
      }
      if (text == null) {
        _setStatus('Looking for ID...');
        return;
      }

      final readiness = _readinessEvaluator.evaluate(text);
      if (!readiness.hasEnoughText) {
        _setStatus('Looking for ID...');
      } else if (readiness.isReady) {
        _setStatus('Hold still...');
        _scanLocked = true;
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) {
          await _captureAndProcess();
        }
      } else if (readiness.isHoldingStill) {
        _setStatus('Hold still...');
      } else {
        _setStatus('ID found - keep it steady');
      }
    } catch (_) {
      if (mounted && !_scanLocked) {
        _setStatus('Could not read that frame. Keep the card steady.');
      }
    }
  }

  Future<void> _captureAndProcess() async {
    XFile? capturedImage;
    try {
      _setStatus('Reading card...');
      await _cameraService.stopImageStream();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      capturedImage = await _cameraService.takePicture();
      final result = await _ocrService.recognizeFile(capturedImage.path);
      final readableCharacters = result.rawText
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .length;
      if (readableCharacters < 15) {
        await _recoverFromFailedScan(
          'Not enough readable text. Move closer and avoid glare.',
        );
        return;
      }
      if (mounted) {
        Navigator.pop<IdScanResult>(context, result);
      }
    } catch (_) {
      await _recoverFromFailedScan(
        'The card could not be read. Reposition it and try again.',
      );
    } finally {
      final imagePath = capturedImage?.path;
      if (imagePath != null) {
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // The camera plugin may already have removed its temporary file.
        }
      }
    }
  }

  Future<void> _recoverFromFailedScan(String message) async {
    if (!mounted) return;
    _setStatus(message);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    _readinessEvaluator.reset();
    _scanLocked = false;
    _setStatus('Position your school ID inside the frame');
    try {
      await _cameraService.startImageStream(_onCameraImage);
    } catch (_) {
      if (mounted) {
        setState(() {
          _fatalError = 'The camera stopped unexpectedly. Please try again.';
        });
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      final mode = await _cameraService.toggleTorch();
      if (mounted) {
        setState(() => _torchEnabled = mode == FlashMode.torch);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flashlight is not available.')),
        );
      }
    }
  }

  void _setStatus(String message) {
    if (mounted && _statusMessage != message) {
      setState(() => _statusMessage = message);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraGeneration += 1;
    unawaited(_cameraService.dispose());
    unawaited(_ocrService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;
    final cameraReady =
        !_isInitializing &&
        _fatalError == null &&
        controller != null &&
        controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraReady
          ? Stack(
              fit: StackFit.expand,
              children: [
                _CoveringCameraPreview(controller: controller),
                ScannerOverlay(
                  statusMessage: _statusMessage,
                  isReady: _statusMessage == 'Hold still...',
                  isReading: _statusMessage == 'Reading card...',
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScannerActionButton(
                          tooltip: 'Back',
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        if (_cameraService.flashSupported)
                          _ScannerActionButton(
                            tooltip: _torchEnabled
                                ? 'Turn flashlight off'
                                : 'Turn flashlight on',
                            icon: _torchEnabled
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            onPressed: _toggleTorch,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _ScannerLoadingOrError(
              error: _fatalError,
              onRetry: _initializeCamera,
              onBack: () => Navigator.maybePop(context),
            ),
    );
  }
}

class _CoveringCameraPreview extends StatelessWidget {
  const _CoveringCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _ScannerActionButton extends StatelessWidget {
  const _ScannerActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ScannerLoadingOrError extends StatelessWidget {
  const _ScannerLoadingOrError({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            Expanded(
              child: Center(
                child: error == null
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography_outlined,
                            color: Colors.white,
                            size: 58,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('TRY AGAIN'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
