import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

/// Started with `multiViewEnabled: true`: no implicit view, the page adds
/// one per demo (see `views.dart`).
bool get isEmbedded => ui.PlatformDispatcher.instance.implicitView == null;

extension type _InitialData._(JSObject _) implements JSObject {
  external String? get demo;
}

/// The demo a view was added for (`addView({initialData: {demo: …}})`).
String? demoOfView(int viewId) {
  final data = ui_web.views.getInitialData(viewId);
  return data == null ? null : (data as _InitialData).demo;
}
