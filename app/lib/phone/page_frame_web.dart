import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// The relay serves it with its own headers (`relay/web.go`).
const _frame = 'frame.html';

Widget frameView(String html) => HtmlElementView.fromTagName(
  tagName: 'iframe',
  onElementCreated: (e) => setUpFrame(e as web.HTMLIFrameElement, html),
);

/// Makes [f] the frame of [html]: sandboxed to scripts only, loading
/// `frame.html`, and sent the page each time it loads (a reload brings
/// `frame.html` back, empty; the page itself ignores a second one).
void setUpFrame(web.HTMLIFrameElement f, String html) {
  f
    ..setAttribute('sandbox', 'allow-scripts')
    ..setAttribute('referrerpolicy', 'no-referrer')
    ..title = 'Preview';
  f.style
    ..border = 'none'
    ..width = '100%'
    ..height = '100%'
    ..backgroundColor = 'white';
  f
    ..addEventListener(
      'load',
      ((web.Event _) => f.contentWindow?.postMessage(html.toJS, '*'.toJS)).toJS,
    )
    ..src = _frame;
}
