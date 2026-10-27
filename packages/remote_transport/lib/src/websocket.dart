// A relay's WebSocket: dart:io's socket in apps and tests, the browser's
// WebSocket on the web.
export 'limits.dart';
export 'websocket_io.dart' if (dart.library.js_interop) 'websocket_web.dart';
