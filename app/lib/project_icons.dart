import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The projects' own icons (ADR 0112): each folder's asked of the daemon
/// once, the first time its tile shows, and the answer, an image or none,
/// kept until the app quits. The app never reads a project's files
/// itself. It tells its listeners as each answer comes.
class ProjectIcons extends ChangeNotifier {
  new(this.fetch, {this.whenBack});

  /// Asks the daemon for a folder's icon (GetProjectIcon): its bytes, or
  /// none when the folder has no icon.
  final Future<Uint8List?> Function(String folder) fetch;

  /// Calls its argument once the daemon is back (`Daemon.whenBack`): an
  /// ask that failed while it was gone, or of a daemon too old to answer,
  /// is made again then.
  final VoidCallback Function(VoidCallback again)? whenBack;

  final _answers = <String, MemoryImage?>{};
  final _asked = <String>{};
  final _failed = <String>{};
  bool _waits = false;

  /// [folder]'s icon, if it has one and the answer is here; asks for it
  /// the first time.
  MemoryImage? of(String folder) {
    if (folder.isNotEmpty && _asked.add(folder)) unawaited(_ask(folder));
    return _answers[folder];
  }

  Future<void> _ask(String folder) async {
    try {
      final bytes = await fetch(folder);
      _answers[folder] = bytes == null || bytes.isEmpty
          ? null
          : MemoryImage(bytes);
      if (_answers[folder] != null) notifyListeners();
    } on Object {
      // No icon for now: the tile shows the project's initials.
      _failed.add(folder);
      if (!_waits && whenBack != null) {
        _waits = true;
        whenBack!(_again);
      }
    }
  }

  void _again() {
    _waits = false;
    final again = {..._failed};
    _failed.clear();
    for (final folder in again) {
      unawaited(_ask(folder));
    }
  }
}
