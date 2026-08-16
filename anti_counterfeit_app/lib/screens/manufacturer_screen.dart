import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/services/url_launcher_service.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';
import 'package:anti_counterfeit_app/services/network_service.dart';
import 'package:anti_counterfeit_app/services/gallery_service.dart';
import 'package:anti_counterfeit_app/services/storage_service.dart';
import 'package:anti_counterfeit_app/services/biometric_service.dart';
import 'package:anti_counterfeit_app/services/qr_service.dart';

class ManufacturerScreen extends StatefulWidget {
  final BlockchainService blockchainService;

  const ManufacturerScreen({super.key, required this.blockchainService});

  @override
  State<ManufacturerScreen> createState() => _ManufacturerScreenState();
}

class _ManufacturerScreenState extends State<ManufacturerScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();

  bool _isLoading = false;
  bool _isGeneratingQR = false; // Added for QR state

  @override
  void initState() {
    super.initState();
    _loadSavedKey(); // Added to trigger biometrics on screen load
  }

  /// 1. SECURE BIOMETRIC KEY LOADING
  Future<void> _loadSavedKey() async {
    final savedKey = await StorageService.loadManufacturerKey();
    
    if (savedKey != null && savedKey.isNotEmpty && mounted) {
      bool authenticated = await BiometricService.authenticate();
      
      if (authenticated) {
        setState(() {
          _privateKeyController.text = savedKey;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Factory Manager Verified. Key unlocked 🔓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Key remains locked 🔒'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _registerProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final serialNumber = _serialController.text.trim();
    final productName = _nameController.text.trim();
    final privateKey = _privateKeyController.text.trim();

    // PRE-FLIGHT NETWORK CHECK
    bool hasInternet = await NetworkService.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Cannot mint product on-chain.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // PRE-FLIGHT GAS FEE & BALANCE CHECK
    final gasWarning = await widget.blockchainService.checkGasAndBalance(
      privateKeyHex: privateKey,
      functionName: 'addProduct',
      params: [BigInt.parse(_idController.text.trim()), serialNumber, productName],
    );

    if (gasWarning != null) {
      if (mounted) {
        _showErrorDialog("Gas Fee Warning ⚠️", gasWarning, Colors.orange);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send transaction to smart contract
      final txHash = await widget.blockchainService.addProduct(
        id: BigInt.parse(_idController.text.trim()),
        serialNumber: serialNumber,
        name: productName,
        privateKeyHex: privateKey,
      );

      // Save the Manufacturer Key securely using your XOR encryption!
      await StorageService.saveManufacturerKey(privateKey);

      if (mounted) {
        // Pass the serial & name to the dialog so it can generate the QR code
        _showSuccessDialog(txHash, serialNumber, productName);
        _formKey.currentState!.reset(); // Clear the form
        _privateKeyController.text = privateKey; // Keep the key populated for the next scan
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Transaction Failed ❌", e.toString(), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 2. NATIVE QR CODE GENERATION & EXPORT (Zero Packages)
  Future<void> _generateAndSaveQR(String serialNumber, String productName) async {
    setState(() => _isGeneratingQR = true);
    
    try {
      // Fetch high-res image bytes directly from your QrService API
      final bytes = await QrService.getQrBytes(serialNumber, size: 1024);

      // Pass bytes directly to your Custom Kotlin Native Bridge!
      final success = await GalleryService.saveImage(bytes, filename: "${serialNumber}_qr.png");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Saved to Gallery! 🖼️' : 'Failed to save to Gallery.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingQR = false);
      }
    }
  }

  /// 3. SUCCESS DIALOG (Displays QR Code & Export Button)
  void _showSuccessDialog(String txHash, String serialNumber, String productName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // StatefulBuilder allows the dialog to update its own UI (like the loading spinner)
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text(
                    "Success! ✅",
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "'$productName' successfully minted on the Sepolia blockchain.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // 🌟 THE VISUAL QR CODE BLOCK 🌟
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      // Calls your custom QrService to display the image!
                      child: QrService.buildQrWidget(serialNumber, size: 150),
                    ),
                    const SizedBox(height: 20),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Transaction Hash:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        txHash,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // NATIVE EXPORT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isGeneratingQR 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download),
                        label: Text(_isGeneratingQR ? "Saving..." : "Save QR to Gallery"),
                        onPressed: _isGeneratingQR ? null : () async {
                          // Update dialog state to show spinner
                          setDialogState(() => _isGeneratingQR = true); 
                          
                          await _generateAndSaveQR(serialNumber, productName);
                          
                          // Remove spinner when done
                          if (mounted) {
                            setDialogState(() => _isGeneratingQR = false);
                          }
                        },
                      ),
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showErrorDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _serialController.dispose();
    _nameController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.factory_rounded, size: 56, color: Color(0xFF4F46E5)),
                  const SizedBox(height: 16),
                  const Text(
                    "Register Product",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Mint a new asset on the blockchain",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildModernTextField(
                    controller: _idController,
                    label: 'Product ID',
                    hint: 'Numeric ID',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Enter a valid ID' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _serialController,
                    label: 'Serial Number',
                    hint: 'e.g. QR-101',
                    icon: Icons.qr_code,
                    validator: (value) => value!.isEmpty ? 'Enter a serial number' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _nameController,
                    label: 'Product Name',
                    hint: 'e.g. Luxury Watch',
                    icon: Icons.inventory_2_outlined,
                    validator: (value) => value!.isEmpty ? 'Enter a product name' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _privateKeyController,
                    label: 'Manufacturer Private Key',
                    hint: 'Hex Key for gas fees',
                    icon: Icons.key,
                    obscureText: true,
                    validator: (value) => value!.isEmpty ? 'Private key is required' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _registerProduct,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Mint on Blockchain",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}