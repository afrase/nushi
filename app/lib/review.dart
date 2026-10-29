import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/syntax.dart';

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

/// A review comment as a reply card in the chat's box (the reply-card
/// model the Pull request tab's Send to agent uses): the quote is the
/// file, the lines and their text in a fence, the reply the comment.
Reply reviewReply(ReviewComment c) {
  final side = [
    if (c.old) ' (the old version, before the change)',
    if (c.outdated) ' (they have changed since; they were)',
  ].join();
  var ticks = 3;
  while (c.quote.contains('`' * ticks)) {
    ticks++;
  }
  final fence = '`' * ticks;
  return (
    quote:
        '`${c.path}`, ${c.lines.toLowerCase()}$side:\n'
        '$fence${languageOf(c.path) ?? ''}\n${c.quote}\n$fence',
    text: c.text,
  );
}

/// [chat]'s comments not yet in a message.
List<ReviewComment> unsentComments(String chat) =>
    commentsOf(chat).where((c) => !c.sent).toList();

/// Puts [chat]'s unsent comments in its box as reply cards, to go with
/// the next message, and marks them sent; one taken out of the box
/// without being sent is unsent again ([_untilSent]).
void reviewToBox(ChatState chat) {
  final unsent = unsentComments(chat.id);
  if (unsent.isEmpty) return;
  final cards = {for (final c in unsent) c: reviewReply(c)};
  cards.values.forEach(chat.draft.addReply);
  for (final c in unsent) {
    c.sent = true;
  }
  setComments(chat.id, [...commentsOf(chat.id)]);
  _untilSent(chat, cards);
}

/// Whether a message with [r] (its quote: its text may be edited) is in
/// [chat]'s transcript or queue.
bool _gone(ChatState chat, Reply r) => [
  for (final i in chat.items)
    if (i.kind == ItemKind.ITEM_KIND_USER_MESSAGE) i.text,
  for (final m in chat.queue) m.text,
].any((text) => splitReplies(text).$1.any((x) => x.quote == r.quote.trim()));

/// Marks a comment unsent again when its card leaves the box without a
/// message taking it (removed, or the box cleared): the agent never got
/// it. Stops following once each card went or came back.
void _untilSent(ChatState chat, Map<ReviewComment, Reply> cards) {
  final open = {...cards};
  void check() {
    bool inBox(Reply r) =>
        chat.draft.replies.value.any((x) => x.quote == r.quote);
    open.removeWhere((c, r) {
      if (inBox(r)) return false;
      if (!_gone(chat, r)) {
        // Sending moves it from the box into a message a moment later.
        Timer(const Duration(seconds: 2), () {
          if (_gone(chat, r) || inBox(r)) return;
          c.sent = false;
          setComments(chat.id, [...commentsOf(chat.id)]);
        });
      }
      return true;
    });
    if (open.isEmpty) {
      chat.draft.replies.removeListener(check);
      chat.removeListener(check);
    }
  }

  chat.draft.replies.addListener(check);
  chat.addListener(check);
}
