import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

File get _appJson => File('$dataDir/app.json');

/// An `app.json` with every key the app saves, none at its default, a key
/// from a newer app and an older app's `worktrees` and `subagentWide`.
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
  'sidebarProjects': ['/b', '/a', '/c'],
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
  'panes': {'details': 360.5, 'preview': 600.0},
  'termFont': 'Menlo',
  'termSize': 14.0,
  'appearance': 'dark',
  'theme': 'tokyo-night',
  'alertNeedsYou': false,
  'alertFinished': false,
  'alertFailed': false,
  'alertSound': true,
  'dockBadge': false,
  'wrap': false,
  'filesTree': false,
  'filesTreeSide': 'left',
  'previewTabs': false,
  'tabSize': 8,
  'indentGuides': false,
  'scrollPastEnd': true,
  'dismissedUpdate': '0.1.17',
  'shortcuts': {'nextTab': 'Shift+Cmd+]', 'x': 'bogus'},
  'fromANewerApp': {'kept': true},
  'worktrees': ['/a'],
  'subagentWide': true,
};

/// The older app's keys in [_saved], which the next save drops.
const _dropped = {'worktrees', 'subagentWide'};

/// Every pref, so each is read (made) before a save.
List<ValueNotifier<Object?>> get _all => [
  showDetails,
  collapsedWidgets,
  widgetOrder,
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
  sidebarProjects,
  sidebarChats,
  pinnedCollapsed,
  recentModels,
  chatOpened,
  pinnedFiles,
  pullSeen,
  cleanUpLater,
  paneWidths,
  terminalFont,
  terminalFontSize,
  appearance,
  colorTheme,
  alertNeedsYou,
  alertFinished,
  alertFailed,
  alertSound,
  dockBadge,
  wrapLines,
  filesTree,
  filesTreeSide,
  previewTabs,
  tabSize,
  indentGuides,
  scrollPastEnd,
  dismissedUpdate,
  shortcutKeys,
];

void main() {
  setUpAll(() {
    // Written before anything reads it: as the app finds it at launch.
    _appJson.writeAsStringSync(jsonEncode(_saved));
  });

  test("every key read and saved back as it was; a newer app's key stays, "
      "old keys go; only the user's (0600)", () async {
    expect(showDetails.value, isFalse);
    expect(terminalChats.value, {'x', 'y'});
    // The details panel's width is fixed now (ADR 0092): an older one goes.
    // The preview's, from when files and browser tabs shared it, is the
    // browser's (ADR 0094).
    expect(paneWidths.value, {'browser': 600});
    expect(terminalFontSize.value, 14);
    expect(githubDays.value, 30);
    expect(dismissedUpdate.value, '0.1.17');
    expect(wrapLines.value, isFalse);
    expect(filesTree.value, isFalse);
    expect(filesTreeSide.value, TreeSide.left);
    expect(previewTabs.value, isFalse);
    expect(tabSize.value, 8);
    expect(indentGuides.value, isFalse);
    expect(scrollPastEnd.value, isTrue);
    // A built-in named by its id is the theme shown (ADR 0086).
    expect(colorTheme.value, 'tokyo-night');
    expect(_all.map((p) => p.value), hasLength(48)); // each made
    showDetails.value = true;
    await pumpEventQueue();
    // A pref this file's other tests read that wasn't in the file (the
    // chats' own, when one of them ran first) is saved too, as it is by
    // default: what's compared is every key that was there.
    final saved = readSaved();
    final expected = {
      ...(Map.of(_saved)
        ..remove('worktrees')
        ..remove('subagentWide')),
      'details': true,
      'panes': {'browser': 600.0},
    };
    expect({
      for (final key in saved.keys)
        if (expected.containsKey(key) || _dropped.contains(key))
          key: saved[key],
    }, expected);
    expect(_appJson.statSync().mode & 0x1ff, 0x180);
  });

  test("the preview's width is the browser's unless it has its own; the "
      "Changes list's stays", () {
    expect(readPaneWidths({'preview': 640}), {'browser': 640});
    expect(readPaneWidths({'preview': 640, 'browser': 500, 'files': 333}), {
      'browser': 500,
      'files': 333,
    });
    expect(readPaneWidths('x'), isEmpty);
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
    forgetChats({'x', 'y'});
    expect(chatsKept(), isEmpty);
    appearance.value = ThemeMode.light;
    resetAppSettings(); // as before every test
    expect(chatsKept(), {'x', 'y'});
    expect(appearance.value, ThemeMode.dark);
  });
}
