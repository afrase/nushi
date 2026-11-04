// The phone's theme in a real browser's IndexedDB (ADR 0086): kept, back
// after a reload (a new app on the same storage), and kept through Forget
// this Mac, as it's the device's own.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/platform.dart';

void main() {
  test(
    'the theme picked comes back after a reload and outlives Forget',
    () async {
      final platform = PhonePlatform();
      await platform.saveTheme('nord');
      expect(await PhonePlatform().loadTheme(), 'nord');
      await platform.clear(); // Forget this Mac
      expect(await PhonePlatform().loadTheme(), 'nord');
    },
  );
}
