import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/line_changes.dart';
import 'package:nushi/marks_base.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview.dart' show FileWatch;
import 'package:nushi/tree_dots.dart';

export 'package:nushi/marks_base.dart' show MarksFrom;

// What a shown file's change marks count from, asked of the daemon, and
// why there are none when there are none (ADR 0131): its path row says
// one or the other, so a file never opens to an unexplained blank gutter.

/// Why a file shows no change marks, in the words its path row says.
enum NoMarks {
  notRepository('Not in a git repository'),
  ignored('Ignored by git'),
  link('A link: no change marks'),
  binary('Not text: no change marks'),
  tooLarge('Too large for change marks'),
  tooManyLines('Over 10,000 lines: no change marks'),
  otherRepository('A repository of its own'),
  oldDaemon('Change marks need a newer daemon'),
  failed('Couldn’t compare with git');

  new(this.label);
  final String label;
}

/// A shown file's text before its chat's work, what its change marks are
/// drawn against ([value]; null draws none), and what its path row says
/// of them (ADR 0131). The base is, by [from]: where the chat's branch
/// left its base ([MarksFrom.branch]), the one the Changes tab's Branch
/// view counts from (`ChangeSpan.branchBase`); on that branch itself (a
/// chat on the default branch), from before the chat's own commits
/// ([MarksFrom.chat]); else the last commit. A file outside the chat's
/// folder (another root, so another repository) counts from its last
/// commit. A file new against the base ([isNew]: untracked, or added
/// since) has the empty text as its base, so every line is marked added.
/// Asked of the daemon (GetDiff with the file's path and the base, API
/// [oneFileDiffApi]) as the file changes on disk, the chat's turn ends, it
/// commits or its folder or worktree changes; the base itself is found
/// again when the turn ends, it commits or the folder changes, once for
/// the chat ([marksBaseOf]), the Files tree's dots counting from the same
/// ([TreeDots]). The file's own folder is asked, so a file in a nested
/// repository is compared against its own repository. Where there are no
/// marks, [none] says why; [changed] counts the lines that differ in the
/// file as saved.
class LineBase extends ChangeNotifier implements ValueListenable<String?> {
  new(this.daemon, this.chat, this.watch) {
    marksBaseOf(chat).addListener(_baseMoved);
    watch.addListener(_fileChanged);
    _fileChanged();
  }

  final Daemon daemon;
  final ChatState chat;
  final FileWatch watch;

  String? _base;
  bool _isNew = false;
  MarksFrom _from = MarksFrom.lastCommit;
  String _against = '';
  NoMarks? _none;
  String _error = '';
  int _changed = 0;
  bool _loaded = false;
  bool _slow = false;
  Timer? _slowly;

  @override
  String? get value => _base;

  /// Whether the file is new against the base (untracked, added to the
  /// index, or added on the branch): its every line is marked added.
  bool get isNew => _isNew;

  /// What [value] is.
  MarksFrom get from => _from;

  /// The branch [from] names, with [MarksFrom.branch]: as the Branch view
  /// has it ("origin/main"; a commit's hash when the base branch is gone).
  String get against => _against;

  /// Why there are no marks, when there are none to draw and the file
  /// isn't simply unchanged.
  NoMarks? get none => _none;

  /// The daemon's words, when asking it failed ([NoMarks.failed]).
  String get error => _error;

  /// The lines added, changed and removed in the file as saved; 0 when
  /// it's the same as the base (or there's none).
  int get changed => _changed;

  /// Whether an answer has come for the file yet.
  bool get loaded => _loaded;

  /// Whether the first answer is taking more than a moment ([Waits.slow]).
  bool get slow => _slow && !_loaded;

  /// What the marks count from, as the path row and a mark's card say it:
  /// "since main", "since this chat began", "since the last commit".
  String get since => switch (_from) {
    MarksFrom.branch => 'since ${branchLabel(_against)}',
    MarksFrom.chat => 'since this chat began',
    MarksFrom.lastCommit => 'since the last commit',
  };

  String? _sha;
  int _asked = 0; // only the latest question's answer lands
  bool _disposed = false;

  void _fileChanged() {
    final f = watch.file;
    // A file too large comes without its text: asked once, to say so.
    final sha = f == null || f.missing
        ? null
        : f.tooLarge
        ? 'too large'
        : f.sha256;
    if (sha == _sha) return;
    _sha = sha;
    unawaited(ask());
  }

  // The chat's turn ended, it committed, or its folder or worktree
  // changed: the base may have moved (a commit can be the chat's first,
  // which moves its start), and the file's marks with it.
  void _baseMoved() => unawaited(ask());

