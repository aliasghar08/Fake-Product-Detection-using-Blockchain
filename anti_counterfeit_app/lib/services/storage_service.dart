import 'dart:convert';
import 'package:flutter/services.dart';

// Replaces the shared_preferences package.
// Backed by iOS UserDefaults via a native MethodChannel.
const _ch = MethodChannel('com.blockguard.anticounterfeit/storage');

class StorageService {
  static const String _retailerKey = 'saved_retailer_key';
  static const String _manufacturerKey = 'saved_manufacturer_key';
  static const String _cipherSecret = 'fyp_sepolia_secret_2026';

  // ── XOR + Base64 encryption (unchanged) ──────────────────────────────────

  static String _encrypt(String text) {
    final textBytes = utf8.encode(text);
    final keyBytes = utf8.encode(_cipherSecret);
    final encrypted = List<int>.generate(
      textBytes.length,
      (i) => textBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64.encode(encrypted);
  }

  static String _decrypt(String base64Text) {
    final encrypted = base64.decode(base64Text);
    final keyBytes = utf8.encode(_cipherSecret);
    final decrypted = List<int>.generate(
      encrypted.length,
      (i) => encrypted[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(decrypted);
  }

  // ── Retailer key ──────────────────────────────────────────────────────────

  static Future<void> saveKey(String privateKey) async {
    await _ch.invokeMethod<bool>('setString', {
      'key': _retailerKey,
      'value': _encrypt(privateKey),
    });
  }

  static Future<String?> loadKey() async {
    final scrambled = await _ch.invokeMethod<String>('getString', _retailerKey);
    return scrambled != null ? _decrypt(scrambled) : null;
  }

  // ── Manufacturer key ──────────────────────────────────────────────────────

  static Future<void> saveManufacturerKey(String privateKey) async {
    await _ch.invokeMethod<bool>('setString', {
      'key': _manufacturerKey,
      'value': _encrypt(privateKey),
    });
  }

  static Future<String?> loadManufacturerKey() async {
    final scrambled =
        await _ch.invokeMethod<String>('getString', _manufacturerKey);
    return scrambled != null ? _decrypt(scrambled) : null;
  }
}