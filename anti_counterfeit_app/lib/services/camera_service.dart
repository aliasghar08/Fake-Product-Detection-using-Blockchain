import 'dart:async';
import 'package:flutter/services.dart';

/// Channel names — must match the Swift constants in AppDelegate.swift.
const String kScannerViewType = 'com.blockguard.anticounterfeit/scanner_view';
const String _kEventChannel = 'com.blockguard.anticounterfeit/scanner_events';
const String _kMethodChannel = 'com.blockguard.anticounterfeit/scanner_control';

/// Custom QR/barcode scanning service backed entirely by iOS native
/// AVFoundation (AVCaptureSession + AVCaptureMetadataOutput).
///
/// No third-party scanner library is used. Communication happens over:
///   • [FlutterEventChannel]  → streams raw QR strings from native side
///   • [FlutterMethodChannel] → start / stop / pause / resume / torch
///
/// The camera preview is rendered by a [UiKitView] in [scanner.dart]
/// using the view-type [kScannerViewType].
///
/// Public API:
///   • [barcodeStream]    – `Stream<String>` of detected raw values
///   • [isInitialized]
///   • [initialize()]
///   • [pauseDetection()] / [resumeDetection()]
///   • [toggleTorch()] / [isTorchOn]
///   • [dispose()]
class CameraService {
  static const _events = EventChannel(_kEventChannel);
  static const _methods = MethodChannel(_kMethodChannel);

  final StreamController<String> _barcodeStreamController =
      StreamController<String>.broadcast();
  Stream<String> get barcodeStream => _barcodeStreamController.stream;

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isInitialized = false;
  bool _isPaused = false;
  bool _isTorchOn = false;

  bool get isInitialized => _isInitialized;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final granted = await _methods.invokeMethod<bool>('requestCameraPermission');
    if (granted != true) {
      return;
    }

    // Tell native side to prepare and start the AVCaptureSession.
    await _methods.invokeMethod<void>('start');

    // Subscribe to the native QR detection event stream.
    _eventSubscription = _events.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (_isPaused) return;
        final value = raw?.toString() ?? '';
        if (value.isNotEmpty && !_barcodeStreamController.isClosed) {
          _barcodeStreamController.add(value);
        }
      },
      onError: (dynamic e) {
        // Non-fatal — session errors are handled on the native side.
      },
      cancelOnError: false,
    );

    _isInitialized = true;
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void pauseDetection() {
    _isPaused = true;
    _methods.invokeMethod<void>('pause');
  }

  void resumeDetection() {
    _isPaused = false;
    _methods.invokeMethod<void>('resume');
  }

  Future<void> toggleTorch() async {
    await _methods.invokeMethod<void>('toggleTorch');
    _isTorchOn = !_isTorchOn;
  }

  bool get isTorchOn => _isTorchOn;

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _methods.invokeMethod<void>('stop');
    if (!_barcodeStreamController.isClosed) {
      await _barcodeStreamController.close();
    }
    _isInitialized = false;
    _isTorchOn = false;
  }
}
