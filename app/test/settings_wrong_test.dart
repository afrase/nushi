import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/settings.dart';

/// Values of every JSON type, each the wrong one for some pref.
const _wrong = <Object?>[
  'wrong',
  7,
  2.5,
  true,
  ['x', 3],
  {'x': 'wrong', 'y': 3},
];

void main() {
  test('every pref is in allPrefs, once', () {
    // A top-level pref declaration in settings.dart: `final … = Pref(`, or
    // one of its makers.
    final declared = RegExp(
      r'^final (?:Pref<.*> )?\w+ = (?:Pref|_plain|_set|_list|_places|_byChat)\b',
      multiLine: true,
    ).allMatches(File('lib/settings.dart').readAsStringSync());
    expect(allPrefs, hasLength(declared.length));
    expect({for (final p in allPrefs) p}, hasLength(allPrefs.length));
    final keys = [for (final p in allPrefs) p.key];
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('a value of any wrong type reads as something, never an error', () {
    for (final p in allPrefs) {
      for (final v in _wrong) {
        expect(() => p.readFrom({p.key: v}), returnsNormally, reason: p.key);
      }
    }
  });

  test('a key of the wrong type reads as the default, never an error', () {
    // An app.json whose every key has the wrong type (another app's, or
    // hand-edited), as a launch reads it.
    final saved = {
      for (final p in allPrefs) p.key: p.key.endsWith('Font') ? 7 : 'wrong',
    };
    for (final p in allPrefs) {
      p.readFrom(saved);
    }
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
    expect(sidebarProjects.value, isEmpty);
    expect(chatOpened.value, isEmpty);
    expect(pinnedFiles.value, isEmpty);
    expect(pullSeen.value, isEmpty);
    expect(cleanUpLater.value, isEmpty);
    expect(paneWidths.value, isEmpty);
    expect(terminalFont.value, isNull);
    expect(terminalFontSize.value, 12.5);
    expect(appFont.value, isNull);
    expect(codeFont.value, isNull);
    expect(appearance.value, ThemeMode.system);
    expect(alertNeedsYou.value, isTrue);
    expect(alertSound.value, isFalse);
    expect(chatsKept(), isEmpty);
    // The Files pane's.
    expect(filesChats.value, isEmpty);
    expect(filesIgnored.value, isFalse);
    expect(filesTree.value, isTrue);
    expect(filesTreeSide.value, TreeSide.automatic);
    expect(previewTabs.value, isTrue);
    expect(tabSize.value, 4);
    expect(indentGuides.value, isTrue);
    expect(scrollPastEnd.value, isFalse);
    expect(wrapLines.value, isTrue);
    expect(showWhitespace.value, isFalse);
    expect(shortcutKeys.value, isEmpty);
  });
}
