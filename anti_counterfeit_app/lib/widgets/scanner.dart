import 'package:flutter/material.dart';

class CustomScannerWidget extends StatefulWidget {
  // This callback sends the scanned string back to the main screen
  final Function(String) onCodeDetected;

  const CustomScannerWidget({super.key, required this.onCodeDetected});

  @override
  State<CustomScannerWidget> createState() => _CustomScannerWidgetState();
}

class _CustomScannerWidgetState extends State<CustomScannerWidget> {
  
  // TODO: Initialize your posHub camera controller here
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. YOUR POSHUB CAMERA VIEW GOES HERE
        // Replace this Container with your actual custom camera preview widget
        Container(
          color: Colors.grey[900],
          width: double.infinity,
          height: double.infinity,
          child: const Center(
            child: Text(
              "Your Custom Camera Feed",
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ),
        ),

        // 2. TESTING BUTTON (Optional)
        // Since the PC emulator can't scan real QR codes, use this button to 
        // test the blockchain connection before you build the APK.
        Positioned(
          bottom: 100,
          left: 50,
          right: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code),
            label: const Text("Simulate QR Scan (Test-123)"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: () {
              // Simulating that the camera just detected a string
              // Replace "Test-123" with a serial number you deployed to your smart contract
              widget.onCodeDetected("Test-123"); 
            },
          ),
        )
      ],
    );
  }
}