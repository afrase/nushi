import 'package:flutter/widgets.dart';

import 'package:nushi/phone/page_frame_stub.dart'
    if (dart.library.js_interop) 'package:nushi/phone/page_frame_web.dart';

/// An HTML page (or an SVG) the agent wrote, on the phone: in an iframe
/// of the relay's `frame.html`, sandboxed to an origin of its own
/// (`allow-scripts` only: it can't reach the app, its storage or the
/// device's key) and served with a CSP of its own, so its scripts and the
/// network work there; the page's text goes in by postMessage. A
/// `srcdoc` or `blob:` frame would take the app's CSP, which runs no
/// inline script (WebKit, step 376). Its files beside it don't load.
class PageFrame extends StatelessWidget {
  const new(this.html, {super.key});

  final String html;

  @override
  Widget build(BuildContext context) => frameView(html);
}
