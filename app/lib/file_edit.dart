import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/merge_lines.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/tab_indent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:re_editor/re_editor.dart';

/// The daemon's API that has WriteChatFile, and the watch's sums.
const editApi = 108;

/// A file's text being edited in the preview (ADR 0096): the editor's
/// buffer, and the version on disk it was read from (its base), as the
/// daemon's watch and saves tell of it. It outlives the file's view (a
/// tab shown again, another chat picked), as its chat keeps it
/// (`ChatState.edits`), until its tab closes.
class FileEdit extends ChangeNotifier {
  new(this.daemon, this.chatId, this.path, FileText file, String sha)
    : codec = file.codec,
      _baseText = file.text,
      _baseSha = sha,
      tabs = indentsWithTabs(path, file.text) {
    controller = CodeLineEditingController(
      codeLines: CodeLines.fromText(file.text),
      spanBuilder: _span,
    );
    _lines = controller.codeLines;
    controller.addListener(_changed);
    _highlight();
  }

  final Daemon daemon;
  final String chatId;
  final String path; // as its tab names it

  /// The editor's text and undo history.
  late final CodeLineEditingController controller;

  /// How the disk's version is written: a save writes it so.
  FileCodec codec;

  String _baseText;
  String _baseSha;

  /// The file indents with tabs (its base, as `indentsWithTabs` tells):
  /// the editor's Tab, ⇧Tab and Return indent with them.
  bool tabs;

  /// The disk's version that overlaps the edits (a conflict), while it's
  /// unresolved.
  FileVersion? theirs;

  /// The file went from disk while there were unsaved edits.
  bool deleted = false;

  /// A change from disk was merged into the edits, until the note's
  /// dismissed or the file's saved.
  bool merged = false;

  /// Why the disk's version can't be edited now, while it can't ("it's
  /// over 1 MiB."): the edits are kept, but can't be saved.
  String? readOnly;

  /// Why the last save failed, until one works.
  String? error;

  bool _unsaved = false;

  /// The text differs from the disk's version it was read from.
  bool get unsaved => _unsaved;

  /// The text as the editor has it, `\n` line ends.
  String get text => controller.codeLines.asString(TextLineBreak.lf);

  /// The base: the disk's text the edits started from.
  String get baseText => _baseText;

  /// What would be lost if the edits went now: unsaved edits that can't be
  /// saved as they are (in conflict, deleted, read-only, or failed).
  bool get stuck =>
      _unsaved &&
      (theirs != null || deleted || readOnly != null || error != null);

  /// Whether a save would write now.
  bool get canSave =>
      _unsaved && theirs == null && !deleted && readOnly == null;

  /// The sum of the version a save before this one replaced: watch
  /// messages still carrying it are older than the save, until one with
  /// any other sum comes, or a watch starts. Only the watch's messages
  /// are checked against it: a save's Stale reply is the disk now.
  String? _ignore;

  /// How many watch messages came, and the last one's sum ('' gone).
  int _heard = 0;
  String _heardSum = '';

  /// A change from disk held while an input method composes.
  (String, FileText)? _held;

  Future<bool>? _saving;
  CodeLines? _lines;

  void _changed() {
    if (!identical(controller.codeLines, _lines)) {
      _lines = controller.codeLines;
      final unsaved = text != _baseText;
      if (unsaved != _unsaved) {
        _unsaved = unsaved;
        notifyListeners();
      }
      _soon?.cancel();
      _soon = Timer(const Duration(milliseconds: 300), _highlight);
    }
    if (_held case (final sha, final file) when !controller.isComposing) {
      _held = null;
      _fromDisk(sha, file);
    }
  }

