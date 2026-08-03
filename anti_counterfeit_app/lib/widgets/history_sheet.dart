import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:anti_counterfeit_app/services/history_service.dart';

class ScanHistorySheet extends StatefulWidget {
  const ScanHistorySheet({super.key});

  @override
  State<ScanHistorySheet> createState() => _ScanHistorySheetState();
}

class _ScanHistorySheetState extends State<ScanHistorySheet> {
  List<ScanRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    setState(() {
      // Reversing so the newest scans show at the top of the list!
      _history = history.reversed.toList();
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await HistoryService.clearHistory();
    setState(() {
      _history = [];
    });
  }

  /// Opens the native Google Maps app or browser using the captured coordinates
  Future<void> _openMap(double lat, double lng) async {
    final Uri url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Maps.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          MediaQuery.of(context).size.height * 0.75, // Takes up 75% of screen
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Scan History",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (_history.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    "Clear",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          const Divider(),

          // List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(
                        child: Text("No scans yet. Scan a product to start!"),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final record = _history[index];

                          // Determine UI styling based on status
                          Color iconColor;
                          IconData iconData;
                          if (record.status == 'Authentic') {
                            iconColor = Colors.green;
                            iconData = Icons.verified_rounded;
                          } else if (record.status == 'Sold') {
                            iconColor = Colors.orange;
                            iconData = Icons.warning_amber_rounded;
                          } else {
                            iconColor = Colors.red;
                            iconData = Icons.cancel_outlined;
                          }

                          final hasLocation = record.latitude != null &&
                                              record.longitude != null;
                          final formattedTime = 
                              "${record.timestamp.month}/${record.timestamp.day} ${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor:
                                    iconColor.withValues(alpha: 0.15),
                                child: Icon(iconData, color: iconColor),
                              ),
                              title: Text(
                                record.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text("Serial: ${record.serialNumber}"),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              // The new interactive Map button!
                              trailing: hasLocation
                                  ? IconButton(
                                      icon: const Icon(Icons.map,
                                          color: Colors.blueAccent),
                                      tooltip: 'View Scan Location',
                                      onPressed: () => _openMap(
                                          record.latitude!, record.longitude!),
                                    )
                                  : const IconButton(
                                      icon: Icon(Icons.location_off,
                                          color: Colors.grey),
                                      tooltip: 'No GPS data captured',
                                      onPressed: null,
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}