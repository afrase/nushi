import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/fnv.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/syntax.dart';

/// A review comment on lines [start]–[end] (from 1) of a file's [old] or
/// new side, in the Changes view it was made in ([where]: the scope, the
/// commits in Commits, and a related [worktree]'s folder; [whereIn]).
/// [quote] is those lines as they were, and [before] and [after] the lines
/// around them: when the file changes, the comment moves to where they are
/// now ([anchor]), or is [outdated] when they're gone. Once [sent], it
/// stays (dimmed) until the turn that took it has ended and its lines are
/// outdated or the side changed: [seen] is the side's text as last read
/// before it was sent.
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

  /// Keeps [side] (its hash) as the text the comment is on: true if it
  /// wasn't already.
  bool see(String side) {
    final h = fnv1a(side.codeUnits);
    if (seen == h) return false;
    seen = h;
    return true;
  }

  /// Whether [side] is the text it was on when last seen.
  bool saw(String side) => seen == fnv1a(side.codeUnits);

  String get lines => start == end ? 'Line $start' : 'Lines $start–$end';

  /// The related worktree it was made in, by its folder; null for the
  /// chat's own folder.
  String? get worktree => worktreeOf(where);
}

/// A Changes view's [ReviewComment.where]: [scope] (a Scope's name, or the
/// Commits picked as `commits:<newest>:<oldest>`) of the chat's own folder,
/// or of the related worktree at [worktree] (ADR 0081). A worktree's
/// comments are its own: a file of the same path in the chat's folder
/// shares no comment, draft or sent state with it.
String whereIn(String scope, {String? worktree}) =>
    worktree == null ? scope : '$worktree\n$scope';

/// The related worktree's folder [where] names ([whereIn]), null for the
/// chat's own. A scope has no line break; a folder might.
String? worktreeOf(String where) {
  final i = where.lastIndexOf('\n');
  return i < 0 ? null : where.substring(0, i);
}

/// The scope part of [where] ([whereIn]).
String scopeOf(String where) => where.substring(where.lastIndexOf('\n') + 1);

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
    writeWhole(_file, utf8.encode(jsonEncode(reviews.value)));
  } on Object {
    // Kept until the app quits.
  }
}

/// No chat's comments, in memory (tests: each starts with none).
@visibleForTesting
void forgetReviews() {
  reviews.value = {};
  _sentAs.clear();
}

/// [chat]'s comments.
List<ReviewComment> commentsOf(String chat) => reviews.value[chat] ?? const [];

/// Settles [chat]'s comments made in [where] with its files read
/// ([files], as the view shows them now): each follows its lines
/// ([ReviewComment.anchor]), and one whose file left the view (committed,
/// reverted) is outdated. An unsent one keeps its side's text as read
/// ([ReviewComment.see]). While the chat is [idle], a sent one whose card no
/// message still waits to take (in the box or the queue) went with a turn
/// that has ended: it's dropped once its lines are outdated, its file left
/// the view, or its side changed since it was sent (the owner shouldn't
/// have to clean these up).
void filesRead(
  ChatState chat,
  String where,
  List<FileChange> files, {
  required bool idle,
}) {
  var changed = false;
  final kept = <ReviewComment>[];
  for (final c in commentsOf(chat.id)) {
    if (c.where != where) {
      kept.add(c);
      continue;
    }
    final f = files.where((f) => f.path == c.path).firstOrNull;
    final done = idle && c.sent && !_cardWaits(chat, c);
    if (f == null) {
      if (done) {
        changed = true;
        continue;
      }
      if (!c.outdated) changed = c.outdated = true;
    } else {
      final side = c.old ? f.oldText : f.newText;
      if (c.anchor(side)) changed = true;
      if (!c.sent || c.seen == null) {
        // Unsent, or sent before Nushi kept the text it was sent on.
        if (c.see(side)) changed = true;
      } else if (done && (c.outdated || !c.saw(side))) {
        changed = true;
        continue;
      }
    }
    kept.add(c);
  }
  if (changed) setComments(chat.id, kept);
}

/// The lead line of the user's own review comments in a message.
const myReviewComments = 'My review comments on your changes:';

/// The lead line of the cards of a related worktree's comments (ADR 0081):
/// they go to the chat's own agent, as the subagent has usually exited, so
/// it names the worktree's folder and branch, which their paths are of.
String worktreeComments(String folder, RelatedWorktree? w) {
  final branch = plainName(w?.branch ?? '');
  final head = w?.lastHead ?? '';
  final short = head.substring(0, min(7, head.length));
  return [
    _worktreeLead(folder),
    if (branch.isNotEmpty) ' on branch `$branch`',
    if (w != null && w.state != 'present' && head.isNotEmpty)
      ' (removed since: its last commit is `$short`)',
    ', its paths relative to that folder:',
  ].join();
}

/// How [worktreeComments] starts for [folder], whatever became of it.
String _worktreeLead(String folder) =>
    'My review comments on the changes in the worktree `${plainName(folder)}`';

/// A review comment as a reply card in the chat's box (the reply-card
/// model the Pull request tab's Send to agent uses): the quote is the
/// file, the lines and their text in a fence, the reply the comment. Its
/// lead is [from]: a related worktree's names it ([worktreeComments]).
Reply reviewReply(ReviewComment c, {String from = myReviewComments}) {
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
    // The user's own: Claude took them for a reviewer's once.
    from: from,
  );
}

/// [chat]'s comments not yet in a message.
List<ReviewComment> unsentComments(String chat) =>
    commentsOf(chat).where((c) => !c.sent).toList();