  /// The watch's latest message for the file; [first] the first of a
  /// watch, which can't be older than a save already answered.
  void receive(WatchChatFileResponse f, {bool first = false}) {
    _heard++;
    _heardSum = f.missing ? '' : f.sha256;
    if (first && _saving == null) _ignore = null;
    if (_ignore != null) {
      if (!f.missing && f.sha256 == _ignore) return;
      _ignore = null;
    }
    if (f.missing) {
      if (_unsaved && !deleted) {
        deleted = true;
        notifyListeners();
      }
      return;
    }
    final why = notEditable(f);
    if (why != null) {
      if (readOnly != why) {
        readOnly = why;
        notifyListeners();
      }
      return;
    }
    final (file, _) = decodeFile(f.data);
    readOnly = null;
    _fromDisk(f.sha256, file!);
  }

  void _fromDisk(String sha, FileText file) {
    if (controller.isComposing) {
      _held = (sha, file);
      return;
    }
    final wasDeleted = deleted;
    deleted = false;
    if (sha == _baseSha) {
      codec = file.codec;
      theirs = null;
      notifyListeners();
      return;
    }
    if (theirs?.sha == sha && !wasDeleted) return;
    final mine = text;
    // The disk has the editor's text already (a save's own version, seen
    // before its reply): nothing changed here.
    if (file.text == mine) {
      _setBase(file.text, sha, file.codec);
      _unsaved = false;
      notifyListeners();
      return;
    }
    final merged = mine == _baseText
        ? file.text
        : mergeLines(_baseText, mine, file.text);
    if (merged == null) {
      theirs = (text: file.text, sha: sha, codec: file.codec);
    } else {
      this.merged = this.merged || mine != _baseText;
      _setBase(file.text, sha, file.codec);
      _take(merged);
    }
    notifyListeners();
  }

  void _setBase(String text, String sha, FileCodec codec) {
    _baseText = text;
    _baseSha = sha;
    this.codec = codec;
    tabs = indentsWithTabs(path, text);
    theirs = null;
  }

  /// Puts [text] in the editor as a change from outside: the cursor on its
  /// line and column as near as there are, and no undo past it, so ⌘Z
  /// can't take the disk's change back unseen.
  void _take(String text) {
    final at = controller.selection;
    final lines = CodeLines.fromText(text);
    final line = min(at.extentIndex, lines.length - 1);
    final column = min(at.extentOffset, lines[line].length);
    controller
      ..value = CodeLineEditingValue(
        codeLines: lines,
        selection: CodeLineSelection.collapsed(index: line, offset: column),
      )
      ..clearHistory();
    _changed();
  }

  /// Saves the edits over the base (⌘S, the focus leaving): true once the
  /// disk has them. Never in a conflict, deleted or read-only; a stale
  /// save merges the disk's change in, or turns into a conflict.
  Future<bool> save() async {
    if (_saving case final running?) await running;
    if (!_unsaved) return theirs == null && !deleted;
    if (!canSave) return false;
    return await _write(_baseSha, codec);
  }

  /// Overwrite with mine: saves the edits over the disk's version shown
  /// in the conflict, and only that one.
  Future<bool> overwrite() async {
    final t = theirs;
    if (t == null) return await save();
    if (_saving case final running?) await running;
    return await _write(t.sha, t.codec);
  }

  /// Save, for a file deleted with unsaved edits: writes it again, if it's
  /// still not there.
  Future<bool> restore() async {
    if (!deleted) return await save();
    if (_saving case final running?) await running;
    return await _write('', codec, gone: true);
  }

  /// Use theirs: the disk's version in place of the edits.
  void useTheirs() {
    final t = theirs;
    if (t == null) return;
    _setBase(t.text, t.sha, t.codec);
    merged = false;
    _take(t.text);
    notifyListeners();
  }

  /// Its tab closed, or its edits were discarded: it never writes again.
  bool closed = false;

  Future<bool> _write(String base, FileCodec codec, {bool gone = false}) {
    if (closed) return Future.value(false);
    final done = _writeNow(base, codec, gone);
    _saving = done;
    return done.whenComplete(() {
      if (identical(_saving, done)) _saving = null;
    });
  }

