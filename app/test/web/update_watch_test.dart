// The phone's "Nushi was updated" (platform_web.dart's watchUpdates), on
// a registration and workers made of plain event targets: their states
// change as a browser's do.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/platform_web.dart';
import 'package:web/web.dart' as web;

/// A worker in [state].
web.ServiceWorker _worker(String state) =>
    (web.EventTarget() as JSObject..['state'] = state.toJS)
        as web.ServiceWorker;

/// A registration with these workers.
web.ServiceWorkerRegistration _reg({
  web.ServiceWorker? installing,
  web.ServiceWorker? waiting,
  web.ServiceWorker? active,
}) =>
    (web.EventTarget() as JSObject
          ..['installing'] = installing
          ..['waiting'] = waiting
          ..['active'] = active)
        as web.ServiceWorkerRegistration;

/// Moves [w] to [state] in [reg]'s [slot], as the browser does, and says so.
void _move(
  web.ServiceWorkerRegistration reg,
  web.ServiceWorker w,
  String state,
  String slot,
) {
  for (final s in ['installing', 'waiting', 'active']) {
    if ((reg as JSObject)[s] == w) reg[s] = null;
  }
  (reg as JSObject)[slot] = w;
  (w as JSObject)['state'] = state.toJS;
  w.dispatchEvent(web.Event('statechange'));
}

void main() {
  test('a fresh install is no update', () {
    final w = _worker('installing');
    final reg = _reg(installing: w);
    final ready = ValueNotifier(false);
    watchUpdates(reg, ready);
    _move(reg, w, 'installed', 'waiting');
    _move(reg, w, 'activating', 'active');
    _move(reg, w, 'activated', 'active');
    expect(ready.value, isFalse);
  });

  test('a newer version installed beside the running one is', () {
    final running = _worker('activated');
    final reg = _reg(active: running);
    final ready = ValueNotifier(false);
    watchUpdates(reg, ready);
    final next = _worker('installing');
    (reg as JSObject)['installing'] = next;
    reg.dispatchEvent(web.Event('updatefound'));
    expect(ready.value, isFalse);
    _move(reg, next, 'installed', 'waiting');
    expect(ready.value, isTrue);
  });

  test('one already waiting at launch is', () {
    final ready = ValueNotifier(false);
    watchUpdates(
      _reg(waiting: _worker('installed'), active: _worker('activated')),
      ready,
    );
    expect(ready.value, isTrue);
  });
}
