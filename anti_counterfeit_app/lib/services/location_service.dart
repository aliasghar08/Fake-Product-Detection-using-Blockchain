import 'package:flutter/services.dart';

// Replaces the geolocator package.
// Backed by iOS CLLocationManager via a native MethodChannel.
const _ch = MethodChannel('com.blockguard.anticounterfeit/location');

/// A lightweight GPS coordinate holder (replaces geolocator's Position).
class Position {
  final double latitude;
  final double longitude;
  const Position({required this.latitude, required this.longitude});
}

class LocationService {
  /// Requests permission and returns the current GPS coordinates.
  /// Returns null if permissions are denied or location is turned off.
  static Future<Position?> getCurrentLocation() async {
    // 1. Check if location services are enabled
    final bool serviceEnabled =
        await _ch.invokeMethod<bool>('isLocationServiceEnabled') ?? false;
    if (!serviceEnabled) return null;

    // 2. Check / request permission
    String permission =
        await _ch.invokeMethod<String>('checkPermission') ?? 'denied';

    if (permission == 'notDetermined') {
      permission =
          await _ch.invokeMethod<String>('requestPermission') ?? 'denied';
    }

    if (permission == 'denied' || permission == 'deniedForever') return null;

    // 3. Fetch coordinates — returns {latitude, longitude} or null
    final Map<dynamic, dynamic>? coords =
        await _ch.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');

    if (coords == null) return null;

    return Position(
      latitude: (coords['latitude'] as num).toDouble(),
      longitude: (coords['longitude'] as num).toDouble(),
    );
  }
}
