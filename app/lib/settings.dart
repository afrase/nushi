import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'daemon.dart';

/// What the app remembers across launches, in `app.json` in the data folder:
/// whether the details panel shows (its toolbar button), which of its cards
/// are collapsed, the repositories whose new chats get a worktree, and the
/// worktree chats whose changes show what's uncommitted, not the branch.
final showDetails = ValueNotifier<bool>(_saved['details'] != false)
  ..addListener(_save);
final collapsedCards = ValueNotifier<Set<String>>(_strings('collapsed'))
  ..addListener(_save);
final worktreeRepos = ValueNotifier<Set<String>>(_strings('worktrees'))
  ..addListener(_save);
final uncommittedChats = ValueNotifier<Set<String>>(_strings('uncommitted'))
  ..addListener(_save);

File get _settings => File('$dataDir/app.json');

final Map<String, Object?> _saved = () {
  try {
    return jsonDecode(_settings.readAsStringSync()) as Map<String, Object?>;
  } on Object {
    return <String, Object?>{};
  }
}();

Set<String> _strings(String key) => {
  ...?(_saved[key] as List?)?.whereType<String>(),
};

void _save() {
  try {
    _settings.writeAsStringSync(
      jsonEncode({
        'details': showDetails.value,
        'collapsed': collapsedCards.value.toList(),
        'worktrees': worktreeRepos.value.toList(),
        'uncommitted': uncommittedChats.value.toList(),
      }),
    );
  } on Object {
    // Not remembered; it still applies until the app quits.
  }
}
