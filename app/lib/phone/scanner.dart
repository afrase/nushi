// The camera scanning for a QR code (Scan on the pairing screen): the
// browser's in scanner_web.dart, a stand-in for tests in scanner_stub.dart.
export 'scanner_stub.dart' if (dart.library.js_interop) 'scanner_web.dart';
