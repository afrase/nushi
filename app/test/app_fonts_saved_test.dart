// The app's and code's fonts as `app.json` has them (ADR 0114): a family's
// name is read, and what can't be one (hand-edited, or another program's)
// reads as the bundled font, never an error and never a name to draw with.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

void main() {
  setUpAll(() {
    // Read before anything else is: the tests' own data folder.
    Directory(dataDir).createSync(recursive: true);
    File('$dataDir/app.json').writeAsStringSync(
      jsonEncode({
        'appFont': 'Avenir Next',
        'codeFont': 'Menlo\u001b]0;owned\u0007',
        'termFont': 'SF Mono',
      }),
    );
  });

  test('a saved family is read; one that can’t be a name is the bundled '
      'font', () {
    expect(appFont.value, 'Avenir Next');
    expect(codeFont.value, isNull);
    expect(terminalFont.value, 'SF Mono', reason: 'its own setting');
  });

  test('picking and clearing saves, the terminal’s left as it was', () async {
    codeFont.value = 'Menlo';
    appFont.value = null;
    await Future<void>.delayed(Duration.zero);
    final saved = readSaved();
    expect(saved['codeFont'], 'Menlo');
    expect(saved.containsKey('appFont'), isTrue);
    expect(saved['appFont'], isNull);
    expect(saved['termFont'], 'SF Mono');
  });
}
