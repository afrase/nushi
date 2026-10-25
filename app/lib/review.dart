import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A review comment on lines [start]–[end] (from 1) of a file's [old] or
/// new side, in the Changes view it was made in ([where]: the scope, and
/// the commits in Commits). [quote] is those lines as they were, and
/// [before] and [after] the lines around them: when the file changes, the
/// comment moves to where they are now ([anchor]), or is [outdated] when
/// they're gone. Once [sent], it stays (dimmed) until the file changes
/// after the agent's reply: [seen] is the file's text as the first look
/// after it found it.
class ReviewComment {
  new({
    required this.id,
    required this.where,
    required this.path,
    required this.old,
    required this.start,
    required this.end,
    required this.quote,
    required this.text,
    this.before = '',
    this.after = '',
    this.sent = false,
    this.outdated = false,
    this.seen,
  });

  new fromJson(Map<String, dynamic> j)
    : this(
        id: j['id'] as String,
        where: j['where'] as String,
        path: j['path'] as String,
        old: j['old'] as bool,
        start: j['start'] as int,
        end: j['end'] as int,
        quote: j['quote'] as String,
        text: j['text'] as String,
        before: j['before'] as String? ?? '',
        after: j['after'] as String? ?? '',
        sent: j['sent'] as bool? ?? false,
        outdated: j['outdated'] as bool? ?? false,
        seen: j['seen'] as int?,
      );

  final String id;
  final String where;
  final String path;
  final String quote;
  final String before;
  final String after;
  final bool old;
  int start;
  int end;
  String text;
  bool sent;
  bool outdated;
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
    'before': before,
    'after': after,
    'sent': sent,
    'outdated': outdated,
    'seen': seen,
  };

  /// Follows the commented lines into [text], the side as it is now: true
  /// if the comment moved or became (or stopped being) [outdated].
  /// The lines are compared as the diff shows them: without a "\r" at the
  /// end (Windows line endings).
  bool anchor(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final quoted = quote.split('\n');
    bool at(int i) =>
        i >= 0 &&
        i + quoted.length <= lines.length &&
        Iterable<int>.generate(quoted.length)
            .every((k) => lines[i + k] == quoted[k]);
    // Where the lines are now; with several (a "}" is everywhere), where
    // the lines around them match best, then the nearest: the old place
    // keeps them only when nothing matches better.
    final b = before.isEmpty ? <String>[] : before.split('\n');
    final a = after.isEmpty ? <String>[] : after.split('\n');
    int score(int i) {
      var n = 0;
      for (var k = 0; k < b.length; k++) {
        final j = i - b.length + k;
        if (j >= 0 && lines[j] == b[k]) n += 1000;
      }
      for (var k = 0; k < a.length; k++) {
        final j = i + quoted.length + k;
        if (j < lines.length && lines[j] == a[k]) n += 1000;
      }
      return n - (i - (start - 1)).abs();
    }

    var found = -1;
    for (var i = 0; i + quoted.length <= lines.length; i++) {
      if (at(i) && (found < 0 || score(i) > score(found))) found = i;
    }
    final was = (start, end, outdated);
    if (found >= 0) {
      start = found + 1;
      end = found + quoted.length;
    }
    outdated = found < 0;
    return was != (start, end, outdated);
  }

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
        key: [
          for (final c in value as List)
            ReviewComment.fromJson(c as Map<String, dynamic>),
        ],
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
    writeWhole(_file, jsonEncode(reviews.value));
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
    final side = [
      if (c.old) ' (the old version, before the change)',
      if (c.outdated) ' (they have changed since; they were)',
    ].join();
    var ticks = 3;
    while (c.quote.contains('`' * ticks)) {
      ticks++;
    }
    final fence = '`' * ticks;
    out
      ..write('\n${i + 1}. `${c.path}`, ${c.lines.toLowerCase()}$side:\n')
      ..write('$fence${languageOf(c.path) ?? ''}\n${c.quote}\n$fence\n')
      ..write('${c.text}\n');
  }
  if (note.trim().isNotEmpty) out.write('\n${note.trim()}\n');
  return out.toString();
}

List<ReviewComment> _unsent(String chat) =>
    commentsOf(chat).where((c) => !c.sent).toList();

/// Asks for an overall note, then sends [chat]'s unsent comments to its
/// agent as one message and marks them sent.
Future<void> sendReview(
  BuildContext context,
  Daemon daemon,
  String chat,
) async {
  final note = await showDialog<String>(
    context: context,
    builder: (context) => _SendDialog(
      chat: chat,
      agent: daemon.chats[chat]?.agentName ?? 'the agent',
    ),
  );
  final unsent = _unsent(chat);
  if (note == null || unsent.isEmpty || !context.mounted) return;
  await tryOrShow(context, () async {
    final text = reviewMessage(unsent, note);
    await daemon.client.sendPrompt(
      SendPromptRequest(chatId: chat, text: text, queue: true),
    );
    for (final c in unsent) {
      c.sent = true;
    }
    setComments(chat, [...commentsOf(chat)]);
    if (daemon.chats[chat] case final state?) _untilSent(state, text, unsent);
  });
}

/// Marks [comments] unsent again when the review they went in leaves the
/// chat's queue without reaching its transcript (Stop, Archive, or taken
/// out of the queue): the agent never got them.
void _untilSent(ChatState chat, String text, List<ReviewComment> comments) {
  var queued = false;
  bool sent() => chat.items.any(
    (i) => i.kind == ItemKind.ITEM_KIND_USER_MESSAGE && i.text == text,
  );
  void check() {
    if (!chat.loaded || sent()) {
      if (sent()) chat.removeListener(check);
      return;
    }
    if (chat.queue.any((m) => m.text == text)) {
      queued = true;
    } else if (queued) {
      // Out of the queue: into the transcript, a moment later, or gone.
      Timer(const Duration(seconds: 2), () {
        if (sent() || chat.queue.any((m) => m.text == text)) return;
        chat.removeListener(check);
        for (final c in comments) {
          c.sent = false;
        }
        setComments(chat.id, [...commentsOf(chat.id)]);
      });
    }
  }

  chat.addListener(check);
  check();
}

/// "Send review": what goes, and a box for an overall note; pops the note
/// ('' for none) or null when cancelled.
class _SendDialog extends StatefulWidget {
  const new({required this.chat, required this.agent});

  final String chat;
  final String agent;

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: reviews,
    builder: (context, _, _) => _build(context, _unsent(widget.chat)),
  );

  Widget _build(BuildContext context, List<ReviewComment> unsent) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = unsent.length;
    return nushiDialog(
      'Send review',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            '$n comment${n == 1 ? '' : 's'} go to ${widget.agent} as one '
            'message:',
          ),
          // Every one, those on files the view no longer shows too.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in unsent)
                    Row(
                      spacing: 6,
                      children: [
                        Expanded(
                          child: Text(
                            '${c.path}, ${c.lines.toLowerCase()}: '
                            '${c.text.split('\n').first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.ui(t.textSecondary, size: 12),
                          ),
                        ),
                        IconTap(
                          Icons.close,
                          tooltip: 'Remove',
                          size: 13,
                          onTap: () => setComments(widget.chat, [
                            for (final m in commentsOf(widget.chat))
                              if (m != c) m,
                          ]),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          TextField(
            controller: _note,
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
          onPressed: () => Navigator.pop(context),
        ),
        Button(
          label: 'Send',
          kind: ButtonKind.primary,
          onPressed: n == 0 ? null : () => Navigator.pop(context, _note.text),
        ),
      ],
    );
  }
}
