import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/id_scan_result.dart';
import 'ocr_text_parser.dart';

class OcrService {
  OcrService({OcrTextParser? parser}) : _parser = parser ?? OcrTextParser();

  final OcrTextParser _parser;
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<String?> recognizeCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    final inputImage = _inputImageFromCameraImage(
      image: image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (inputImage == null) {
      return null;
    }
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<IdScanResult> recognizeFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    return _parser.parse(recognizedText.text);
  }

  Future<void> dispose() => _recognizer.close();

  InputImage? _inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) {
        return null;
      }
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final isSupported =
        format != null &&
        ((Platform.isAndroid && format == InputImageFormat.nv21) ||
            (Platform.isIOS && format == InputImageFormat.bgra8888));
    if (!isSupported || image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
