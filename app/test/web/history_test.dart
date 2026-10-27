// The phone's web app and the browser's history (history.dart): the
// page's entry is the root, a screen's entry says its depth and nothing
// else, and a back (iOS's edge swipe) or a go reaches the app as the
// depth it landed on, the page staying.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/platform.dart';
import 'package:web/web.dart' as web;

void main() {
  test('entries by depth, at the page’s own address', () async {
    final href = web.window.location.href;
    final platform = PhonePlatform();
    final landed = <int>[];
    platform.onEntry = landed.add;
    Future<void> moved(int n) async {
      for (var w = 0; w < 100 && landed.length < n; w++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(landed, hasLength(n));
    }

    final length = web.window.history.length;
    platform
      ..pushEntry(1)
      ..pushEntry(2);
    expect(web.window.history.length, length + 2);
    expect(web.window.location.href, href, reason: 'no route in the address');
    web.window.history.back();
    await moved(1);
    expect(landed.last, 1);
    platform.go(-1);
    await moved(2);
    expect(landed.last, 0);
    // Still this page, and nothing pushed by the moves.
    expect(web.window.location.href, href);
    expect(web.window.history.length, length + 2);
  });
}
