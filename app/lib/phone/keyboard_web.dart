import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:nushi/phone/keyboard.dart';
import 'package:web/web.dart' as web;

/// Keeps [inset] at the on-screen keyboard's height over the app's box,
/// from the visual viewport (iOS's keyboard shrinks it, not the layout
/// viewport the box is in), and keeps the page from scrolling: iOS scrolls
/// a focused field into view by moving the whole page, which would take
/// the app's top (its header) off the screen.
void watchKeyboard(ValueNotifier<double> inset) {
  final vv = web.window.visualViewport;
  final app = web.document.querySelector('#app');
  if (vv == null || app == null) return;
  void update() {
    final w = web.window;
    // Not while pinch-zoomed: then the page moves on purpose.
    if ((w.scrollX != 0 || w.scrollY != 0 || vv.offsetTop > 0) &&
        (vv.scale - 1).abs() < 0.01) {
      w.scrollTo(0.toJS, 0);
    }
    inset.value = keyboardInset(
      appBottom: app.getBoundingClientRect().bottom,
      viewportTop: vv.offsetTop,
      viewportHeight: vv.height,
    );
  }

  final listener = ((web.Event _) => update()).toJS;
  vv
    ..addEventListener('resize', listener)
    ..addEventListener('scroll', listener);
  web.window
    ..addEventListener('resize', listener)
    ..addEventListener('scroll', listener);
  update();
}
