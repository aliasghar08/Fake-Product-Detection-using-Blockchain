import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanRecord {
  final String serialNumber;
  final String name;
  final String status;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  ScanRecord({
    required this.serialNumber,
    required this.name,
    required this.status,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'serialNumber': serialNumber,
    'name': name,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    serialNumber: json['serialNumber'],
    name: json['name'],
    status: json['status'],
    timestamp: DateTime.parse(json['timestamp']),
    latitude: json['latitude'] != null
        ? (json['latitude'] as num).toDouble()
        : null,
    longitude: json['longitude'] != null
        ? (json['longitude'] as num).toDouble()
        : null,
  );
}

class HistoryService {
  static const String _key = 'scan_history';

  static Future<void> saveScan(ScanRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    List<ScanRecord> history = await getHistory();

    // Add the new record to the top of the list
    history.insert(0, record);

    // Keep only the last 50 scans to save space
    if (history.length > 50) history = history.sublist(0, 50);

    final String encodedData = jsonEncode(
      history.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_key, encodedData);
  }

  static Future<List<ScanRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);

    if (data == null) return [];

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => ScanRecord.fromJson(e)).toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
