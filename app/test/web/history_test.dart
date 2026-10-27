// The browser's back in the phone's web app (iOS's edge swipe in a Home
// Screen app): the page keeps its own history entries, and a back is the
// app's back, never the browser leaving (and reloading) the page.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/platform.dart';
import 'package:web/web.dart' as web;

void main() {
  test('a back is the app’s, and the page stays', () async {
    final platform = PhonePlatform();
    var backs = 0;
    platform.onBack = () => backs++;
    final length = web.window.history.length;
    final href = web.window.location.href;
    for (var i = 1; i <= 3; i++) {
      web.window.history.back();
      for (var w = 0; w < 100 && backs < i; w++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(backs, i, reason: 'back $i reached the app');
    }
    // Still this page, and the history didn't grow with each back.
    expect(web.window.location.href, href);
    expect(web.window.history.length, length);
  });
}