/// Puts [chat]'s unsent comments in its box as reply cards, to go with
/// the next message, and marks them sent; one taken out of the box
/// without being sent is removed ([_untilSent]). The chat then shows its
/// transcript and box: the review is done by the time it's sent.
void reviewToBox(ChatState chat) {
  final unsent = unsentComments(chat.id);
  if (unsent.isEmpty) return;
  String lead(ReviewComment c) => switch (c.worktree) {
    final path? => worktreeComments(
      path,
      chat.related.list.where((w) => w.path == path).firstOrNull,
    ),
    null => myReviewComments,
  };
  // Each worktree's together, after the chat's own: one lead a group.
  final byPlace = <String?, List<ReviewComment>>{};
  for (final c in unsent) {
    (byPlace[c.worktree] ??= []).add(c);
  }
  final cards = {
    for (final c in [
      ...?byPlace.remove(null),
      ...byPlace.values.expand((g) => g),
    ])
      c: _sentAs[c.id] = reviewReply(c, from: lead(c)),
  };
  cards.values.forEach(chat.draft.addReply);
  for (final c in unsent) {
    c.sent = true;
  }
  setComments(chat.id, [...commentsOf(chat.id)]);
  _untilSent(chat, cards);
  chat.tab.value = ChatTab.chat;
}

/// Whether [c]'s card waits to go to the agent ([_waiting]): its card as it
/// was put in the box, or (after a restart) any card on its file and lines'
/// text under its place's lead; the comment may have moved or become
/// outdated since.
bool _cardWaits(ChatState chat, ReviewComment c) {
  bool of(Reply x) =>
      x.quote.startsWith('`${c.path}`, ') &&
      x.quote.contains('\n${c.quote}\n') &&
      switch (c.worktree) {
        final path? => x.from.startsWith(_oneLine(_worktreeLead(path))),
        null => x.from == myReviewComments,
      };
  if (_sentAs[c.id] case final r?) return _waiting(chat, r);
  return _led(chat.draft.replies.value).any(of) ||
      chat.queue.any((m) => _led(splitReplies(m.text).$1).any(of));
}

/// Each comment's card as it was put in the box, by the comment's id: the
/// comment moves or becomes outdated after, and its card stays as it was.
final Map<String, Reply> _sentAs = runMap();

/// The texts of [chat]'s messages in its transcript, but for those in
/// [before] (by id): an earlier message may quote the same lines.
Iterable<String> _said(ChatState chat, Set<String> before) => [
  for (final i in chat.items)
    if (i.kind == ItemKind.ITEM_KIND_USER_MESSAGE && !before.contains(i.id))
      i.text,
];

/// [cards], each with its group's lead on one line, as [withReplies]
/// writes it: [splitReplies] gives it to a group's first card only, and a
/// queued message taken back to edit puts its cards in the box so.
List<Reply> _led(List<Reply> cards) {
  var lead = '';
  return [
    for (final x in cards)
      (
        quote: x.quote,
        text: x.text,
        from: lead = x.from.isEmpty ? lead : _oneLine(x.from),
      ),
  ];
}

/// [lead] on one line, as [withReplies] writes it.
String _oneLine(String lead) => lead.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Whether [x] (its lead as [_led] has it) is the card [r], by its quote and
/// lead: its text may be edited, and a worktree's file may have the chat's
/// path and lines.
bool _isCard(Reply x, Reply r) =>
    x.quote == r.quote.trim() && x.from == _oneLine(r.from);

/// Whether a message in [texts] has the card [r] ([_isCard]).
bool _carried(Iterable<String> texts, Reply r) =>
    texts.any((text) => _led(splitReplies(text).$1).any((x) => _isCard(x, r)));

/// Whether [r] waits to go to the agent: in [chat]'s box, or in a message
/// in its queue.
bool _waiting(ChatState chat, Reply r) =>
    _led(chat.draft.replies.value).any((x) => _isCard(x, r)) ||
    _carried([for (final m in chat.queue) m.text], r);

/// Follows each comment's card until a message in the transcript has it.
/// One that leaves the box and the queue without that (the card removed,
/// the box cleared, its queued message removed) is removed: the user took
/// it out, and it never comes back on its own (the owner's call: it came
/// back with the next Send to agent when it was only unsent). A queued
/// message taken back to edit puts its cards in the box again, still
/// followed.
void _untilSent(ChatState chat, Map<ReviewComment, Reply> cards) {
  final open = {...cards};
  final before = {for (final i in chat.items) i.id};
  final checking = <ReviewComment>{};
  late final VoidCallback check;
  void settled(ReviewComment c) {
    open.remove(c);
    if (open.isNotEmpty) return;
    chat.draft.replies.removeListener(check);
    chat.removeListener(check);
  }

  check = () {
    for (final c in [...open.keys]) {
      final r = open[c]!;
      if (_carried(_said(chat, before), r)) {
        settled(c);
      } else if (!_waiting(chat, r) && checking.add(c)) {
        // Sending moves it from the box into a message a moment later.
        Timer(const Duration(seconds: 2), () {
          checking.remove(c);
          if (!open.containsKey(c) || _waiting(chat, r)) return;
          settled(c);
          if (_carried(_said(chat, before), r)) return;
          _sentAs.remove(c.id);
          setComments(chat.id, [
            for (final m in commentsOf(chat.id))
              if (m != c) m,
          ]);
        });
      }
    }
  };
  chat.draft.replies.addListener(check);
  chat.addListener(check);
}
