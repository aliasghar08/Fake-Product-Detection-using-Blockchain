import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _storageKey = 'saved_private_key';

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

  /// 3. SAVE TO LOCAL DEVICE
  static Future<void> saveKey(String privateKey) async {
    final prefs = await SharedPreferences.getInstance();

    // Encrypt the key before saving it
    final scrambledKey = _encrypt(privateKey);
    await prefs.setString(_storageKey, scrambledKey);
  }

  /// 4. LOAD FROM LOCAL DEVICE
  static Future<String?> loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final scrambledKey = prefs.getString(_storageKey);

    if (scrambledKey == null) return null;

    // Decrypt the key before returning it to the text field
    return _decrypt(scrambledKey);
  }
}
