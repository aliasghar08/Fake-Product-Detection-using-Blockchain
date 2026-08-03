import 'package:flutter/services.dart';

class NativeShareService {
  // Define a unique channel name
  static const MethodChannel _channel = MethodChannel('com.anti_counterfeit/share');

  /// Calls the native OS to share a file located at [filePath]
  static Future<void> shareFile(String filePath, String text) async {
    try {
      await _channel.invokeMethod('shareImage', {
        'path': filePath,
        'text': text,
      });
    } on PlatformException catch (e) {
      throw Exception("Native sharing failed: '${e.message}'.");
    }
  }
}