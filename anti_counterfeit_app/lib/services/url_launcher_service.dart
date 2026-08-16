import 'package:flutter/services.dart';

// Replaces the url_launcher package.
// Backed by UIApplication.open via a native MethodChannel.
const _ch = MethodChannel('com.blockguard.anticounterfeit/url_launcher');

/// Opens [url] in the default browser / handler.
/// Returns true if the URL was launched successfully.
Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
  return await _ch.invokeMethod<bool>('launch', url.toString()) ?? false;
}

/// Mirror of url_launcher's LaunchMode — values are ignored on the native
/// side (we always use externalApplication), but kept so existing call
/// sites compile without changes.
enum LaunchMode {
  platformDefault,
  inAppWebView,
  externalApplication,
  externalNonBrowserApplication,
}
