import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show GitHubDraft;
import 'package:nushi/github_review.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_edit.dart';

/// The Mac's GitHub and Jira drafts across a restart (ADR 0073): the
/// comment boxes' text, each pull request's unsent inline comments and
/// what each open title or description edit began from, in
/// `comment_drafts.json` in the data folder, written whole (0600), gone
/// once none is left. Read here at start, saved [delay] after they stop
/// changing and on [flush] (the app going to the back or quitting). Read
/// by [readKept]'s rule: a file that doesn't parse is set aside, one with
/// a draft that doesn't read is copied aside and the rest saved over it
/// at once, and one that can't be read at all isn't written over until a
/// save reads it.
final class CommentDraftFile {
  new(String dir, {this.delay = Waits.save})
    : _file = File('$dir/comment_drafts.json') {
    _load();
    _changes.addListener(_changed);
  }

  final Duration delay;
  final File _file;
  final _changes = Listenable.merge([commentDraftsChanged, draftsChanged]);
  Timer? _timer;

  /// The file couldn't be read: nothing is saved over it until a save's
  /// read works.
  bool _unread = false;

  /// Reads the file and puts its drafts back; [again] after a launch
  /// that couldn't, when the drafts made since win over its own.
  void _load({bool again = false}) {
    final Map<String, Object?> j;
    try {
      j = readKept(_file).json;
    } on Object {
      _unread = true;
      return;
    }
    _unread = false;
    var dropped = false;
    void drop() => dropped = true;
    final boxes = _strings(j['boxes'], drop);
    // None in a file from before edits were kept.
    final began = _strings(j['began'], drop);
    final reviews = <String, List<GitHubDraft>>{};
    switch (j['reviews']) {
      case null:
        break;
      case final Map<String, Object?> m:
        for (final MapEntry(:key, :value) in m.entries) {
          final drafts = <GitHubDraft>[];
          for (final d in value is List ? value : [value]) {
            if (_draft(d) case final draft?) {
              drafts.add(draft);
            } else {
              dropped = true;
            }
          }
          if (drafts.isNotEmpty) reviews[key] = drafts;
        }
      default:
        dropped = true;
    }
    if (dropped) {
      try {
        copyAside(_file);
      } on Object {
        _unread = true; // not copied: not written over either
      }
    }
    if (again) {
      boxes.addAll(keptCommentDrafts);
      reviews.addAll({
        for (final MapEntry(:key, :value) in keptReviewDrafts.entries)
          if (value.isNotEmpty) key: value,
      });
      began.addAll(keptPullEdits);
    }
    restoreCommentDrafts(boxes);
    restoreReviewDrafts(reviews);
    restorePullEdits(began);
    // The rest written back at once, so the next launch copies nothing.
    if (dropped && !_unread) _write();
  }

  /// [j]'s text entries, if it's a map; [drop] hears of anything else.
  static Map<String, String> _strings(Object? j, void Function() drop) {
    if (j == null) return {};
    if (j is! Map<String, Object?>) {
      drop();
      return {};
    }
    final strings = <String, String>{};
    for (final MapEntry(:key, :value) in j.entries) {
      if (value is String) {
        strings[key] = value;
      } else {
        drop();
      }
    }
    return strings;
  }

  /// A pull request's inline comment as kept, or null when it doesn't read.
  static GitHubDraft? _draft(Object? d) {
    try {
      return GitHubDraft()..mergeFromProto3Json(d, ignoreUnknownFields: true);
    } on Object {
      return null;
    }
  }

  void _changed() {
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Saves what changed since the last save, now.
  void flush() {
    final waiting = _timer;
    if (waiting == null) return;
    waiting.cancel();
    _timer = null;
    if (_unread) _load(again: true);
    if (_unread) return; // kept in memory; the next save reads again
    _write();
  }

  /// Writes the drafts kept now over the file, or removes it when there's
  /// none.
  void _write() {
    final reviews = {
      for (final MapEntry(:key, :value) in keptReviewDrafts.entries)
        if (value.isNotEmpty) key: [for (final d in value) d.toProto3Json()],
    };
    try {
      if (keptCommentDrafts.isEmpty &&
          reviews.isEmpty &&
          keptPullEdits.isEmpty) {
        if (_file.existsSync()) _file.deleteSync();
      } else {
        final j = {
          'boxes': keptCommentDrafts,
          'reviews': reviews,
          'began': keptPullEdits,
        };
        writeWhole(_file, utf8.encode(jsonEncode(j)));
      }
    } on Object {
      // Kept in memory; the next change tries again.
    }
  }

  /// Stops following the drafts (tests: the next file reads them).
  @visibleForTesting
  void close() {
    _timer?.cancel();
    _changes.removeListener(_changed);
  }
}
