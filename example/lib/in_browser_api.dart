/// The HTTP client the example talks to the mock API with.
///
/// On iOS: a plain `http.Client` to `localhost:4000` (`npm start` in
/// `mock-api/`; the simulator shares the host network). On the web: a client
/// that answers every request from the mock API bundled into the page
/// (`web/mock-api.js`, built by `npm run build:browser` in `mock-api/`), so
/// the web build needs no server and every tab has its own data.
///
/// Queries, mutations and SSE subscriptions all go through
/// `http.Client.send`, so swapping the client is the whole integration: the
/// `SlingClient` wiring in `main.dart` is the same on both platforms.
library;

export 'in_browser_api_io.dart'
    if (dart.library.js_interop) 'in_browser_api_web.dart';
