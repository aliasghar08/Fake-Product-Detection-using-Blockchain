import 'package:flutter/material.dart';

class QrService {
  /// Generates the API URL for the QR code based on your product data
  static String _generateQrUrl(String data, {int size = 200}) {
    // Encodes the string safely for web transmission
    final encodedData = Uri.encodeComponent(data);
    return 'https://api.qrserver.com/v1/create-qr-code/?size=${size}x$size&data=$encodedData';
  }

  /// Returns a ready-to-use Flutter Image widget containing the QR code
  static Widget buildQrWidget(String serialNumber, {int size = 200}) {
    final url = _generateQrUrl(serialNumber, size: size);

    return Image.network(
      url,
      width: size.toDouble(),
      height: size.toDouble(),
      // Shows a spinner while the QR code is fetching
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: size.toDouble(),
          height: size.toDouble(),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        );
      },
      // Handles offline/error states gracefully
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size.toDouble(),
          height: size.toDouble(),
          color: Colors.grey[200],
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 40),
              SizedBox(height: 8),
              Text("Failed to load QR"),
            ],
          ),
        );
      },
    );
  }
}
