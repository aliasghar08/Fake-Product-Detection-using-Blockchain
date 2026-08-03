import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductTimelineSheet extends StatelessWidget {
  final String serialNumber;
  final Map<String, dynamic> data;

  const ProductTimelineSheet({
    super.key,
    required this.serialNumber,
    required this.data,
  });

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return "${address.substring(0, 6)}...${address.substring(address.length - 4)}";
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return "Unknown Date";
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  /// Opens the manufacturer address profile on Sepolia Etherscan
  Future<void> _openEtherscanAddress(BuildContext context, String address) async {
    if (address.isEmpty || address.startsWith('0x000')) return;

    final Uri url = Uri.parse('https://sepolia.etherscan.io/address/$address');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Etherscan URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthentic = data['isAuthentic'] ?? false;
    final bool isSold = data['isSold'] ?? false;
    final String name = data['name'] ?? 'Unknown Product';
    final String manufacturer = data['manufacturer'] ?? '0x000...0000';
    final DateTime? timestamp = data['timestamp'];

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Icon(
                isAuthentic
                    ? (isSold
                        ? Icons.warning_amber_rounded
                        : Icons.verified_user)
                    : Icons.cancel_outlined,
                color: isAuthentic
                    ? (isSold ? Colors.orange : Colors.green)
                    : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAuthentic
                          ? (isSold ? "ALREADY SOLD" : "GENUINE PRODUCT")
                          : "FAKE DETECTED",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isAuthentic
                            ? (isSold ? Colors.orange[800] : Colors.green[800])
                            : Colors.red[800],
                      ),
                    ),
                    Text(
                      "Serial: $serialNumber",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          if (!isAuthentic) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  data['error'] ??
                      "This product serial number was not found on the Sepolia blockchain ledger.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
            ),
          ] else ...[
            // Product Name Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Item: $name",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // TIMELINE SECTION
            const Text(
              "Lifecycle Provenance",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Stage 1: Minted by Manufacturer (With Etherscan Clickable Address)
            _buildTimelineTile(
              icon: Icons.factory_rounded,
              iconColor: Colors.blueAccent,
              title: "Minted on Blockchain",
              subtitleWidget: InkWell(
                onTap: () => _openEtherscanAddress(context, manufacturer),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Manufacturer: ${_shortenAddress(manufacturer)} ",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 14, color: Colors.blue[700]),
                    ],
                  ),
                ),
              ),
              timestamp: _formatDate(timestamp),
              isCompleted: true,
              isLast: false,
            ),

            // Stage 2: Verified on Sepolia
            _buildTimelineTile(
              icon: Icons.link_rounded,
              iconColor: Colors.purpleAccent,
              title: "Ledger State Immutable",
              subtitleText: "Smart Contract: Sepolia Testnet",
              timestamp: "On-Chain Verified",
              isCompleted: true,
              isLast: false,
            ),

            // Stage 3: Retail Checkout Status
            _buildTimelineTile(
              icon: isSold
                  ? Icons.shopping_bag_rounded
                  : Icons.storefront_rounded,
              iconColor: isSold ? Colors.orange : Colors.green,
              title: isSold ? "Purchased & Locked" : "Available in Retail",
              subtitleText: isSold
                  ? "Marked as sold. Duplicate scans flag a cloned QR code!"
                  : "Item is fresh in inventory and ready for customer purchase.",
              timestamp: isSold ? "Status: Sold" : "Status: In Stock",
              isCompleted: isSold,
              isLast: true,
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Close Timeline"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitleText,
    Widget? subtitleWidget,
    required String timestamp,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (Icon + Vertical Line)
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isCompleted
                    ? iconColor.withValues(alpha: 0.15)
                    : Colors.grey[200],
                child: Icon(
                  icon,
                  size: 18,
                  color: isCompleted ? iconColor : Colors.grey,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: Colors.grey[300])),
            ],
          ),
          const SizedBox(width: 16),

          // Right Column (Content)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        timestamp,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (subtitleWidget != null)
                    subtitleWidget
                  else if (subtitleText != null)
                    Text(
                      subtitleText,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}