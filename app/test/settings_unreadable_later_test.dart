import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

// An `app.json` that couldn't be read at launch but can later (a passing
// disk error, permissions put right): the next save reads it first, so
// what changed this run is saved over what it held, not lost at quit.

const _kept = '{"details": false, "flat": true, "sidebarProjects": ["/a"]}';

File get _appJson => File('$dataDir/app.json');

/// Sets app.json's permissions ([setUpAll] runs before the native edge
/// is set up, so through chmod(1)).
void _chmod(String mode) => Process.runSync('chmod', [mode, _appJson.path]);

void main() {
  setUpAll(() {
    _appJson.writeAsStringSync(_kept);
    _chmod('000');
  });
  tearDownAll(() => _chmod('600'));

  test('once it reads, a change is saved over it and the prefs not '
      'changed take what it holds', () async {
    expect(showDetails.value, isTrue); // couldn't be read: the default
    expect(changesFlat.value, isFalse);
    sidebarProjects.value = {'/b'};
    await pumpEventQueue();
    _chmod('600');
    expect(_appJson.readAsStringSync(), _kept); // not yet written over

    diffUnified.value = true;
    await pumpEventQueue();
    final saved = jsonDecode(_appJson.readAsStringSync());
    expect(saved, {
      'details': false,
      'flat': true,
      'sidebarProjects': ['/b'],
      'unified': true,
    });
    expect(showDetails.value, isFalse);
    expect(changesFlat.value, isTrue);
    expect(sidebarProjects.value, {'/b'});
  });
}
