/// The HTTP client the example talks to the mock API with.
///
/// On iOS and Android: a plain `http.Client` to port 4000 of the host
/// (`npm start` in `mock-api/`; `localhost` from the iOS simulator,
/// `10.0.2.2` from the Android emulator, see [mockApiHost]). On the web: a client
/// that answers every request from the mock API bundled into the page
/// (`web/mock-api.js`, built by `npm run build:browser` in `mock-api/`), so
/// the web build needs no server and every tab has its own data.
///
/// Queries, mutations and SSE subscriptions all go through
/// `http.Client.send`, so swapping the client is the whole integration: the
/// `SlingClient` wiring in `main.dart` is the same on every platform.
library;

export 'in_browser_api_io.dart'
    if (dart.library.js_interop) 'in_browser_api_web.dart';
