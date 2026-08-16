import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera + QR scanning service backed by [mobile_scanner] v6.
///
/// In mobile_scanner v6 barcode detection is delivered exclusively
/// through the [MobileScanner] widget's [onDetect] callback — the
/// controller no longer exposes a `.barcodes` stream.
///
/// The widget (scanner.dart) calls [handleCapture] from [onDetect],
/// which pipes the result into [barcodeStream] for the rest of the
/// app to consume, while honouring the pause/resume gate.
///
/// Public API:
///   • [barcodeStream]    – `Stream<String>` of detected raw values
///   • [controller]       – MobileScannerController for the widget
///   • [isInitialized]
///   • [initialize()]
///   • [handleCapture()]  – called by widget's onDetect
///   • [pauseDetection()] / [resumeDetection()]
///   • [toggleTorch()] / [isTorchOn]
///   • [dispose()]
class CameraService {
  late final MobileScannerController _scannerController;

  // Stream that emits every detected barcode / QR raw value
  final StreamController<String> _barcodeStreamController =
      StreamController<String>.broadcast();
  Stream<String> get barcodeStream => _barcodeStreamController.stream;

  bool _isInitialized = false;
  bool _isPaused = false;

  /// Exposes the controller so [MobileScanner] widget can be built.
  MobileScannerController? get controller =>
      _isInitialized ? _scannerController : null;

  bool get isInitialized => _isInitialized;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // mobile_scanner v6: camera starts when MobileScanner widget is built.
    // Calling start() here ensures the controller is ready before the
    // widget tree renders.
    await _scannerController.start();
    _isInitialized = true;
  }

  // ── Barcode callback (called from widget's onDetect) ──────────────────────

  /// The [MobileScanner] widget must wire its [onDetect] to this method:
  ///   onDetect: (capture) => _cameraService?.handleCapture(capture),
  void handleCapture(BarcodeCapture capture) {
    if (_isPaused || _barcodeStreamController.isClosed) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _barcodeStreamController.add(value);
        break; // emit only the first valid code per frame
      }
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void pauseDetection() => _isPaused = true;
  void resumeDetection() => _isPaused = false;

  Future<void> toggleTorch() async {
    if (!_isInitialized) return;
    await _scannerController.toggleTorch();
  }

  /// Torch state — reads the state from the controller's value.
  bool get isTorchOn =>
      _scannerController.value.torchState == TorchState.on;

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _scannerController.dispose();
    if (!_barcodeStreamController.isClosed) {
      await _barcodeStreamController.close();
    }
    _isInitialized = false;
  }
}
