import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

// An `app.json` that can't be read at all (its permissions, a disk error):
// never written over in that run, so nothing in it is lost.

const _kept = '{"details": false, "sidebarProjects": ["/a"]}';

File get _appJson => File('$dataDir/app.json');

/// Sets app.json's permissions ([setUpAll] runs before the native edge
/// is set up, so through chmod(1)).
void _chmod(String mode) => Process.runSync('chmod', [mode, _appJson.path]);

void main() {
  setUpAll(() {
    // As the app finds it at launch: there, and not the user's to read.
    _appJson.writeAsStringSync(_kept);
    _chmod('000');
  });
  tearDownAll(() => _chmod('600'));

  test('the prefs start from defaults, and a change is never saved over '
      'it', () async {
    expect(showDetails.value, isTrue);
    showDetails.value = false;
    sidebarProjects.value = {'/b'};
    await pumpEventQueue();
    _chmod('600');
    addTearDown(() => _chmod('000'));
    expect(_appJson.readAsStringSync(), _kept);
    expect(
      Directory(dataDir).listSync().map((f) => f.uri.pathSegments.last),
      isNot(contains(startsWith('app.json.'))),
    );
  });
}
