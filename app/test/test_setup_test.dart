import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/native.dart';

import 'fake_desktop.dart';

// What every test starts with (flutter_test_config.dart's setUp).

void main() {
  test('nothing a test does opens on the desktop', () async {
    expect(native.desktop, isA<FakeDesktop>());
    await native.desktop.reveal('/Users/me/nushi/README.md');
    expect(fakeDesktop(), [
      ['-R', '/Users/me/nushi/README.md'],
    ]);
  });

  test('the next test’s file manager was asked nothing', () {
    expect(fakeDesktop(), isEmpty);
  });
}
