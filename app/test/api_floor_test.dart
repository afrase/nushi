// Gates expire by rule, not by memory (ADR 0004): a `const <name>Api`
// at or below apiFloor guards a daemon the app no longer works with, so
// it goes, with its old-daemon branch and test, when the floor passes it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';

/// The gates at or below the floor still to go, swept right after the
/// floor landed. This list must be empty once that sweep is done; from
/// then on, raising the floor makes this test name each gate it passes.
const _toGo = {
  'previewApi',
  'doneApi',
  'restartWhenIdleApi',
  'chatPullApi',
  'findFilesApi',
  'updatesApi',
  'rerunApi',
  'cleanUpApi',
  'pinApi',
  'forkApi',
  'chatColorApi',
  'relatedApi',
  'messagePinApi',
  'filesApi',
  'pinTitlesApi',
  'attachApi',
  'turnEndApi',
  'editApi',
  'serversApi',
  'searchSessionsApi',
  'installApi',
  'archiveSideApi',
  'githubItemsApi',
  'branchPullApi',
  'workflowApi',
};

void main() {
  test('no API gate is at or below the floor', () {
    final gate = RegExp(r'const (\w+Api) = (\d+);');
    final expired = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.startsWith('lib/gen/')) continue;
      for (final m in gate.allMatches(f.readAsStringSync())) {
        final (name, api) = (m[1]!, int.parse(m[2]!));
        if (api <= apiFloor && !_toGo.contains(name)) {
          expired.add('$name = $api (${f.path})');
        }
      }
    }
    expect(
      expired,
      isEmpty,
      reason:
          'at or below apiFloor ($apiFloor): delete each gate with its '
          'old-daemon branch and test',
    );
  });
}
