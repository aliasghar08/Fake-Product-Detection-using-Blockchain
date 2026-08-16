import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/services/url_launcher_service.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';
import 'package:anti_counterfeit_app/services/storage_service.dart';
import 'package:anti_counterfeit_app/services/network_service.dart';
import 'package:anti_counterfeit_app/services/biometric_service.dart'; // IMPORT ADDED
import 'package:anti_counterfeit_app/widgets/scanner.dart';

class RetailerScreen extends StatefulWidget {
  final BlockchainService blockchainService;
  final bool isActive;

  const RetailerScreen({super.key, required this.blockchainService, this.isActive = true});

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
    // 1. Check if there is even a key to load first
    final savedKey = await StorageService.loadKey();
    
    if (savedKey != null && savedKey.isNotEmpty && mounted) {
      // 2. Trigger native Biometric verification (Fingerprint/Face ID)
      bool authenticated = await BiometricService.authenticate();
      
      if (authenticated) {
        // 3. Unlock and populate the key
        setState(() {
          _privateKeyController.text = savedKey;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Identity verified. Private key unlocked 🔓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 4. Fail gracefully if they cancel or use the wrong fingerprint
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Key remains locked 🔒'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleScannedCode(String scannedSerialNumber) async {
    if (_isProcessing) return;

    final privateKey = _privateKeyController.text.trim();

    if (privateKey.isEmpty) {
      _showErrorDialog(
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
      return;
    }

    // 2. PRE-FLIGHT GAS FEE & BALANCE CHECK
    final gasWarning = await widget.blockchainService.checkGasAndBalance(
      privateKeyHex: privateKey,
      functionName: 'markAsSold',
      params: [scannedSerialNumber],
    );

    if (gasWarning != null) {
      if (mounted) {
        _showErrorDialog("Gas Fee Warning ⚠️", gasWarning, Colors.orange);
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isProcessing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final txHash = await widget.blockchainService.markAsSold(
        serialNumber: scannedSerialNumber,
        privateKeyHex: privateKey,
      );

      await StorageService.saveKey(privateKey);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showSuccessDialog(txHash);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showErrorDialog("Transaction Failed ❌", e.toString(), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog(String txHash) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text(
              "Checkout Successful! 🛒",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Product permanently marked as sold on the blockchain.\n"),
              const Text(
                "Transaction Hash:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              SelectableText(
                txHash,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text("View on Etherscan"),
            onPressed: () async {
              final Uri url = Uri.parse('https://sepolia.etherscan.io/tx/$txHash');
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch Etherscan URL')),
                  );
                }
              }
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message, Color color) {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Card(
            elevation: 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Retailer Wallet",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _privateKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Private Key',
                      hintText: 'Enter Hex Key',
                      prefixIcon: const Icon(Icons.key, color: Color(0xFF4F46E5)),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF1E293B) 
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Required to pay gas fees when marking products as sold.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomScannerWidget(
              isActive: widget.isActive,
              onCodeDetected: (String code) {
                _handleScannedCode(code);
              },
            ),
          ),
        ),
      ],
    );
  }
}