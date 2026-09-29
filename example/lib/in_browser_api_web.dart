import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Web: requests answered by the mock API running in this page (see
/// `in_browser_api.dart`).
http.Client mockApiHttpClient() => InBrowserMockApiClient();

/// Whether requests are answered in-process rather than by `npm start`.
const bool mockApiInBrowser = true;

/// `globalThis.slingMockApi`, set by `web/mock-api.js` (`mock-api/browser.mjs`).
@JS('slingMockApi')
external _MockApi? get _mockApi;

extension type _MockApi._(JSObject _) implements JSObject {
  /// graphql-yoga's `fetch(url, init)`: a Fetch API `Response`, whose body
  /// streams for `text/event-stream`.
  external JSPromise<web.Response> fetch(String url, web.RequestInit init);
}

/// An `http.Client` over the in-page mock API. The response body is streamed
/// chunk by chunk from the `Response`'s `ReadableStream`, so SSE
/// subscriptions work as they do over the network; cancelling the body stream
/// cancels the reader, which ends the subscription on the "server".
class InBrowserMockApiClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final api = _mockApi;
    if (api == null) {
      throw http.ClientException(
        'web/mock-api.js is not loaded: run `npm run build:browser` in '
        'mock-api/ before `flutter run -d chrome`.',
        request.url,
      );
    }
    final body = await request.finalize().toBytes();
    final headers = web.Headers();
    request.headers.forEach((name, value) => headers.append(name, value));
    final response = await api
        .fetch(
          request.url.toString(),
          web.RequestInit(
            method: request.method,
            headers: headers,
            body: body.isEmpty ? null : body.toJS,
          ),
        )
        .toDart;
    final contentType = response.headers.get('content-type');
    return http.StreamedResponse(
      _bodyOf(response),
      response.status,
      headers: {'content-type': ?contentType},
      reasonPhrase: response.statusText,
      request: request,
    );
  }
}

Stream<List<int>> _bodyOf(web.Response response) {
  final body = response.body;
  if (body == null) return const Stream.empty();
  final reader = body.getReader() as web.ReadableStreamDefaultReader;
  var cancelled = false;
  late final StreamController<List<int>> controller;

  Future<void> pump() async {
    try {
      while (!cancelled) {
        final chunk = await reader.read().toDart;
        if (chunk.done || cancelled) break;
        controller.add((chunk.value as JSUint8Array).toDart);
      }
    } catch (e, st) {
      if (!cancelled) controller.addError(e, st);
    }
    if (!cancelled) await controller.close();
  }

  controller = StreamController<List<int>>(
    onListen: pump,
    onCancel: () async {
      cancelled = true;
      await reader.cancel().toDart;
    },
  );
  return controller.stream;
}
