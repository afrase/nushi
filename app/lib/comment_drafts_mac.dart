import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show GitHubDraft;
import 'package:nushi/github_review.dart';
import 'package:nushi/motion.dart';

/// The Mac's GitHub and Jira drafts across a restart (ADR 0073): the
/// comment boxes' text and each pull request's unsent inline comments, in
/// `comment_drafts.json` in the data folder, written whole (0600), gone
/// once none is left. Read here at start, saved [delay] after they stop
/// changing and on [flush] (the app going to the back or quitting). Read
/// by [readKept]'s rule: a file that doesn't parse is set aside, one with
/// a draft that doesn't read is copied aside before the rest is saved
/// over it, and one that can't be read at all isn't written over in this
/// run.
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

  /// The file couldn't be read: nothing is saved over it.
  bool _unread = false;

  void _load() {
    final Map<String, Object?> j;
    try {
      j = readKept(_file).json;
    } on Object {
      _unread = true;
      return;
    }
    var dropped = false;
    final boxes = <String, String>{};
    switch (j['boxes']) {
      case null:
        break;
      case final Map<String, Object?> m:
        for (final MapEntry(:key, :value) in m.entries) {
          if (value is String) {
            boxes[key] = value;
          } else {
            dropped = true;
          }
        }
      default:
        dropped = true;
    }
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
    restoreCommentDrafts(boxes);
    restoreReviewDrafts(reviews);
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
    if (_unread) return; // kept in memory until the app quits
    final reviews = {
      for (final MapEntry(:key, :value) in keptReviewDrafts.entries)
        if (value.isNotEmpty) key: [for (final d in value) d.toProto3Json()],
    };
    try {
      if (keptCommentDrafts.isEmpty && reviews.isEmpty) {
        if (_file.existsSync()) _file.deleteSync();
      } else {
        final j = {'boxes': keptCommentDrafts, 'reviews': reviews};
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
