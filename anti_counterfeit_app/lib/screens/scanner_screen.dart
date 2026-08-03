import 'package:anti_counterfeit_app/services/location_service.dart';
import 'package:anti_counterfeit_app/services/network_service.dart';
import 'package:anti_counterfeit_app/widgets/scanner.dart';
import 'package:anti_counterfeit_app/widgets/timeline_sheet.dart';
import 'package:anti_counterfeit_app/widgets/history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';
import 'package:anti_counterfeit_app/services/history_service.dart';
import 'package:geolocator/geolocator.dart';

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

    // 1. PRE-FLIGHT NETWORK CHECK
    bool hasInternet = await NetworkService.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Please check your network to verify products.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Stop execution if offline
    }

    setState(() => _isProcessing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    // 2. Fetch GPS Location asynchronously while verifying on the blockchain
    final locationFuture = LocationService.getCurrentLocation();

    // 3. Send the string to the blockchain
    final result = await widget.blockchainService.verifyProduct(
      scannedSerialNumber,
    );

    // Wait for GPS to finish grabbing coordinates
    final Position? position = await locationFuture;

    if (mounted) Navigator.pop(context); // Remove loading indicator

    // 4. Determine Status
    String status = 'Fake';
    if (result['isAuthentic'] == true) {
      status = result['isSold'] == true ? 'Sold' : 'Authentic';
    }

    // 5. Save to history WITH location data
    await HistoryService.saveScan(
      ScanRecord(
        serialNumber: scannedSerialNumber,
        name: result['name'] ?? 'Unknown',
        status: status,
        timestamp: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      ),
    );

    // Show Timeline Bottom Sheet
    if (mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ProductTimelineSheet(
          serialNumber: scannedSerialNumber,
          data: result,
        ),
      );
    }

    setState(() => _isProcessing = false);
  }

  // KEPT AS REQUESTED - The original dialog function remains here safely
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
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(fontSize: 16)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Scan Another",
              style: TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. BASE LAYER: The Camera Scanner
          CustomScannerWidget(
            onCodeDetected: (String code) {
              _handleScannedCode(code);
            },
          ),

          // 2. OVERLAY LAYER: Practical History Button
          Positioned(
            top:
                MediaQuery.of(context).padding.top +
                16, // Respects the phone's status bar
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54, // Semi-transparent background
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: 'Scan History',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const ScanHistorySheet(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
