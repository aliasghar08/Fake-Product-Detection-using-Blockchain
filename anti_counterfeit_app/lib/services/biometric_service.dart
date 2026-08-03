import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BiometricService {
  // Must match the BIOMETRIC_CHANNEL string in your MainActivity.kt
  static const MethodChannel _channel = MethodChannel('com.example.anti_counterfeit_app/biometrics');

  /// Triggers the native OS biometric prompt (Fingerprint / Face ID).
  /// Returns `true` if authentication succeeds, `false` otherwise.
  static Future<bool> authenticate() async {
    try {
      final bool? authenticated = await _channel.invokeMethod<bool>('authenticate');
      return authenticated ?? false;
    } on PlatformException catch (e) {
      // If the device doesn't have hardware or the user cancels, it falls here
      debugPrint('Biometric error: ${e.message}');
      return false;
    }
  }
}