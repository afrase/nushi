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
/// changing and on [flush] (the app going to the back or quitting).
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

  void _load() {
    try {
      final j = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      restoreCommentDrafts((j['boxes'] as Map).cast<String, String>());
      restoreReviewDrafts({
        for (final MapEntry(:key, :value)
            in (j['reviews'] as Map<String, dynamic>).entries)
          key: [
            for (final d in value as List)
              GitHubDraft()..mergeFromProto3Json(d),
          ],
      });
    } on Object {
      // Nothing kept, or it can't be read: drafts start empty.
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
