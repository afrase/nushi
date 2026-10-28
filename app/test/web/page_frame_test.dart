// The phone's frame for an agent's page (page_frame_web.dart).
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/page_frame_web.dart';
import 'package:web/web.dart' as web;

void main() {
  test('a page in a sandboxed frame of frame.html', () {
    final f = web.HTMLIFrameElement();
    setUpFrame(f, '<h1>hi</h1>');
    // Scripts, but no origin of the app's: no allow-same-origin.
    expect(f.getAttribute('sandbox'), 'allow-scripts');
    expect(f.sandbox.contains('allow-same-origin'), isFalse);
    expect(Uri.parse(f.src).path, endsWith('/frame.html'));
    expect(f.getAttribute('srcdoc'), isNull);
  });
}
