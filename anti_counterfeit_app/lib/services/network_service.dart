import 'dart:io';

class NetworkService {
  /// Checks for actual internet access by attempting a DNS lookup.
  static Future<bool> hasInternetConnection() async {
    try {
      // Attempt to resolve a highly reliable domain
      final result = await InternetAddress.lookup('google.com');

      // If it successfully returns an IP address, the internet is working
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      // A SocketException is thrown if the network is down or DNS fails
      return false;
    }
    return false;
  }
}
