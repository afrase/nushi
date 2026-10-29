import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:nushi/phone/platform_web.dart' show trustedScriptUrl;
import 'package:web/web.dart' as web;

/// The camera scanning for a QR code (Scan on the pairing screen; ADR
/// 0054). The back camera's stream shows in a `<video>`; about five times
/// a second a frame (at most 800 pixels a side) goes to the browser's
/// BarcodeDetector where there is one, else to `qr_worker.js` (jsQR,
/// served from the app's own origin) off the page's thread. Frames are
/// read and dropped: nothing is kept or sent anywhere. [stop] ends the
/// stream, which turns the camera off.
final class Scanner {
  new();

  final _codes = StreamController<String>.broadcast();
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  web.Worker? _worker;
  JSObject? _detector;
  Timer? _timer;
  bool _busy = false;
  bool _stopped = false;
  final _canvas = web.HTMLCanvasElement();

  /// The text of each QR code it reads.
  Stream<String> get codes => _codes.stream;

  /// The camera's picture, filling its box.
  Widget view() => HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (o) {
      final v = _video = o as web.HTMLVideoElement
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', '');
      v.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover';
      _show();
    },
  );

  /// Asks for the camera (the browser asks the user the first time) and
  /// starts reading: null once it runs, else why it can't, in a sentence.
  Future<String?> start() async {
    final nav = web.window.navigator as JSObject;
    if (!nav.has('mediaDevices')) {
      return "This browser can't use the camera here: paste the link instead.";
    }
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: {
                'facingMode': {'ideal': 'environment'},
              }.jsify()!,
              audio: false.toJS,
            ),
          )
          .toDart;
      if (_stopped) {
        _end(stream);
        return null;
      }
      _stream = stream;
    } on Object catch (e) {
      return switch (_errorName(e)) {
        'NotAllowedError' || 'SecurityError' =>
          'Nushi may not use the camera. Allow it in Settings › Apps › '
              'Safari › Camera (or this site’s settings), or paste the link.',
        'NotFoundError' || 'OverconstrainedError' =>
          'No camera was found: paste the link instead.',
        'NotReadableError' =>
          'The camera is in use by another app: close it, then try again.',
        _ => "The camera didn't start: paste the link instead.",
      };
    }
    _show();
    if (web.window.has('BarcodeDetector')) {
      try {
        _detector = web.window
            .getProperty<JSFunction>('BarcodeDetector'.toJS)
            .callAsConstructor<JSObject>(
              {
                'formats': ['qr_code'],
              }.jsify(),
            );
      } on Object {
        _detector = null; // no QR support in it: the worker reads
      }
    }
    if (_detector == null) {
      _worker = web.Worker(trustedScriptUrl('qr_worker.js'))
        ..onmessage = ((web.MessageEvent e) {
          _busy = false;
          final text = e.data;
          if (text != null && text.isA<JSString>()) {
            _found((text as JSString).toDart);
          }
        }).toJS
        ..onerror = ((web.Event _) => _busy = false).toJS;
    }
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_frame()),
    );
    return null;
  }

  void _show() {
    final v = _video;
    final s = _stream;
    if (v == null || s == null) return;
    v.srcObject = s;
    v.play().toDart.ignore();
  }

  Future<void> _frame() async {
    final v = _video;
    if (_busy || _stopped || v == null || v.readyState < 2) return;
    final w = v.videoWidth;
    final h = v.videoHeight;
    if (w == 0 || h == 0) return;
    _busy = true;
    if (_detector case final d?) {
      try {
        final found = await d
            .callMethod<JSPromise<JSArray<JSObject>>>('detect'.toJS, v)
            .toDart;
        for (final code in found.toDart) {
          final raw = code['rawValue'];
          if (raw != null && raw.isA<JSString>()) {
            _found((raw as JSString).toDart);
          }
        }
      } on Object {
        // A frame it couldn't read: the next one.
      }
      _busy = false;
      return;
    }
    final scale = min(1, 800 / max(w, h));
    final cw = (w * scale).round();
    final ch = (h * scale).round();
    _canvas
      ..width = cw
      ..height = ch;
    final ctx =
        _canvas.getContext('2d', {'willReadFrequently': true}.jsify())!
              as web.CanvasRenderingContext2D
          ..drawImage(v, 0, 0, cw, ch);
    final pixels = ctx.getImageData(0, 0, cw, ch).data.toDart.buffer.toJS;
    final frame = JSObject()
      ..['data'] = pixels
      ..['width'] = cw.toJS
      ..['height'] = ch.toJS;
    // The pixels move to the worker, not copied.
    _worker?.postMessage(frame, [pixels].toJS);
  }

  void _found(String text) {
    if (!_stopped) _codes.add(text);
  }

  /// Turns the camera off and stops reading.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    _worker?.terminate();
    _worker = null;
    if (_stream case final s?) _end(s);
    _stream = null;
    _video?.srcObject = null;
    unawaited(_codes.close());
  }

  static void _end(web.MediaStream s) {
    for (final t in s.getTracks().toDart) {
      t.stop();
    }
  }

  static String _errorName(Object e) {
    try {
      return (e as web.DOMException).name;
    } on Object {
      return '';
    }
  }
}
