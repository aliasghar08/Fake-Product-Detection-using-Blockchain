import 'dart:convert';
import 'package:flutter/services.dart';

// Replaces shared_preferences with our custom UserDefaults channel.
const _ch = MethodChannel('com.blockguard.anticounterfeit/storage');

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
    latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
    longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
  );
}

class HistoryService {
  static const String _key = 'scan_history';

  static Future<void> saveScan(ScanRecord record) async {
    List<ScanRecord> history = await getHistory();
    history.insert(0, record);
    if (history.length > 50) history = history.sublist(0, 50);

    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await _ch.invokeMethod<bool>('setString', {'key': _key, 'value': encoded});
  }

  static Future<List<ScanRecord>> getHistory() async {
    final data = await _ch.invokeMethod<String>('getString', _key);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => ScanRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> clearHistory() async {
    await _ch.invokeMethod<bool>('remove', _key);
  }
}
