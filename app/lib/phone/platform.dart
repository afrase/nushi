// What the phone needs of the browser (ADR 0054): storage for its key and
// pairing, Web Push, the service worker, and whether it runs installed.
// The browser's in platform_web.dart; tests and the VM get platform_stub's,
// in memory.
export 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart';
