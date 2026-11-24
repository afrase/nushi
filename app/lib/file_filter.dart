import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/tree_rows.dart';

// The Files pane's filter: any file of the folder by name, as a tree.

/// How well [path] matches [query], lower better, or null for no match:
/// each word of the query in the file's name (its start best), else in its
/// path, else its letters in order in the name, then in the path; a
/// shorter path before a longer among equals.
int? matchScore(String path, String query) {
  final lower = path.toLowerCase();
  final name = lower.substring(lower.lastIndexOf('/') + 1);
  var score = 0;
  for (final w in query.toLowerCase().split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    final s = name.startsWith(w)
        ? 0
        : name.contains(w)
        ? 1
        : lower.contains(w)
        ? 2
        : _inOrder(name, w)
        ? 3
        : _inOrder(lower, w)
        ? 4
        : null;
    if (s == null) return null;
    score += s;
  }
  return score * 10000 + path.length;
}

/// Whether [w]'s letters are in [s], in order.
bool _inOrder(String s, String w) {
  var at = 0;
  for (final c in w.codeUnits) {
    at = s.indexOf(String.fromCharCode(c), at);
    if (at < 0) return false;
    at++;
  }
  return true;
}

/// The most files a filter shows.
const filterShows = 200;

/// What a filter found: its rows, the best match, and whether more matched
/// than it shows ([filterShows]).
typedef FilterFound = ({List<TreeRow> rows, String? best, bool capped});

/// The rows of the files [paths] that match [query], as a tree: their
/// folders open above them, folders first, each by name; at most
/// [filterShows] of the best, and the best match.
FilterFound filterRows(Iterable<String> paths, String query) {
  final scored = <(int, String)>[
    for (final p in paths)
      if (matchScore(p, query) case final s?) (s, p),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2.compareTo(b.$2));
  final hits = [for (final (_, p) in scored.take(filterShows)) p];
  final root = _Dir();
  for (final p in hits) {
    final parts = p.split('/');
    var d = root;
    for (final part in parts.take(parts.length - 1)) {
      d = d.dirs[part] ??= _Dir();
    }
    d.files.add(parts.last);
  }
  int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  final rows = <TreeRow>[];
  void walk(_Dir d, String at, int depth) {
    for (final name in d.dirs.keys.toList()..sort(byName)) {
      final path = at.isEmpty ? name : '$at/$name';
      rows.add(TreeRow(path, name, depth, TreeRowKind.folder, open: true));
      walk(d.dirs[name]!, path, depth + 1);
    }
    for (final name in d.files..sort(byName)) {
      rows.add(TreeRow(at.isEmpty ? name : '$at/$name', name, depth, .file));
    }
  }

  walk(root, '', 0);
  return (
    rows: rows,
    best: hits.firstOrNull,
    capped: scored.length > filterShows,
  );
}

/// [filterRows] of a tree's listings and git's list, worked out again only
/// when the query, the tree ([FolderTree.revision]) or git's list changes:
/// a pane rebuilds at every chunk its chat streams, and the filter of a
/// large folder takes 10 to 25 ms.
class FilterMemo {
  Object? _key;
  FilterFound? _found;

  /// The rows for [query] in [tree] and [git].
  FilterFound of(FolderTree tree, GitFiles git, String query) {
    // git's list is replaced, never changed: the same list is the same.
    final key = (query, tree.revision, git.paths);
    if (_found case final found? when key == _key) return found;
    _key = key;
    return _found = filterRows(filterPaths(tree, git.paths), query);
  }
}

class _Dir {
  final dirs = <String, _Dir>{};
  final files = <String>[];
}

/// Each daemon's folders' [GitFiles], while it lasts: a phone paired with
/// another Mac (a new [Daemon]) never filters with the last one's names
/// for a folder at the same path.
final _gitFiles = Expando<Map<String, GitFiles>>('git files');

/// [folder]'s one [GitFiles] on [daemon]: the Files pane's filter, the
/// phone's, `@` and ⌘P read the same list.
GitFiles gitFilesOf(Daemon daemon, String folder) =>
    (_gitFiles[daemon] ??= {})[folder] ??= GitFiles._(daemon, folder);

/// A folder's files as git lists them (ListFiles: what it doesn't
/// ignore), for a filter, `@` or ⌘P: asked when one starts, and again
/// once they're a few seconds old, so files the agent adds come in. A
/// listing that fails keeps the last list and says why ([error]).
class GitFiles extends ChangeNotifier {
  new _(this.daemon, this.folder);

  final Daemon daemon;
  final String folder;
  List<String> paths = const [];

  /// Why the last listing failed, in words; '' once one answers.
  String error = '';

  /// Whether a listing answered or failed yet.
  bool listed = false;

  DateTime? _at;

  /// Asks [daemon] for the folder's files, unless it did a moment ago (by
  /// the app's [clock], which a test moves).
  void ask() {
    final at = _at;
    final now = clock();
    if (at != null && now.difference(at).inSeconds <= 5) return;
    _at = now;
    unawaited(
      daemon.client
          .listFiles(ListFilesRequest(folder: folder))
          .then(
            (r) {
              paths = r.paths;
              error = '';
              listed = true;
              notifyListeners();
            },
            onError: (Object e) {
              error = errorText(e);
              listed = true;
              notifyListeners();
            },
          ),
    );
  }
}

/// The paths a filter looks through: the folder's files as git lists them
/// ([GitFiles]), and every file listed in the folders that show, the
/// ignored too while they show.
Set<String> filterPaths(FolderTree tree, List<String> gitFiles) => {
  ...gitFiles,
  ...tree.listedFiles,
};
