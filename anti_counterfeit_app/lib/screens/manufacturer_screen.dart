import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';

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

  Future<void> _registerProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Send the transaction to the smart contract
      final txHash = await widget.blockchainService.addProduct(
        id: BigInt.parse(_idController.text.trim()),
        serialNumber: _serialController.text.trim(),
        name: _nameController.text.trim(),
        privateKeyHex: _privateKeyController.text.trim(),
      );

      if (mounted) {
        _showDialog(
          "Success! ✅",
          "Product registered on the blockchain.\n\nTransaction Hash:\n$txHash",
          Colors.green,
        );
        _formKey.currentState!.reset(); // Clear the form
      }
    } catch (e) {
      if (mounted) {
        _showDialog("Transaction Failed ❌", e.toString(), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: SelectableText(
          message,
        ), // Selectable so you can copy the txHash
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manufacturer Portal'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.factory_rounded,
                      size: 60,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Register New Product",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Product ID Field
                    TextFormField(
                      controller: _idController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Product ID (Numeric)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter a valid ID' : null,
                    ),
                    const SizedBox(height: 16),

                    // Serial Number Field
                    TextFormField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        labelText: 'Serial Number (e.g. QR-101)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter a serial number' : null,
                    ),
                    const SizedBox(height: 16),

                    // Product Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter a product name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Private Key Field (Required to pay gas fees)
                    TextFormField(
                      controller: _privateKeyController,
                      obscureText: true, // Hides the private key for security
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer Private Key',
                        border: OutlineInputBorder(),
                        helperText: "Used to sign the transaction and pay gas.",
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Private key is required' : null,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _registerProduct,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Mint on Blockchain",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
