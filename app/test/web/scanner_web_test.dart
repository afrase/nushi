// The phone's QR scanner in the browser (ADR 0054), on a camera faked from
// a canvas's stream and jsQR's worker faked to answer at once: a frame
// that fails to read never stops the reading.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/scanner_web.dart';
import 'package:web/web.dart' as web;

@JS('eval')
external JSAny? _eval(String code);

/// The browser as the iPhone's Safari has it for Scan: no BarcodeDetector
/// (so jsQR's worker reads), a camera that's a canvas's stream, a worker
/// that answers each frame with no code, and a getImageData that throws
/// [failures] times first, counting its calls in `__reads`. Put back as
/// it was when the test ends.
void _fakeBrowser({required int failures}) {
  _eval('''
(() => {
  const saved = {
    detector: window.BarcodeDetector,
    worker: window.Worker,
    media: navigator.mediaDevices.getUserMedia,
    read: CanvasRenderingContext2D.prototype.getImageData,
  };
  window.__restore = () => {
    if (saved.detector) window.BarcodeDetector = saved.detector;
    window.Worker = saved.worker;
    navigator.mediaDevices.getUserMedia = saved.media;
    CanvasRenderingContext2D.prototype.getImageData = saved.read;
    clearInterval(window.__paint);
  };
  delete window.BarcodeDetector;
  window.Worker = class {
    postMessage() {
      setTimeout(() => this.onmessage && this.onmessage({data: null}), 0);
    }
    terminate() {}
  };
  const camera = document.createElement('canvas');
  camera.width = 64;
  camera.height = 48;
  const paint = camera.getContext('2d');
  let n = 0;
  window.__paint = setInterval(() => {
    paint.fillStyle = (n++ % 2) ? '#fff' : '#000';
    paint.fillRect(0, 0, 64, 48);
  }, 30);
  navigator.mediaDevices.getUserMedia =
      () => Promise.resolve(camera.captureStream(30));
  window.__reads = 0;
  let left = $failures;
  CanvasRenderingContext2D.prototype.getImageData = function (...a) {
    window.__reads++;
    if (left > 0) {
      left--;
      throw new DOMException('the frame was lost', 'InvalidStateError');
    }
    return saved.read.apply(this, a);
  };
})()
''');
}

int get _reads => web.window.getProperty<JSNumber>('__reads'.toJS).toDartInt;

void main() {
  test('a frame whose pixels fail to read is let go: the next ones are '
      'read', () async {
    _fakeBrowser(failures: 1);
    addTearDown(() => web.window.callMethod<JSAny?>('__restore'.toJS));
    final scanner = Scanner();
    addTearDown(scanner.stop);
    final video = web.HTMLVideoElement();
    web.document.body!.append(video);
    // An interop member can't be torn off.
    // ignore: unnecessary_lambdas
    addTearDown(() => video.remove());
    scanner.show(video);
    // What the scanner's frames let escape, which the test would fail on
    // before it could say what the reading did.
    final escaped = <Object>[];
    final started = runZonedGuarded(scanner.start, (e, _) => escaped.add(e));
    expect(await started, isNull);
    // The first read throws; reading goes on, a frame each 200 ms.
    final until = DateTime.now().add(const Duration(seconds: 10));
    while (_reads < 3 && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(_reads, greaterThanOrEqualTo(3), reason: 'reads $_reads');
    expect(escaped, isEmpty);
  });
}
