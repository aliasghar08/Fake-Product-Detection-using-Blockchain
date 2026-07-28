import 'package:anti_counterfeit_app/widgets/scanner.dart';
import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';

class ScannerScreen extends StatefulWidget {
  final BlockchainService blockchainService;

  const ScannerScreen({super.key, required this.blockchainService});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;

  /// This triggers when CustomScannerWidget fires 'onCodeDetected'
  Future<void> _handleScannedCode(String scannedSerialNumber) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    // Send the string to the blockchain
    final result = await widget.blockchainService.verifyProduct(
      scannedSerialNumber,
    );

    // Remove loading indicator
    if (mounted) Navigator.pop(context);

    // Show results
    if (mounted) {
      if (result['isAuthentic'] == true) {
        if (result['isSold'] == true) {
          await _showResultDialog(
            "WARNING: ALREADY SOLD ⚠️",
            "This item exists, but was already marked as purchased. Potential clone!",
            Colors.orange,
            Icons.warning_amber_rounded,
          );
        } else {
          await _showResultDialog(
            "AUTHENTIC PRODUCT ✅",
            "Product: ${result['name']}\nManufacturer: ${result['manufacturer']}",
            Colors.green,
            Icons.verified_rounded,
          );
        }
      } else {
        await _showResultDialog(
          "FAKE DETECTED ❌",
          result['error'] ?? "Product not found on ledger.",
          Colors.red,
          Icons.cancel_outlined,
        );
      }
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _showResultDialog(
    String title,
    String message,
    Color color,
    IconData icon,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Scan Another",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Verify Product',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      // PLUGGING IN YOUR SEPARATE WIDGET HERE
      body: CustomScannerWidget(
        onCodeDetected: (String code) {
          _handleScannedCode(code);
        },
      ),
    );
  }
}
