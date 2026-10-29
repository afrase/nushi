import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

File get _appJson => File('$dataDir/app.json');

/// An `app.json` with every key the app saves, none at its default, a key
/// from a newer app and an older app's `worktrees`.
final _saved = <String, Object?>{
  'details': false,
  'collapsed': ['Context'],
  'cards': ['Changes', 'Context'],
  'scopes': {'x': 'branch', 'y': 'commits'},
  'flat': true,
  'terminals': ['x', 'y'],
  'jiraSite': 'acme.atlassian.net',
  'jiraGroups': {
    '*': ['Done', 'To Do'],
  },
  'jiraCollapsed': {
    '*': ['Done'],
  },
  'jiraAssignee': {
    'acme mine': ['me'],
  },
  'githubTeams': true,
  'githubCards': ['mine', 'review'],
  'githubCollapsed': ['assigned'],
  'githubDays': 30,
  'githubHidden': {
    'github.com': ['octo/old'],
  },
  'githubOwners': {
    'github.com': ['octo'],
  },
  'githubFindings': true,
  'githubFindingBots': 'review-bot',
  'githubFindingHeadings': 'Blockers',
  'sidebarOrder': ['/b', '/a'],
  'sidebarCollapsed': ['/a'],
  'sidebarChats': {
    '/a': ['y', 'x'],
  },
  'pinnedCollapsed': true,
  'models': ['opus', 'sonnet'],
  'opened': {'x': 1000, 'y': 2000},
  'pins': {
    'x': ['notes.md'],
    'y': ['plan.md'],
  },
  'pullSeen': {'x': 3000, 'y': 4000},
  'cleanUpLater': ['x', 'y'],
  'panes': {'details': 360.5},
  'subagentWide': true,
  'termFont': 'Menlo',
  'termSize': 14.0,
  'appearance': 'dark',
  'alertNeedsYou': false,
  'alertFinished': false,
  'alertFailed': false,
  'alertSound': true,
  'dockBadge': false,
  'dismissedUpdate': '0.1.17',
  'fromANewerApp': {'kept': true},
  'worktrees': ['/a'],
};

/// Every pref, so each is read (made) before a save.
List<ValueNotifier<Object?>> get _all => [
  showDetails,
  collapsedCards,
  cardOrder,
  changeScopes,
  changesFlat,
  terminalChats,
  lastJiraSite,
  jiraGroupOrder,
  jiraCollapsed,
  jiraAssignee,
  githubTeamReviews,
  githubCardOrder,
  githubCollapsed,
  githubDays,
  githubHidden,
  githubOwners,
  githubFindings,
  githubFindingBots,
  githubFindingHeadings,
  sidebarOrder,
  sidebarCollapsed,
  sidebarChats,
  pinnedCollapsed,
  recentModels,
  chatOpened,
  pinnedFiles,
  pullSeen,
  cleanUpLater,
  paneWidths,
  subagentWide,
  terminalFont,
  terminalFontSize,
  appearance,
  alertNeedsYou,
  alertFinished,
  alertFailed,
  alertSound,
  dockBadge,
  dismissedUpdate,
];

void main() {
  setUpAll(() {
    // Written before anything reads it: as the app finds it at launch.
    Directory(dataDir).createSync(recursive: true); // the tests' own
    _appJson.writeAsStringSync(jsonEncode(_saved));
  });

  test("every key read and saved back as it was; a newer app's key stays, "
      "the old worktrees goes; only the user's (0600)", () async {
    expect(showDetails.value, isFalse);
    expect(terminalChats.value, {'x', 'y'});
    expect(paneWidths.value, {'details': 360.5});
    expect(terminalFontSize.value, 14);
    expect(githubDays.value, 30);
    expect(dismissedUpdate.value, '0.1.17');
    expect(_all.map((p) => p.value), hasLength(39)); // each made
    showDetails.value = true;
    await pumpEventQueue();
    expect(readSaved(), {
      ...(Map.of(_saved)..remove('worktrees')),
      'details': true,
    });
    expect(_appJson.statSync().mode & 0x1ff, 0x180);
  });

  test('a chat forgotten from every pref kept by chat, in one go', () {
    expect(chatsKept(), {'x', 'y'});
    forgetChats({'x'});
    expect(chatsKept(), {'y'});
    expect(changeScopes.value, {'y': 'commits'});
    expect(sidebarChats.value, {
      '/a': ['y'],
    });
    expect(pullSeen.value, {'y': 4000});
    forgetChats({'y', 'z'});
    expect(chatsKept(), isEmpty);
  });

  test('each test starts with the prefs as at launch', () {
    // The test before forgot both chats.
    expect(chatsKept(), {'x', 'y'});
    appearance.value = ThemeMode.light;
    resetAppSettings();
    expect(appearance.value, ThemeMode.dark);
  });
}
