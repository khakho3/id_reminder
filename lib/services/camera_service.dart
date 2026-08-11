import 'dart:io';

import 'package:camera/camera.dart';

class CameraServiceException implements Exception {
  const CameraServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CameraService {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _flashSupported = false;

  CameraController? get controller => _controller;
  CameraDescription? get camera => _camera;
  bool get flashSupported => _flashSupported;

  Future<void> initialize() async {
    await dispose();

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const CameraServiceException('No camera was found on this device.');
    }

    _camera = cameras.cast<CameraDescription?>().firstWhere(
      (camera) => camera?.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final selectedCamera = _camera!;
    final newController = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller = newController;

    try {
      await newController.initialize();
    } on CameraException catch (error) {
      _controller = null;
      _camera = null;
      _flashSupported = false;
      await newController.dispose();
      throw CameraServiceException(_cameraErrorMessage(error));
    } catch (_) {
      _controller = null;
      _camera = null;
      _flashSupported = false;
      await newController.dispose();
      throw const CameraServiceException(
        'The camera could not be started. Please try again.',
      );
    }

    try {
      await newController.setFlashMode(FlashMode.off);
      _flashSupported = true;
    } on CameraException {
      _flashSupported = false;
    }
  }

  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      throw const CameraServiceException('The camera is not ready.');
    }
    if (!cameraController.value.isStreamingImages) {
      await cameraController.startImageStream(onImage);
    }
  }

  Future<void> stopImageStream() async {
    final cameraController = _controller;
    if (cameraController != null &&
        cameraController.value.isInitialized &&
        cameraController.value.isStreamingImages) {
      await cameraController.stopImageStream();
    }
  }

  Future<XFile> takePicture() async {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      throw const CameraServiceException('The camera is not ready.');
    }
    return cameraController.takePicture();
  }

  Future<FlashMode> toggleTorch() async {
    final cameraController = _controller;
    if (cameraController == null || !_flashSupported) {
      throw const CameraServiceException('Flashlight is not available.');
    }
    final newMode = cameraController.value.flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    await cameraController.setFlashMode(newMode);
    return newMode;
  }

  Future<void> dispose() async {
    final cameraController = _controller;
    _controller = null;
    _camera = null;
    _flashSupported = false;
    if (cameraController != null) {
      try {
        if (cameraController.value.isInitialized &&
            cameraController.value.isStreamingImages) {
          await cameraController.stopImageStream();
        }
      } on CameraException {
        // Disposal is best-effort cleanup; dispose below still releases camera.
      } finally {
        await cameraController.dispose();
      }
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera access is not available. Check the app permission in Settings.';
      default:
        return 'The camera could not be started. Please try again.';
    }
  }
}
