import 'package:flutter/material.dart';

import 'package:nushi/blame.dart';
import 'package:nushi/chat.dart' show relativeIn;
import 'package:nushi/chat_files.dart' show chatWrote;
import 'package:nushi/controls.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/line_base.dart';
import 'package:nushi/preview.dart' show PreviewKind;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tree_dots.dart';
import 'package:nushi/widgets.dart' show showError;

// The Files pane's path row's one word on the shown file's change marks
// (ADR 0131): what they count from and how many lines, that the file is
// new, that it's unchanged, or why there are none; so a file with the
// tree's dot never opens to an unexplained blank gutter, and one the chat
// wrote says when it's the same as before.

/// What the path row says of a file's marks: `label` in a [NotePill] of
/// `tone`, `tip` its tooltip; `toSource` makes it the way to the source
/// view, where the marks are, from a rendered view.
typedef MarksWord = ({String label, NoteTone tone, String tip, bool toSource});

/// [lines]'s word for the path row, null for none: nothing until the
/// first answer, and for a file the chat didn't write ([wrote] false) only
/// a count of changed lines or New file, as "No changes" and why there
/// are no marks would be noise on every file opened. [rendered] is a
/// rendered view that has a source to switch to (Markdown, CSV, HTML),
/// where marks can't show: a count or New file leads to the source.
/// [reformatted] is a source shown other than as saved (JSON
/// pretty-printed), whose lines aren't marked.
MarksWord? marksWord(
  LineBase lines, {
  required bool wrote,
  bool rendered = false,
  bool reformatted = false,
}) {
  if (!lines.loaded) return null;
  if (lines.none case final none?) {
    if (!wrote) return null;
    return (
      label: none.label,
      tone: switch (none) {
        NoMarks.failed => NoteTone.crashed,
        _ => NoteTone.quiet,
      },
      tip: switch (none) {
        NoMarks.notRepository =>
          'Change marks come from git, and this folder has no repository',
        NoMarks.ignored =>
          'Git ignores it (.gitignore), so has nothing to compare it with',
        NoMarks.link => 'A symbolic link: git keeps the link, not the file',
        NoMarks.binary => 'Only text has change marks',
        NoMarks.tooLarge => 'Change marks stop at 1 MiB',
        NoMarks.tooManyLines => 'Change marks stop at 10,000 lines',
        NoMarks.otherRepository => 'A repository inside this one',
        NoMarks.failed =>
          lines.error.isEmpty ? 'Click for the error' : lines.error,
      },
      toSource: false,
    );
  }
  final since = lines.since;
  if (lines.isNew) {
    return (
      label: 'New file',
      tone: NoteTone.done,
      tip: rendered
          ? 'Every line is new $since: view source to see them marked'
          : 'Every line is new $since',
      toSource: rendered,
    );
  }
  final n = lines.changed;
  if (n == 0) {
    if (!wrote) return null;
    return (
      label: 'No changes $since',
      tone: NoteTone.quiet,
      tip: 'The chat wrote it, but it’s the same as it was',
      toSource: false,
    );
  }
  return (
    label: '$n changed ${n == 1 ? 'line' : 'lines'} $since',
    tone: NoteTone.accent,
    tip: rendered
        ? 'View source to see the changed lines marked'
        : reformatted
        ? 'Shown reformatted, so its lines aren’t marked'
        : 'Marked beside the lines; click a mark for what was there',
    toSource: rendered,
  );
}

/// The shown file's [marksWord] as a [NotePill], kept current; a quiet
/// "Comparing…" while the first answer takes more than a moment; a
/// failure's pill shows the daemon's words. While its Blame is on, what
/// Blame has to say comes first, the same way: "Blaming…", or why there
/// is no blame (issue #78).
class MarksNote extends StatelessWidget {
  const new({required this.shown, super.key});

  final ShownFile shown;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      shown.lines,
      shown.blame,
      shown.source,
      shown.watch,
      shown.chat.editsChanged,
      treeDotsOf(shown.chat),
    ]),
    builder: (context, _) {
      // A picture or a PDF shows no text, so has no gutter to explain.
      if (shown.kind == PreviewKind.image || shown.kind == PreviewKind.pdf) {
        return const SizedBox.shrink();
      }
      if (_blame(context, shown.blame, reformatted: shown.reformatted)
          case final note?) {
        return note;
      }
      final chat = shown.chat;
      // The chat wrote it, or the tree dots it: either way the path row
      // says what its marks are, or why there are none.
      final rel = relativeIn(chat.folder, shown.path);
      final wrote =
          chatWrote(chat).contains(rel) ||
          treeDotsOf(chat).marks.files.contains(rel);
      final lines = shown.lines;
      if (lines.slow && wrote) {
        final theme = NushiTheme.of(context);
        return Text(
          'Comparing…',
          maxLines: 1,
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      }
      final word = marksWord(
        lines,
        wrote: wrote,
        rendered: !shown.showsSource && shown.switches,
        reformatted: shown.reformatted,
      );
      if (word == null) return const SizedBox.shrink();
      final failed = lines.none == NoMarks.failed && lines.error.isNotEmpty;
      return NotePill(
        word.label,
        tone: word.tone,
        tip: word.tip,
        trailing: word.toSource ? Icons.chevron_right : null,
        onTap: word.toSource
            ? () => shown.showSource(on: true)
            : failed
            ? () => showError(context, lines.error)
            : null,
      );
    },
  );

  /// What Blame says while it's on: "Blaming…" while its first answer
  /// takes a moment, or why there's none; null to say nothing.
  static Widget? _blame(
    BuildContext context,
    FileBlame blame, {
    required bool reformatted,
  }) {
    if (blame.on && reformatted) {
      return NotePill(NoBlame.reformatted.label, tip: NoBlame.reformatted.tip);
    }
    if (blame.slow) {
      final theme = NushiTheme.of(context);
      return Text(
        'Blaming…',
        maxLines: 1,
        style: theme.ui(theme.t.textMuted, size: 12),
      );
    }
    final none = blame.none;
    if (none == null) return null;
    final failed = none == NoBlame.failed;
    return NotePill(
      none.label,
      tone: failed ? NoteTone.crashed : NoteTone.quiet,
      tip: failed
          ? (blame.error.isEmpty ? 'Click for the error' : blame.error)
          : none.tip,
      onTap: failed && blame.error.isNotEmpty
          ? () => showError(context, blame.error)
          : null,
    );
  }
}