  Future<bool> _writeNow(String base, FileCodec codec, bool gone) async {
    final mine = text;
    final heard = _heard;
    final WriteChatFileResponse r;
    try {
      r = await daemon.client.writeChatFile(
        WriteChatFileRequest(
          chatId: chatId,
          path: path,
          data: codec.encode(mine),
          baseSha256: base,
          mustNotExist: gone,
        ),
      );
    } on Object catch (e) {
      error = errorText(e);
      notifyListeners();
      return false;
    }
    error = null;
    if (r.hasSaved()) {
      // Messages with the old sum are older than the save, unless the
      // watch has told of a newer version already (the save's own).
      final told = _heard != heard && _heardSum != base;
      if (!gone && !told) _ignore = base;
      deleted = false;
      merged = false;
      _setBase(mine, r.saved.sha256, codec);
      _unsaved = text != mine;
      notifyListeners();
      return !_unsaved;
    }
    final stale = r.stale;
    _ignore = null;
    if (stale.missing) {
      deleted = true;
      notifyListeners();
      return false;
    }
    final (file, why) = decodeFile(stale.data);
    if (file == null) {
      readOnly = why;
      notifyListeners();
      return false;
    }
    _fromDisk(stale.sha256, file);
    return false;
  }

  /// Dismisses the note of a merge.
  void dismissMerged() {
    merged = false;
    notifyListeners();
  }

  // The syntax's spans, as the preview's source has them (SourceView):
  // the whole text highlighted off the UI thread a moment after it
  // changes; until then a line keeps its spans while its text is as it
  // was, at its index or as far from the end.
  Timer? _soon;
  int _reads = 0;
  List<String> _hlLines = const [];
  List<Uint32List?> _hlSpans = const [];

  void _highlight() {
    final text = this.text;
    final language = sourceLanguage(path, text);
    if (language == null) return;
    final read = ++_reads;
    highlightSides(language, '', text).then((s) {
      if (read != _reads || _disposed || s[1] == null) return;
      _hlLines = text.split('\n');
      _hlSpans = s[1]!;
      controller.forceRepaint();
    }).ignore();
  }

  /// Whether the syntax's spans came (tests wait for them).
  @visibleForTesting
  bool get highlighted => _hlLines.isNotEmpty;

  Uint32List? _spansAt(int i, String line) {
    if (i < _hlLines.length && _hlLines[i] == line) {
      return _hlSpans.elementAtOrNull(i);
    }
    final j = i + _hlLines.length - controller.codeLines.length;
    if (j >= 0 && j < _hlLines.length && _hlLines[j] == line) {
      return _hlSpans.elementAtOrNull(j);
    }
    return null;
  }

  TextSpan _span({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final t = NushiTheme.of(context).t;
    final line = codeLine.text;
    return TextSpan(
      style: style.copyWith(fontFeatures: _noLigatures),
      // re_editor draws with no text scaling.
      children: tabStops(
        spansOf(t, line, _spansAt(index, line)),
        fontSize: style.fontSize!,
        column: columnWidth(style, TextScaler.noScaling),
        spacing: style.letterSpacing ?? 0,
      ),
    );
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _soon?.cancel();
    controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }
}

const _noLigatures = [FontFeature.disable('liga'), FontFeature.disable('calt')];

/// A version of the file on disk: its text, sum and codec.
typedef FileVersion = ({String text, String sha, FileCodec codec});

/// Why the watch's [f] can't be edited, or null when it can: a message
/// from a daemon before API 108 can't, and says nothing.
String? notEditable(WatchChatFileResponse f) {
  if (f.sha256.isEmpty) return '';
  if (!f.editable) {
    if (f.size > 1 << 20) return 'it’s over 1 MiB.';
    if (f.readOnly) return 'its permissions don’t let you write it.';
    return 'it has more than one hard link.';
  }
  final (_, why) = decodeFile(f.data);
  return why;
}

/// Saves every edit that can be saved, in every chat (the window going to
/// the back, quitting); gives those left unsaved.
Future<List<FileEdit>> saveEdits(Daemon d) async {
  final all = [
    for (final c in d.chats.values) ...c.edits.values.where((e) => e.unsaved),
  ];
  await Future.wait([for (final e in all) e.save()]);
  return [
    for (final e in all)
      if (e.unsaved) e,
  ];
}
