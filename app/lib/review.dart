import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'syntax.dart';
import 'widgets.dart';

/// A review comment on lines [start]–[end] (from 1) of a file's [old] or
/// new side, in the Changes view it was made in ([where]: the scope, and
/// the commits in Commits). [quote] is those lines as they were, and
/// [before] and [after] the lines around them: when the file changes, the
/// comment moves to where they are now ([anchor]), or is [outdated] when
/// they're gone. Once [sent], it stays (dimmed) until the file changes
/// after the agent's reply: [seen] is the file's text as the first look
/// after it found it.
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
    this.before = '',
    this.after = '',
    this.sent = false,
    this.outdated = false,
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
        before: j['before'] ?? '',
        after: j['after'] ?? '',
        sent: j['sent'] ?? false,
        outdated: j['outdated'] ?? false,
        seen: j['seen'],
      );

  final String id, where, path, quote, before, after;
  final bool old;
  int start, end;
  String text;
  bool sent, outdated;
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
  bool anchor(String text) {
    final lines = text.split('\n'), quoted = quote.split('\n');
    bool at(int i) =>
        i >= 0 &&
        i + quoted.length <= lines.length &&
        Iterable<int>.generate(quoted.length)
            .every((k) => lines[i + k] == quoted[k]);
    var found = at(start - 1) ? start - 1 : -1;
    if (found < 0) {
      // Where the lines are now; with several, where the lines around
      // them match best, then the nearest.
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

      for (var i = 0; i + quoted.length <= lines.length; i++) {
        if (at(i) && (found < 0 || score(i) > score(found))) found = i;
      }
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
    final side = [
      if (c.old) ' (the old version, before the change)',
      if (c.outdated) ' (they have changed since; they were)',
    ].join();
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
      SendPromptRequest(
        chatId: chat,
        text: reviewMessage(unsent, note.text),
        queue: daemon.canQueue,
      ),
    );
    for (final c in unsent) {
      c.sent = true;
    }
    setComments(chat, [...commentsOf(chat)]);
  });
}
