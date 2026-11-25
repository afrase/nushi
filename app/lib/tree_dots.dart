import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/marks_base.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/tree_rows.dart';

/// How long the dots wait after a change before asking again, so a burst
/// of them (a save, a listing, a turn's end) asks once.
const Duration treeDotsWait = Waits.typing;

/// The Files tree's dots for a chat (ADR 0131): the files that differ from
/// the base its change marks count from ([marksBaseOf], one lookup for
/// both), added, changed, renamed or new and untracked, whoever changed
/// them, and the folders holding them, so a dot and a file's marks always
/// agree. Asked of the daemon by name alone (GetDiff's `names`: no
/// texts) when a pane showing the tree starts, then a
/// moment after one of its listings changes, a shown file's marks change,
/// the chat's turn ends, it commits, or its folder or worktree changes;
/// never while no pane shows the tree. A folder outside git keeps the
/// files the chat wrote ([writtenMarks]):
/// there's nothing to compare with.
final class TreeDots extends ChangeNotifier {
  new _(this.chat);

  final ChatState chat;

  Daemon? _daemon;
  int _users = 0;
  Timer? _soon;
  int _asked = 0; // only the latest question's answer lands

  /// The files git lists as differing, or null where git can't say.
  Set<String>? _files;
  Set<String> _folders = const {};

  /// The files dotted and the folders holding them.
  ({Set<String> files, Set<String> folders}) get marks => switch (_files) {
    final files? => (files: files, folders: _folders),
    null => writtenMarks(chat),
  };

  /// Whether the dots are git's: false while they're the files the chat
  /// wrote (no repository, an old daemon, or no answer yet).
  bool get fromGit => _files != null;

  /// Starts asking, for a pane that shows the tree.
  void attach(Daemon daemon) {
    _daemon = daemon;
    if (_users++ > 0) return;
    marksBaseOf(chat).addListener(poke);
    folderTreeOf(chat).heard.addListener(poke);
    unawaited(_ask());
  }

  /// Stops asking when no pane shows the tree.
  void detach() {
    if (--_users > 0) return;
    marksBaseOf(chat).removeListener(poke);
    folderTreeOf(chat).heard.removeListener(poke);
    _soon?.cancel();
    _asked++; // an answer on its way is dropped
  }

  /// Asks again in a moment ([treeDotsWait]), while a pane shows the tree.
  void poke() {
    if (_users == 0) return;
    _soon?.cancel();
    _soon = Timer(treeDotsWait, () => unawaited(_ask()));
  }

  Future<void> _ask() async {
    final daemon = _daemon;
    if (daemon == null) return;
    final asked = ++_asked;
    final folder = chat.folder;
    Future<GetDiffResponse> names(String base) => daemon.client.getDiff(
      GetDiffRequest(folder: folder, base: base, names: true),
    );
    try {
      final found = await marksBaseOf(chat).find(daemon);
      if (asked != _asked) return;
      GetDiffResponse r;
      try {
        r = await names(found.base);
      } on Object {
        // As a file's marks do: a base this repository lacks counts from
        // its last commit.
        if (found.base.isEmpty) rethrow;
        r = await names('');
      }
      _land(asked, {
        for (final f in r.files)
          if (f.status != 'deleted') f.path,
      });
    } on Object catch (e) {
      // Not a repository: the files the chat wrote. Anything else (the
      // daemon away a moment): the dots stay as they were.
      if (e is ConnectException &&
          e.code == Code.failedPrecondition &&
          RegExp('not (in )?a git repository').hasMatch(e.message)) {
        _land(asked, null);
      }
    }
  }

  void _land(int asked, Set<String>? files) {
    if (asked != _asked) return;
    if (setEquals(files, _files)) return;
    _files = files;
    _folders = files == null ? const {} : foldersOf(files);
    notifyListeners();
  }
}

final _dots = Expando<TreeDots>();

/// [chat]'s tree dots, made the first time they're asked for.
TreeDots treeDotsOf(ChatState chat) => _dots[chat] ??= TreeDots._(chat);

/// What row [r]'s dot says in its tooltip, by [marks] ([TreeDots.marks]),
/// [git] being [TreeDots.fromGit]; null for no dot.
String? dotWords(
  TreeRow r,
  ({Set<String> files, Set<String> folders}) marks, {
  required bool git,
}) {
  final folder = r.kind == TreeRowKind.folder;
  if (!(folder ? marks.folders : marks.files).contains(r.path)) return null;
  return switch ((git, folder)) {
    (true, true) => 'holds changed files',
    (true, false) => 'changed',
    (false, true) => 'holds files the chat wrote',
    (false, false) => 'the chat wrote it',
  };
}
