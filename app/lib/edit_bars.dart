import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart' show ReadOnlyLine, baseName;
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';

/// What an edited file's view says above its text (ADR 0096), one line
/// each, while it applies: changed on disk over the edits (Compare,
/// Overwrite with mine, Use theirs), deleted on disk (Save, Discard), a
/// change from disk merged in (Compare, dismissed), the last save's
/// failure, and why it's read-only now. [onDiscard] drops the edits.
class EditBars extends StatelessWidget {
  const new({required this.edit, required this.onDiscard, super.key});

  final FileEdit edit;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: edit,
    builder: (context, _) {
      final t = NushiTheme.of(context).t;
      final theirs = edit.theirs;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (theirs != null)
            _Bar(
              dot: t.needs,
              text: 'Changed on disk',
              actions: [
                ('Compare', () => compareEdit(context, edit, theirs.text)),
                ('Overwrite with mine', () => unawaited(edit.overwrite())),
                ('Use theirs', edit.useTheirs),
              ],
            )
          else if (edit.deleted)
            _Bar(
              dot: t.needs,
              text: 'Deleted on disk',
              actions: [
                ('Save', () => unawaited(edit.restore())),
                ('Discard', onDiscard),
              ],
            )
          else if (edit.merged)
            _Bar(
              text: 'Merged a change from disk',
              actions: [
                ('Compare', () => compareEdit(context, edit, edit.baseText)),
              ],
              onDismiss: edit.dismissMerged,
            ),
          if (edit.error case final error?)
            _Bar(
              dot: t.crashed,
              text: 'Couldn’t save: $error',
              actions: [('Try again', () => unawaited(edit.save()))],
            ),
          if (edit.readOnly case final why? when why.isNotEmpty)
            ReadOnlyLine(why),
        ],
      );
    },
  );
}

/// One line over the text: a dot when it needs you, what happened, its
/// links, and a ✕ when it can be dismissed.
class _Bar extends StatelessWidget {
  const new({
    required this.text,
    required this.actions,
    this.dot,
    this.onDismiss,
  });

  final String text;
  final List<(String, VoidCallback)> actions;
  final Color? dot;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.fromLTRB(NushiTheme.gutter, 4, 8, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        spacing: 8,
        children: [
          if (dot case final color?)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(text, style: theme.ui(t.text, size: 12)),
                for (final (label, onTap) in actions)
                  LinkText(label, size: 12, onTap: onTap),
              ],
            ),
          ),
          if (onDismiss case final dismiss?)
            IconTap.line(
              LineIcon.close,
              size: 12,
              padding: 3,
              tooltip: 'Dismiss',
              onTap: dismiss,
            ),
        ],
      ),
    );
  }
}

/// Compare: the disk's [disk] text against the edits, read-only, in a
/// dialog.
void compareEdit(BuildContext context, FileEdit edit, String disk) => unawaited(
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 1000,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${plainPath(baseName(edit.path))}: on disk · yours',
                      style: NushiTheme.of(context).ui(
                        NushiTheme.of(context).t.text,
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconTap.line(
                    LineIcon.close,
                    tooltip: 'Close',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DiffBox(
                FileChange(path: edit.path, oldText: disk, newText: edit.text),
                fit: false,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Asks to drop [edit]'s unsaved text, which couldn't be saved (in
/// conflict, deleted, read-only or failed): true for Discard.
Future<bool> askDiscard(BuildContext context, FileEdit edit) => confirm(
  context,
  'Discard your changes to ${plainPath(baseName(edit.path))}?',
  switch (edit) {
    FileEdit(theirs: _?) =>
      'It changed on disk too, and they couldn’t be saved.',
    FileEdit(deleted: true) => 'It was deleted on disk.',
    FileEdit(readOnly: final _?) => 'It can’t be edited now: ${edit.readOnly}',
    FileEdit(error: final e?) => 'They couldn’t be saved: $e',
    _ => 'A change from disk was merged into them; they aren’t saved yet.',
  },
  'Discard',
  destructive: true,
);

/// Saves the edits of [tabs] before they close: true when they can close,
/// every edit saved, or one that couldn't be discarded after asking.
Future<bool> saveBeforeClosing(
  BuildContext context,
  ChatState chat,
  Iterable<PreviewEntry> tabs,
) async {
  for (final tab in [...tabs]) {
    if (tab is! PreviewFile) continue;
    final edit = chat.edits[tab.path];
    if (edit == null || !edit.unsaved) continue;
    if (await edit.save()) continue;
    if (!context.mounted || !await askDiscard(context, edit)) return false;
  }
  return true;
}

/// Closes [tab], its edits saved first ([saveBeforeClosing]).
Future<void> closeTabSaving(
  BuildContext context,
  ChatState chat,
  PreviewEntry tab,
) async {
  if (await saveBeforeClosing(context, chat, [tab])) chat.closePreview(tab);
}

/// Closes the preview and its tabs, their edits saved first.
Future<void> closePreviewSaving(BuildContext context, ChatState chat) async {
  if (await saveBeforeClosing(context, chat, chat.previewTabs.value)) {
    chat.preview.value = null;
  }
}

/// A file tab's ✕, or, while its file has unsaved edits and the pointer
/// isn't on the tab ([hover]), a dot in its place (amber in a conflict or
/// deleted). [shown] says whether the ✕ shows otherwise.
class EditedMark extends StatelessWidget {
  const new({
    required this.chat,
    required this.path,
    required this.close,
    required this.shown,
    required this.hover,
    super.key,
    this.color,
  });

  final ChatState chat;
  final String? path; // null: not a file's tab
  final Widget close;
  final bool shown;
  final bool hover;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Widget plain() => Opacity(opacity: shown ? 1 : 0, child: close);
    final path = this.path;
    if (path == null) return plain();
    return ListenableBuilder(
      listenable: chat.editsChanged,
      builder: (context, _) => switch (chat.edits[path]) {
        null => plain(),
        final edit => ListenableBuilder(
          listenable: edit,
          builder: (context, _) => edit.unsaved && !hover
              ? Center(child: UnsavedDot(edit, color: color))
              : plain(),
        ),
      },
    );
  }
}

/// The dot of a file with unsaved edits: the text's color, amber in a
/// conflict or when it was deleted.
class UnsavedDot extends StatelessWidget {
  const new(this.edit, {super.key, this.color});

  final FileEdit edit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final needs = edit.theirs != null || edit.deleted;
    return Tooltip(
      message: needs ? 'Unsaved: changed on disk' : 'Unsaved',
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: needs ? t.needs : color ?? t.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
