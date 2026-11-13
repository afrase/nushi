import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

// An `app.json` a newer app (a beta, ADR 0108) wrote, read by this one:
// what it can't read stays in the file as it was, so going back to the
// beta finds the user's settings.

final _newer = <String, Object?>{
  // A key this app has no pref for.
  'sidebarDensity': {'rows': 'compact', 'gap': 2},
  // A value this app doesn't know, under keys it knows.
  'sidebarGroupBy': 'repository',
  'sidebarSort': 7,
  'sidebarShows': ['status', 'checks', 'time'],
  'appearance': 'sepia',
  'terminals': ['x', 3],
};

void main() {
  setUpAll(() {
    // Written before anything reads it: as the app finds it at launch.
    Directory(dataDir).createSync(recursive: true); // the tests' own
    File('$dataDir/app.json').writeAsStringSync(jsonEncode(_newer));
  });

  test('values this app can’t read are saved back as they were while '
      'the user leaves them', () async {
    // Read as this app's defaults…
    expect(sidebarGroupBy.value, GroupBy.project);
    expect(sidebarSort.value, SortBy.manual);
    expect(sidebarShows.value, {RowPart.status, RowPart.time});
    expect(terminalChats.value, {'x'});
    // …and kept as written when another pref is saved.
    showDetails.value = false;
    await pumpEventQueue();
    expect(readSaved(), {..._newer, 'details': false});
  });

  test('a value the user changes is saved as this app has it; a set keeps '
      'the names it doesn’t know', () async {
    sidebarGroupBy.value = GroupBy.date;
    sidebarShows.toggle(RowPart.agent);
    terminalChats.toggle('y');
    await pumpEventQueue();
    final saved = readSaved();
    expect(saved['sidebarGroupBy'], 'date');
    expect(
      saved['sidebarShows'],
      unorderedEquals(['status', 'time', 'agent', 'checks']),
    );
    expect(saved['terminals'], unorderedEquals(['x', 'y']));
    // The rest as they were.
    expect(saved['sidebarSort'], 7);
    expect(saved['appearance'], 'sepia');
    expect(saved['sidebarDensity'], _newer['sidebarDensity']);
  });

  test('a pref reset as at launch is saved as it was again', () async {
    // The test before changed them; resetAppSettings put them back.
    showDetails.value = true;
    await pumpEventQueue();
    expect(readSaved()['sidebarGroupBy'], 'repository');
    expect(readSaved()['sidebarShows'], _newer['sidebarShows']);
  });
}
