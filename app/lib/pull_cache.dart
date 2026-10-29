import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The pull requests last read whole, so a chat's Pull request tab and
/// its PR widget show them at once (and after the app restarts), asked
/// again behind them: in memory, and each in `pulls/` in the data folder
/// (the protobuf as the daemon sent it, 0600 in a 0700 folder; its file's
/// time is when it was read). The [_keep] most recent.
const _keep = 50;

Directory get _dir => Directory('$dataDir/pulls');

final _known = <String, (DateTime, GitHubPull)>{};

/// A file name for [ref]: its host, repository and number, from
/// GitHub's characters only (else not kept).
String? _name(GitHubRef ref) {
  final key = '${ref.host}_${ref.repo.replaceAll('/', '_')}_${ref.number}';
  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(key) &&
          !key.startsWith('.') &&
          ref.number > 0
      ? '$key.pb'
      : null;
}

/// [ref]'s pull request as last read, and when; null when never (or not
/// readable).
(DateTime, GitHubPull)? cachedPull(GitHubRef ref) {
  final name = _name(ref);
  if (name == null) return null;
  if (_known[name] case final k?) return k;
  try {
    final f = File('${_dir.path}/$name');
    if (!f.existsSync()) return null;
    final k = (
      f.lastModifiedSync(),
      GitHubPull.fromBuffer(f.readAsBytesSync()),
    );
    return _known[name] = k;
  } on Object {
    return null;
  }
}

/// Keeps [p] as [ref]'s pull request, read now.
void keepPull(GitHubRef ref, GitHubPull p) {
  final name = _name(ref);
  if (name == null) return;
  final was = _known[name]?.$2;
  _known[name] = (clock(), p);
  if (was == p) return _touch(name); // the same: only when
  try {
    if (!_dir.existsSync()) {
      _dir.createSync(recursive: true);
      setMode(_dir.path, 0x1c0);
    }
    final tmp = File('${_dir.path}/$name.tmp')
      ..writeAsBytesSync(p.writeToBuffer(), flush: true);
    setMode(tmp.path, 0x180);
    tmp.renameSync('${_dir.path}/$name');
    _touch(name);
    _prune();
  } on Object {
    // Not kept on disk; memory still has it until the app quits.
  }
}

void _touch(String name) {
  try {
    File('${_dir.path}/$name').setLastModifiedSync(clock());
  } on Object {
    // Its time stays older: it says so, nothing more.
  }
}

/// Drops all but the [_keep] most recent.
void _prune() {
  final files = _dir.listSync().whereType<File>().toList();
  if (files.length <= _keep) return;
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  for (final f in files.skip(_keep)) {
    _known.remove(f.uri.pathSegments.last);
    f.deleteSync();
  }
}

/// Forgets every kept pull request, in memory and, unless [disk] is
/// false (an app's restart), on disk (tests).
@visibleForTesting
void forgetPulls({bool disk = true}) {
  _known.clear();
  if (disk && _dir.existsSync()) _dir.deleteSync(recursive: true);
}
