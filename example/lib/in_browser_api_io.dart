import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

/// Native platforms: the real network (see `in_browser_api.dart`).
http.Client mockApiHttpClient() => http.Client();

/// Whether requests are answered in-process rather than by `npm start`.
const bool mockApiInBrowser = false;

/// The machine running `npm start`, as this device sees it: the Android
/// emulator reaches its host at `10.0.2.2`; the iOS simulator (and
/// `flutter test` on the host) shares the host's network.
final String mockApiHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
