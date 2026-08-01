import 'package:flutter/services.dart';

class GalleryService {
  static const MethodChannel _channel =
      MethodChannel('com.example.anti_counterfeir_app/gallery');

  /// Saves the given [imageBytes] to the device's gallery.
  /// 
  /// Optionally provide a [filename] (e.g., 'my_qr_code.png').
  /// Returns `true` if the image was saved successfully, `false` otherwise.
  static Future<bool> saveImage(Uint8List imageBytes, {String? filename}) async {
    try {
      final result = await _channel.invokeMethod<bool>('saveImage', {
        'bytes': imageBytes,
        'filename': filename,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to save image to gallery: ${e.message}');
      return false;
    }
  }
}
