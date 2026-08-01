import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// A custom service that owns the camera lifecycle and QR/barcode detection.
///
/// Usage:
///   1. Call [initialize] once to start the camera.
///   2. Listen to [barcodeStream] for detected codes.
///   3. Call [pauseDetection] / [resumeDetection] to control scanning.
///   4. Call [dispose] when done.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  // ML Kit barcode scanner – only looks for QR codes for speed
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );

  // Stream that emits every detected barcode string
  final StreamController<String> _barcodeStreamController =
      StreamController<String>.broadcast();
  Stream<String> get barcodeStream => _barcodeStreamController.stream;

  // State flags
  bool _isDetecting = false;
  bool _isPaused = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  // ── Initialization ──────────────────────────────────────────────────────

  /// Discovers available cameras and starts the rear-facing one.
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw CameraException('noCameras', 'No cameras found on this device.');
    }

    // Prefer the back camera
    final backCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // required for ML Kit on Android
    );

    await _controller!.initialize();
    _startImageStream();
  }

  // ── Image stream → ML Kit ──────────────────────────────────────────────

  void _startImageStream() {
    _controller?.startImageStream((CameraImage image) {
      if (_isDetecting || _isPaused) return;
      _isDetecting = true;
      _processImage(image).whenComplete(() => _isDetecting = false);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);

      for (final barcode in barcodes) {
        final value = barcode.rawValue;
        if (value != null && value.isNotEmpty) {
          _barcodeStreamController.add(value);
          break; // emit only the first valid code per frame
        }
      }
    } catch (e) {
      debugPrint('CameraService: barcode detection error – $e');
    }
  }

  /// Converts a [CameraImage] from the camera plugin into an ML Kit
  /// [InputImage].  Supports NV21 (Android) and BGRA8888 (iOS).
  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameras?.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Concatenate all planes into a single byte buffer
    final bytes = Uint8List.fromList(
      image.planes.fold<List<int>>(
        [],
        (prev, plane) => prev..addAll(plane.bytes),
      ),
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ── Controls ────────────────────────────────────────────────────────────

  /// Temporarily stop barcode detection (camera keeps running).
  void pauseDetection() => _isPaused = true;

  /// Resume barcode detection.
  void resumeDetection() => _isPaused = false;

  /// Toggle the device torch / flashlight.
  Future<void> toggleTorch() async {
    if (_controller == null) return;
    final currentMode = _controller!.value.flashMode;
    await _controller!.setFlashMode(
      currentMode == FlashMode.torch ? FlashMode.off : FlashMode.torch,
    );
  }

  /// Whether the torch is currently on.
  bool get isTorchOn => _controller?.value.flashMode == FlashMode.torch;

  // ── Cleanup ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _barcodeScanner.close();
    await _barcodeStreamController.close();
  }
}
