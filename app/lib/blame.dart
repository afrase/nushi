import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_changes.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/line_changes.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview.dart' show FileWatch;

// Who last changed each line of a file the Files pane shows (issue #78):
// asked of the daemon (GetBlame) while the file's Blame is on, again as
// the file changes or the chat commits, and laid on the lines shown, an
// editor's unsaved ones too.

/// Why a file shows no blame, in the words its path row says: the change
/// marks' words where they have them (`NoMarks`), and [tip] its tooltip.
enum NoBlame {
  notRepository(
    'Not in a git repository',
    'Blame comes from git, and this folder has no repository',
  ),
  ignored(
    'Ignored by git',
    'Git ignores it (.gitignore), so has no history of it',
  ),
  untracked(
    'Not committed yet',
    'Git doesn’t track it yet, so no line of it has a commit',
  ),
  isNew('New file: not committed yet', 'It’s staged, but no commit has it yet'),
  link('A link: no blame', 'A symbolic link: git keeps the link, not the file'),
  binary('Not text: no blame', 'Only text has blame'),
  tooLarge('Too large for blame', 'Blame stops at 1 MiB'),
  tooManyLines('Over 10,000 lines: no blame', 'Blame stops at 10,000 lines'),

  /// The app's own: the view shows the file other than as saved (JSON
  /// pretty-printed), so git's lines aren't the lines shown.
  reformatted(
    'Shown reformatted: no blame',
    'The file is shown reformatted here, so its lines aren’t the saved ones',
  ),
  failed('Couldn’t blame', '');

  new(this.label, this.tip);
  final String label;
  final String tip;

  /// The daemon's `none_reason` (GetBlameResponse) as one of these.
  static NoBlame of(String reason) => switch (reason) {
    'not a repository' => notRepository,
    'ignored' => ignored,
    'untracked' => untracked,
    'new' => isNew,
    'a link' => link,
    'binary' => binary,
    'too large' => tooLarge,
    'too many lines' => tooManyLines,
    _ => failed,
  };
}

/// An answer of GetBlame: its [runs] and the [text] they are of (the file
/// as the app had it when it asked). No runs: none yet, or none to have.
@immutable
final class Blamed {
  const new(this.runs, this.text);

  final List<BlameRun> runs;
  final String text;

  /// Nothing yet.
  static const nothing = Blamed([], '');
}

/// A shown file's blame ([value]; null while its Blame is off), and what
/// its path row says of it: a quiet "Blaming…" while the first answer takes
/// a moment ([slow]), or why there is none ([none]). It asks only while
/// Blame is on for the file's tab (`FileTabs.blamed`), as it turns on, as
/// the file changes on disk, and as the chat's folder may have moved (a
/// turn ended, it committed: `ChatChanges.baseMoved`), as the change marks
/// do (`LineBase`).
class FileBlame extends ChangeNotifier implements ValueListenable<Blamed?> {
  new(this.daemon, this.chat, this.watch, this.path) {
    _on = chat.files.blamed.value.contains(path);
    _changes = ChatChanges.of(daemon, chat);
    chat.files.blamed.addListener(_switched);
    watch.addListener(_fileChanged);
    _changes.baseMoved.addListener(_moved);
    if (_on) unawaited(ask());
  }

  final Daemon daemon;
  final ChatState chat;
  final FileWatch watch;

  /// The file, as its tab names it.
  final String path;

  late final ChatChanges _changes;
  bool _on = false;
  Blamed _blamed = Blamed.nothing;
  NoBlame? _none;
  String _error = '';
  bool _loaded = false;
  bool _slow = false;
  Timer? _slowly;
  String? _sha;
  int _asked = 0; // only the latest question's answer lands
  bool _disposed = false;

  /// Whether its Blame is on.
  bool get on => _on;

  @override
  Blamed? get value => _on ? _blamed : null;

  /// Why there is no blame, once asked.
  NoBlame? get none => _on ? _none : null;

  /// The daemon's words, when asking it failed ([NoBlame.failed]).
  String get error => _error;

  /// Whether the first answer is taking more than a moment ([Waits.slow]).
  bool get slow => _on && _slow && !_loaded;

  /// Turns its Blame on or off, for as long as its tab is open.
  void turn({required bool on}) => chat.files.blame(path, on: on);

  void _switched() {
    final on = chat.files.blamed.value.contains(path);
    if (on == _on) return;
    _on = on;
    _slowly?.cancel();
    _slowly = null;
    _slow = false;
    _loaded = false;
    _blamed = Blamed.nothing;
    _none = null;
    _error = '';
    _asked++; // an answer under way is of before
    notifyListeners();
    if (on) unawaited(ask());
  }

  void _fileChanged() {
    final f = watch.file;
    final sha = f == null || f.missing
        ? null
        : f.tooLarge
        ? 'too large'
        : f.sha256;
    if (sha == _sha) return;
    _sha = sha;
    if (_on) unawaited(ask());
  }

  void _moved() {
    if (_on) unawaited(ask());
  }

