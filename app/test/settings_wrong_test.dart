import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

void main() {
  setUpAll(() {
    // An app.json whose every key has the wrong type (another app's, or
    // hand-edited): read before anything else is.
    Directory(dataDir).createSync(recursive: true); // the tests' own
    File('$dataDir/app.json').writeAsStringSync(
      jsonEncode({
        for (final key in [
          'details', 'collapsed', 'cards', 'scopes', 'flat', 'terminals', //
          'jiraSite', 'jiraGroups', 'jiraCollapsed', 'jiraAssignee',
          'githubTeams', 'githubCards', 'githubCollapsed', 'githubDays',
          'githubHidden', 'githubOwners', 'githubFindings',
          'githubFindingBots', 'githubFindingHeadings', 'sidebarOrder',
          'sidebarCollapsed', 'sidebarChats', 'pinnedCollapsed', 'models',
          'opened', 'pins', 'pullSeen', 'cleanUpLater', 'panes',
          'subagentWide', 'termFont', 'termSize', 'appearance',
          'alertNeedsYou', 'alertFinished', 'alertFailed', 'alertSound',
          'dockBadge', 'dismissedUpdate',
        ])
          key: key == 'termFont' ? 7 : 'wrong',
      }),
    );
  });

  test('a key of the wrong type reads as the default, never an error', () {
    expect(showDetails.value, isTrue);
    expect(collapsedWidgets.value, isEmpty);
    expect(widgetOrder.value, isEmpty);
    expect(changeScopes.value, isEmpty);
    expect(changesFlat.value, isFalse);
    expect(terminalChats.value, isEmpty);
    expect(lastJiraSite.value, 'wrong'); // a string, as it should be
    expect(jiraGroupOrder.value, isEmpty);
    expect(githubDays.value, 90);
    expect(githubFindingBots.value, 'wrong');
    expect(sidebarChats.value, isEmpty);
    expect(chatOpened.value, isEmpty);
    expect(pinnedFiles.value, isEmpty);
    expect(pullSeen.value, isEmpty);
    expect(cleanUpLater.value, isEmpty);
    expect(paneWidths.value, isEmpty);
    expect(terminalFont.value, isNull);
    expect(terminalFontSize.value, 12.5);
    expect(appearance.value, ThemeMode.system);
    expect(alertNeedsYou.value, isTrue);
    expect(alertSound.value, isFalse);
    expect(chatsKept(), isEmpty);
  });
}
