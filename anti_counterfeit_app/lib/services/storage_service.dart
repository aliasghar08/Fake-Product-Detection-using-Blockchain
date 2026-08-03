import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Separate keys so Manufacturer and Retailer don't overwrite each other
  static const String _retailerKey = 'saved_retailer_key';
  static const String _manufacturerKey = 'saved_manufacturer_key';

  // This is your encryption keyword. Keep it secret!
  static const String _cipherSecret = 'fyp_sepolia_secret_2026';

  /// 1. ENCRYPTION ALGORITHM (XOR + Base64)
  static String _encrypt(String text) {
    List<int> textBytes = utf8.encode(text);
    List<int> keyBytes = utf8.encode(_cipherSecret);
    List<int> encryptedBytes = [];

    // Apply bitwise XOR operator to scramble the data
    for (int i = 0; i < textBytes.length; i++) {
      encryptedBytes.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    // Convert the scrambled bytes to a Base64 string for safe storage
    return base64.encode(encryptedBytes);
  }

  /// 2. DECRYPTION ALGORITHM
  static String _decrypt(String base64Text) {
    List<int> encryptedBytes = base64.decode(base64Text);
    List<int> keyBytes = utf8.encode(_cipherSecret);
    List<int> decryptedBytes = [];

    // Reverse the XOR operation to get the original data back
    for (int i = 0; i < encryptedBytes.length; i++) {
      decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(decryptedBytes);
  }

  // ==========================================
  // RETAILER KEY STORAGE
  // ==========================================
  static Future<void> saveKey(String privateKey) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Encrypt the key before saving it
    final scrambledKey = _encrypt(privateKey);
    await prefs.setString(_retailerKey, scrambledKey);
  }

  static Future<String?> loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final scrambledKey = prefs.getString(_retailerKey);

    if (scrambledKey == null) return null;

    // Decrypt the key before returning it to the text field
    return _decrypt(scrambledKey);
  }

  // ==========================================
  // MANUFACTURER KEY STORAGE
  // ==========================================
  static Future<void> saveManufacturerKey(String privateKey) async {
    final prefs = await SharedPreferences.getInstance();
    
    final scrambledKey = _encrypt(privateKey);
    await prefs.setString(_manufacturerKey, scrambledKey);
  }

  static Future<String?> loadManufacturerKey() async {
    final prefs = await SharedPreferences.getInstance();
    final scrambledKey = prefs.getString(_manufacturerKey);

    if (scrambledKey == null) return null;

    return _decrypt(scrambledKey);
  }
}