  /// Asks the daemon again who last changed each line.
  Future<void> ask() async {
    if (!_on) return;
    final asked = ++_asked;
    final f = watch.file;
    if (f == null || f.missing) return;
    if (!_loaded) {
      _slowly ??= Timer(Waits.slow, () {
        _slow = true;
        if (!_disposed) notifyListeners();
      });
    }
    if (f.tooLarge) return _land(asked, none: NoBlame.tooLarge);
    if (watch.notText) return _land(asked, none: NoBlame.binary);
    final text = utf8.decode(f.data, allowMalformed: true);
    final abs = f.path.isNotEmpty ? f.path : absoluteIn(chat.folder, path);
    final slash = abs.lastIndexOf('/');
    if (slash < 0) return _land(asked, none: NoBlame.failed);
    GetBlameResponse r;
    try {
      // The file's own folder: one in a nested repository is blamed in it.
      r = await daemon.client.getBlame(
        GetBlameRequest(
          folder: slash == 0 ? '/' : abs.substring(0, slash),
          path: abs.substring(slash + 1),
        ),
      );
    } on Object catch (e) {
      final words = errorText(e);
      final notGit = RegExp(
        'not (in )?a git repository',
        caseSensitive: false,
      ).hasMatch(words);
      return _land(
        asked,
        none: notGit ? NoBlame.notRepository : NoBlame.failed,
        error: notGit ? '' : words,
      );
    }
    if (r.noneReason.isNotEmpty) {
      final none = NoBlame.of(r.noneReason);
      return _land(
        asked,
        none: none,
        error: none == NoBlame.failed ? r.noneReason : '',
      );
    }
    _land(asked, blamed: Blamed(r.runs, text));
  }

  /// Lands the answer to question [asked], if it's the latest.
  void _land(
    int asked, {
    Blamed blamed = Blamed.nothing,
    NoBlame? none,
    String error = '',
  }) {
    if (_disposed || asked != _asked) return;
    _slowly?.cancel();
    _slowly = null;
    _loaded = true;
    _blamed = blamed;
    _none = none;
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _slowly?.cancel();
    chat.files.blamed.removeListener(_switched);
    watch.removeListener(_fileChanged);
    _changes.baseMoved.removeListener(_moved);
    super.dispose();
  }
}

/// One line's place in the blame: the [run] it's from (null: not
/// committed yet, by git's answer or an unsaved edit since), and whether
/// it's the first of its run as shown ([first]), where the gutter names
/// who and when.
@immutable
final class BlameCell {
  const new(this.run, {required this.first});

  final BlameRun? run;
  final bool first;

  /// The commit's id; '' for a line not committed yet.
  String get commit => run?.commit ?? '';

  @override
  bool operator ==(Object other) =>
      other is BlameCell && identical(other.run, run) && other.first == first;

  @override
  int get hashCode => Object.hash(identityHashCode(run), first);
}

/// Each line of [shown]'s cell of [blamed]: at once when [shown] is the
/// text blamed, else through a line diff between the two (off the UI
/// thread for a long text, as the change marks), so an unsaved edit's
/// lines read as not committed and the rest keep their commit. None when
/// the runs don't cover the text blamed line for line (the file changed
/// while it was asked: the next answer has it), or there are none.
FutureOr<List<BlameCell>> blameCells(Blamed blamed, String shown) {
  final runs = blamed.runs;
  if (runs.isEmpty) return const [];
  final owners = _owners(runs, textLines(blamed.text).length);
  if (owners == null) return const [];
  if (_noBom(blamed.text) == _noBom(shown)) return _cells(runs, owners);
  final lines = textLines(shown).length;
  return switch (lineMarksSoon(blamed.text, shown)) {
    final List<LineMark> marks => _mapped(runs, owners, marks, lines),
    final Future<List<LineMark>> later => later.then(
      (marks) => _mapped(runs, owners, marks, lines),
    ),
  };
}

String _noBom(String s) => s.startsWith('﻿') ? s.substring(1) : s;

/// Each of [lines] lines' run, by its index in [runs]; null unless the
/// runs cover them all, one after another from line 1.
List<int>? _owners(List<BlameRun> runs, int lines) {
  final owners = <int>[];
  for (final (i, r) in runs.indexed) {
    if (r.start != owners.length + 1 || r.count < 1) return null;
    owners.addAll(List.filled(r.count, i));
  }
  return owners.length == lines ? owners : null;
}

/// The lines of the text shown ([lines] of them), each the run of the
/// line it was in the text blamed, through [marks] between the two; -1
/// for one changed or added since. None when [marks] has nothing for
/// texts that differ (past the diff's limit).
List<BlameCell> _mapped(
  List<BlameRun> runs,
  List<int> owners,
  List<LineMark> marks,
  int lines,
) {
  if (marks.isEmpty) return const [];
  final mapped = List.filled(lines, -1);
  var delta = 0; // a line's place in the text blamed less its place now
  var at = 0;
  void same(int upTo) {
    for (; at < upTo && at < lines; at++) {
      final was = at + delta;
      mapped[at] = was >= 0 && was < owners.length ? owners[was] : -1;
    }
  }

  for (final m in marks) {
    same(m.first);
    switch (m.kind) {
      case MarkKind.added:
        delta -= m.count;
        at = m.first + m.count;
      case MarkKind.changed:
        delta += m.old.length - m.count;
        at = m.first + m.count;
      case MarkKind.removed:
        delta += m.old.length;
    }
  }
  same(lines);
  return _cells(runs, mapped);
}

/// [owners]' cells: a run's first line where its commit differs from the
/// line above's.
List<BlameCell> _cells(List<BlameRun> runs, List<int> owners) {
  String commit(int owner) => owner < 0 ? '' : runs[owner].commit;
  return [
    for (final (i, owner) in owners.indexed)
      BlameCell(
        owner < 0 || runs[owner].commit.isEmpty ? null : runs[owner],
        first: i == 0 || commit(owners[i - 1]) != commit(owner),
      ),
  ];
}
