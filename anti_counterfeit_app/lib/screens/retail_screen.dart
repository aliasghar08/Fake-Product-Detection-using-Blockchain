import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';
import 'package:anti_counterfeit_app/services/storage_service.dart';
import 'package:anti_counterfeit_app/services/network_service.dart';
import 'package:anti_counterfeit_app/widgets/scanner.dart';

class RetailerScreen extends StatefulWidget {
  final BlockchainService blockchainService;

  const RetailerScreen({super.key, required this.blockchainService});

  @override
  State<RetailerScreen> createState() => _RetailerScreenState();
}

class _RetailerScreenState extends State<RetailerScreen> {
  final TextEditingController _privateKeyController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedKey();
  }

  Future<void> _loadSavedKey() async {
    final savedKey = await StorageService.loadKey();
    if (savedKey != null && mounted) {
      setState(() {
        _privateKeyController.text = savedKey;
      });
    }
  }

  Future<void> _handleScannedCode(String scannedSerialNumber) async {
    if (_isProcessing) return;

    final privateKey = _privateKeyController.text.trim();

    // Enforce private key entry before scanning
    if (privateKey.isEmpty) {
      _showDialog(
        "Action Required",
        "Please enter your Retailer Private Key first to pay network gas fees.",
        Colors.orange,
      );
      return;
    }

    // 1. PRE-FLIGHT NETWORK CHECK
    bool hasInternet = await NetworkService.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Cannot process retail checkout.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Stop execution if offline
    }

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

    try {
      // Trigger the smart contract to mark the item as sold
      final txHash = await widget.blockchainService.markAsSold(
        serialNumber: scannedSerialNumber,
        privateKeyHex: privateKey,
      );

      // Save the private key upon successful checkout
      await StorageService.saveKey(privateKey);

      // Remove loading indicator
      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showDialog(
          "Checkout Successful! 🛒",
          "Product permanently marked as sold on the blockchain.\n\nTransaction Hash:\n$txHash",
          Colors.green,
        );
      }
    } catch (e) {
      // Remove loading indicator
      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showDialog("Transaction Failed ❌", e.toString(), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Retailer Checkout',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Column(
        children: [
          // Private Key Input Section (Top)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              controller: _privateKeyController,
              obscureText: true, // Hides the key for security
              decoration: const InputDecoration(
                labelText: 'Retailer Private Key',
                hintText: 'Enter key to authorize sale',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key, color: Colors.deepPurpleAccent),
              ),
            ),
          ),

          // Scanner Section (Bottom)
          Expanded(
            child: CustomScannerWidget(
              onCodeDetected: (String code) {
                _handleScannedCode(code);
              },
            ),
          ),
        ],
      ),
    );
  }
}
