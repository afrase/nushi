import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'syntax.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A review comment on lines [start]–[end] (from 1) of a file's [old] or
/// new side, in the Changes view it was made in ([where]: the scope, and
/// the commits in Commits). [quote] is those lines as they were. Once
/// [sent], it stays (dimmed) until the file changes after the agent's
/// reply: [seen] is the file's text as the first look after it found it.
class ReviewComment {
  ReviewComment({
    required this.id,
    required this.where,
    required this.path,
    required this.old,
    required this.start,
    required this.end,
    required this.quote,
    required this.text,
    this.sent = false,
    this.seen,
  });

  ReviewComment.fromJson(Map<String, dynamic> j)
    : this(
        id: j['id'],
        where: j['where'],
        path: j['path'],
        old: j['old'],
        start: j['start'],
        end: j['end'],
        quote: j['quote'],
        text: j['text'],
        sent: j['sent'] ?? false,
        seen: j['seen'],
      );

  final String id, where, path, quote;
  final bool old;
  final int start, end;
  String text;
  bool sent;
  int? seen; // a hash of the side's text

  Map<String, Object?> toJson() => {
    'id': id,
    'where': where,
    'path': path,
    'old': old,
    'start': start,
    'end': end,
    'quote': quote,
    'text': text,
    'sent': sent,
    'seen': seen,
  };

  String get lines => start == end ? 'Line $start' : 'Lines $start–$end';
}

File get _file => File('$dataDir/reviews.json');

/// Every chat's review comments, by chat id, kept in `reviews.json` in
/// the data folder until sent and gone, or removed.
final reviews = ValueNotifier<Map<String, List<ReviewComment>>>(() {
  try {
    final j = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in j.entries)
        key: [for (final c in value as List) ReviewComment.fromJson(c)],
    };
  } on Object {
    return <String, List<ReviewComment>>{};
  }
}());

/// Replaces [chat]'s comments with [comments] and saves them.
void setComments(String chat, List<ReviewComment> comments) {
  reviews.value = {...reviews.value, chat: comments}
    ..removeWhere((_, v) => v.isEmpty);
  try {
    _file.writeAsStringSync(jsonEncode(reviews.value));
  } on Object {
    // Kept until the app quits.
  }
}

/// [chat]'s comments.
List<ReviewComment> commentsOf(String chat) => reviews.value[chat] ?? const [];

/// Drops [chat]'s sent comments on files whose side changed since the
/// first look after the agent's reply ([files], as [where] shows them now;
/// called only while the chat is idle).
void forgetChanged(String chat, String where, List<FileChange> files) {
  var changed = false;
  final kept = <ReviewComment>[];
  for (final c in commentsOf(chat)) {
    final f = files.where((f) => f.path == c.path).firstOrNull;
    if (c.sent && c.where == where && f != null) {
      final h = _hash(c.old ? f.oldText : f.newText);
      if (c.seen == null) {
        c.seen = h;
        changed = true;
      } else if (c.seen != h) {
        changed = true;
        continue;
      }
    }
    kept.add(c);
  }
  if (changed) setComments(chat, kept);
}

/// FNV-1a over the text's code units: the same across launches.
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The message a review sends: each comment's file, lines, the quoted
/// lines in a fence and the comment, then [note].
String reviewMessage(List<ReviewComment> comments, String note) {
  final out = StringBuffer('Review comments:\n');
  for (final (i, c) in comments.indexed) {
    final side = c.old ? ' (the old version, before the change)' : '';
    var fence = '```';
    while (c.quote.contains(fence)) {
      fence += '`';
    }
    out
      ..write('\n${i + 1}. `${c.path}`, ${c.lines.toLowerCase()}$side:\n')
      ..write('$fence${languageOf(c.path) ?? ''}\n${c.quote}\n$fence\n')
      ..write('${c.text}\n');
  }
  if (note.trim().isNotEmpty) out.write('\n${note.trim()}\n');
  return out.toString();
}

/// Asks for an overall note, then sends [chat]'s unsent comments to its
/// agent as one message and marks them sent.
Future<void> sendReview(
  BuildContext context,
  Daemon daemon,
  String chat,
) async {
  final unsent = commentsOf(chat).where((c) => !c.sent).toList();
  final note = TextEditingController();
  final files = unsent.map((c) => c.path).toSet().length;
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => nushiDialog(
      'Send review',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            '${unsent.length} comment${unsent.length == 1 ? '' : 's'} on '
            '$files file${files == 1 ? '' : 's'}, with the lines they are '
            'on, go to Claude as one message.',
          ),
          TextField(
            controller: note,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Anything else to say (optional)',
            ),
          ),
        ],
      ),
      [
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context, false),
        ),
        Button(
          label: 'Send',
          kind: ButtonKind.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  if (send != true || !context.mounted) return;
  await tryOrShow(context, () async {
    await daemon.client.sendPrompt(
      SendPromptRequest(chatId: chat, text: reviewMessage(unsent, note.text)),
    );
    for (final c in unsent) {
      c.sent = true;
    }
    setComments(chat, [...commentsOf(chat)]);
  });
}

/// A comment under its lines in the diff: its lines and text, Edit and
/// Remove on hover; dimmed once sent.
class CommentCard extends StatefulWidget {
  const CommentCard(
    this.comment, {
    super.key,
    required this.onEdit,
    required this.onRemove,
  });

  final ReviewComment comment;
  final VoidCallback onEdit, onRemove;

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final c = widget.comment;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Opacity(
        opacity: c.sent ? 0.55 : 1,
        child: _Inlay(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.sent ? '${c.lines} · sent' : c.lines,
                      style: theme.ui(t.textMuted, size: 11.5),
                    ),
                  ),
                  if (_hover && !c.sent)
                    IconTap(
                      Icons.edit_outlined,
                      tooltip: 'Edit',
                      size: 13,
                      onTap: widget.onEdit,
                    ),
                  if (_hover)
                    IconTap(
                      Icons.close,
                      tooltip: 'Remove',
                      size: 13,
                      onTap: widget.onRemove,
                    ),
                ],
              ),
              SelectableText(c.text, style: theme.ui(t.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The box to write a comment in, under the lines it's on: Enter saves it,
/// Shift-Enter adds a line, Escape drops it.
class CommentBox extends StatefulWidget {
  const CommentBox({
    super.key,
    required this.lines,
    required this.text,
    required this.onSave,
    required this.onCancel,
  });

  final String lines, text;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends State<CommentBox> {
  late final _text = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The diff pane took the focus with the click; autofocus would yield.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isNotEmpty) widget.onSave(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return _Inlay(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(widget.lines, style: theme.ui(t.textMuted, size: 11.5)),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): _save,
              const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
            },
            child: TextField(
              controller: _text,
              focusNode: _focus,
              minLines: 1,
              maxLines: 8,
              style: theme.ui(t.text),
              decoration: const InputDecoration(
                hintText: 'Comment for Claude',
                isDense: true,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 6,
            children: [
              Button(
                label: 'Cancel',
                kind: ButtonKind.ghost,
                onPressed: widget.onCancel,
              ),
              Button(
                label: widget.text.isEmpty ? 'Comment' : 'Save',
                kind: ButtonKind.primary,
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An inline box between a diff's lines, with an accent bar on its left.
class _Inlay extends StatelessWidget {
  const _Inlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 8, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
        decoration: BoxDecoration(
          color: t.raised,
          border: Border(left: BorderSide(color: t.accent, width: 2)),
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        child: child,
      ),
    );
  }
}
