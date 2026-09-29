import 'package:http/http.dart' as http;

/// Native platforms: the real network (see `in_browser_api.dart`).
http.Client mockApiHttpClient() => http.Client();

/// Whether requests are answered in-process rather than by `npm start`.
const bool mockApiInBrowser = false;
