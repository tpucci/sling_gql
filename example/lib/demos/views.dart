/// The docs site runs every demo of a page in one Flutter engine, one view
/// per demo (multi-view embedding): the page adds a view per "Run" and says
/// which demo it shows in the view's initial data (`{demo: 'batching'}`).
///
/// Only the web build can be embedded; elsewhere there is always the one
/// implicit view, and [isEmbedded] is false.
library;

export 'views_io.dart' if (dart.library.js_interop) 'views_web.dart';
