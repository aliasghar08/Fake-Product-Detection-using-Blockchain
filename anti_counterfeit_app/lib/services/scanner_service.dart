import 'dart:async';
import 'blockchain_service.dart';

class ScannerService {
  final BlockchainService _blockchainService;

  // Stream to broadcast verification states to the UI
  final StreamController<Map<String, dynamic>> _scanStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get scanStream => _scanStreamController.stream;

  // Lock to prevent duplicate calls while a request is in flight
  bool _isProcessing = false;

  ScannerService(this._blockchainService);

  /// Call this function from ANY custom camera widget or text input when a code is detected
  Future<void> processCode(String rawCode) async {
    final cleanCode = rawCode.trim();

    if (_isProcessing || cleanCode.isEmpty) return;

    _isProcessing = true;

    // 1. Notify UI that processing has started (Show loading spinner)
    _scanStreamController.add({'status': ScanStatus.loading});

    try {
      // 2. Query the smart contract
      final result = await _blockchainService.verifyProduct(cleanCode);

      // 3. Emit the parsed blockchain result
      _scanStreamController.add({
        'status': ScanStatus.success,
        'serialNumber': cleanCode,
        'data': result,
      });
    } catch (e) {
      _scanStreamController.add({
        'status': ScanStatus.error,
        'message': 'Failed to communicate with blockchain: $e',
      });
    }
  }

  /// Reset the processing lock so the user can scan another item
  void resetScanner() {
    _isProcessing = false;
    _scanStreamController.add({'status': ScanStatus.idle});
  }

  void dispose() {
    _scanStreamController.close();
  }
}

enum ScanStatus { idle, loading, success, error }