  /// Asks again what the file was before the chat's work.
  Future<void> ask() async {
    final asked = ++_asked;
    final f = watch.file;
    if (f == null || f.missing) return;
    if (!_loaded) {
      _slowly ??= Timer(Waits.slow, () {
        _slow = true;
        if (!_disposed) notifyListeners();
      });
    }
    if (f.tooLarge) return await _land(asked, none: NoMarks.tooLarge);
    if (watch.notText) return await _land(asked, none: NoMarks.binary);
    if (daemon.daemonApi < oneFileDiffApi) {
      return await _land(asked, none: NoMarks.oldDaemon);
    }
    final now = utf8.decode(f.data, allowMalformed: true);
    final abs = f.path.isNotEmpty
        ? f.path
        : absoluteIn(chat.folder, watch.path);
    final slash = abs.lastIndexOf('/');
    if (slash < 0) return await _land(asked, none: NoMarks.failed);
    final inChat = insideOf(chat.folder, abs) != null;
    Future<GetDiffResponse> diff(String base) => daemon.client.getDiff(
      GetDiffRequest(
        folder: slash == 0 ? '/' : abs.substring(0, slash),
        path: abs.substring(slash + 1),
        base: base,
      ),
    );
    var against = lastCommitBase;
    GetDiffResponse r;
    try {
      // A base that couldn't be found is a failure, as GetDiff's is: not
      // the last commit, which would count from somewhere else unsaid.
      if (inChat) against = await marksBaseOf(chat).find(daemon);
      if (_disposed || asked != _asked) return;
      try {
        r = await diff(against.base);
      } on Object {
        // Not a branch or commit of the file's own repository (a nested
        // one), or the chat's first commit was the repository's first:
        // from its last commit instead.
        if (against.base.isEmpty) rethrow;
        against = lastCommitBase;
        r = await diff('');
      }
    } on Object catch (e) {
      final words = errorText(e);
      final notGit = RegExp(
        'not (in )?a git repository',
        caseSensitive: false,
      ).hasMatch(words);
      return await _land(
        asked,
        none: notGit ? NoMarks.notRepository : NoMarks.failed,
        error: notGit ? '' : words,
      );
    }
    if (r.files.isEmpty) {
      // Tracked and unchanged: its text then is this.
      return await _land(asked, base: now, now: now, at: against);
    }
    final c = r.files.first;
    if (c.skipped.isNotEmpty) {
      return await _land(
        asked,
        none: _skipped(c),
        error: c.skipped,
        at: against,
      );
    }
    return await switch (c.status) {
      'modified' ||
      'renamed' => _land(asked, base: c.oldText, now: now, at: against),
      'untracked' ||
      'added' => _land(asked, base: '', now: now, isNew: true, at: against),
      final s => _land(
        asked,
        none: NoMarks.failed,
        error: 'git lists it as $s',
        at: against,
      ),
    };
  }

  /// Why the daemon left a file's text out.
  static NoMarks _skipped(FileChange c) => switch (c.skipped) {
    'not tracked' => NoMarks.ignored,
    'a link' => NoMarks.link,
    'binary' => NoMarks.binary,
    'too large' => NoMarks.tooLarge,
    'a submodule' || 'a repository of its own' => NoMarks.otherRepository,
    _ => NoMarks.failed,
  };

  /// Lands an answer for question [asked], the latest: [base] against
  /// [now] (the file as saved), or [none] and why.
  Future<void> _land(
    int asked, {
    String? base,
    String now = '',
    bool isNew = false,
    NoMarks? none,
    String error = '',
    MarksBase at = lastCommitBase,
  }) async {
    var changed = 0;
    var text = base;
    var why = none;
    if (text != null && tooLongToMark(text, now)) {
      // Past the diff's limit: no marks, but a new file stays new.
      text = null;
      if (!isNew) why = NoMarks.tooManyLines;
    } else if (text != null) {
      final marks = await lineMarksSoon(text, now);
      for (final m in marks) {
        changed += m.kind == MarkKind.removed ? m.old.length : m.count;
      }
    }
    if (_disposed || asked != _asked) return;
    _slowly?.cancel();
    final same =
        _loaded &&
        text == _base &&
        isNew == _isNew &&
        at.from == _from &&
        at.base == _against &&
        why == _none &&
        error == _error &&
        changed == _changed;
    _loaded = true;
    if (same) return;
    _base = text;
    _isNew = isNew;
    _from = at.from;
    _against = at.base;
    _none = why;
    _error = error;
    _changed = changed;
    notifyListeners();
    // The tree's dot follows what the file's marks found (ADR 0131).
    treeDotsOf(chat).poke();
  }

  @override
  void dispose() {
    _disposed = true;
    _slowly?.cancel();
    marksBaseOf(chat).removeListener(_baseMoved);
    watch.removeListener(_fileChanged);
    super.dispose();
  }
}

/// A base branch's name as the path row says it: a remote's `origin/`
/// left off ("main"), a commit's hash shortened.
String branchLabel(String base) {
  if (RegExp(r'^[0-9a-f]{40}$').hasMatch(base)) return base.substring(0, 7);
  return base.startsWith('origin/') ? base.substring(7) : base;
}
