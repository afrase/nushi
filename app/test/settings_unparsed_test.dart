import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

// An `app.json` that doesn't parse (a hand edit's typo, a file cut short):
// set aside whole, never written over, and the app starts from defaults.

const _bad = '{"details": false, "sidebarProjects": ["/a"]';

List<File> _aside() => [
  for (final f in Directory(dataDir).listSync().whereType<File>())
    if (f.uri.pathSegments.last.startsWith('app.json.unreadable-')) f,
];

void main() {
  setUpAll(() {
    // Written before anything reads it: as the app finds it at launch.
    File('$dataDir/app.json').writeAsStringSync(_bad);
  });

  test('it is set aside with its bytes, and a pref saved writes a new '
      'file beside it', () async {
    expect(showDetails.value, isTrue); // the default
    expect(sidebarProjects.value, isEmpty);
    expect(_aside().single.readAsStringSync(), _bad);

    showDetails.value = false;
    await pumpEventQueue();
    expect(readSaved()['details'], isFalse);
    expect(_aside().single.readAsStringSync(), _bad);
  });
}
