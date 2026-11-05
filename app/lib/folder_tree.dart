import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tree_rows.dart';

/// The daemon's API that has WatchChatFolder.
const filesApi = 103;

/// A chat's folder as the Files pane shows it: the folders open, each one's
/// entries as the daemon last listed them (WatchChatFolder, one stream for
/// each folder in sight, kept while the pane is), and the row the keys are
/// on. Lazy: a folder is listed when it opens. It lasts while the app runs
/// ([folderTreeOf]), so the pane opens again as it was.
class FolderTree extends ChangeNotifier {
  new(this.chat) : _folder = chat.folder;

  final ChatState chat;

  /// The folders open, by path ('' is the chat's folder, always open).
  final open = <String>{};

  /// The row the keys are on, by path.
  String? selected;

  /// Each folder's listing as last sent, by path.
  final _listed = <String, FolderListing>{};

  /// Why a folder can't be listed, by path.
  final _refused = <String, String>{};

  final _subs = <String, StreamSubscription<WatchChatFolderResponse>>{};
  Daemon? _daemon;
  int _users = 0;
  String _folder; // the chat's, as listed: a moved chat starts again

  /// Starts listing what's in sight, for a pane that shows it. Only while
  /// one does it follows [filesIgnored], so a chat no pane shows is let go
  /// with its tree; what it missed meanwhile is asked again.
  void attach(Daemon daemon) {
    _daemon = daemon;
    if (_users++ == 0) {
      filesIgnored.addListener(_ignoredChanged);
      _refused.clear();
    }
    _sync();
  }

  /// Ends the listing when no pane shows it.
  void detach() {
    if (--_users > 0) return;
    filesIgnored.removeListener(_ignoredChanged);
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  /// Opens [folder], or closes it.
  void toggle(String folder) => setOpen(folder, open: !open.contains(folder));

  /// Opens or closes [folder].
  void setOpen(String folder, {required bool open}) {
    if (open ? !this.open.add(folder) : !this.open.remove(folder)) return;
    if (open) _refused.remove(folder); // asked again
    _sync();
    notifyListeners();
  }

  /// Puts the keys on [path].
  void select(String path) {
    if (selected == path) return;
    selected = path;
    notifyListeners();
  }

  /// A file to scroll to once its row is listed, for the pane to take.
  String? revealing;

  /// Opens the folders above [path], puts the keys on it, and asks the pane
  /// to scroll to it ([revealing]).
  void reveal(String path) {
    for (final f in _ancestors(path)) {
      setOpen(f, open: true);
    }
    selected = revealing = path;
    notifyListeners();
  }

  /// The folders whose entries show: the chat's, and each open one whose
  /// folders above are open too.
  Set<String> get _shown => {
    '',
    for (final f in open)
      if (_ancestors(f).every(open.contains)) f,
  };

  void _sync() {
    if (chat.folder != _folder) {
      _folder = chat.folder;
      _listed.clear();
      _refused.clear();
      for (final s in _subs.values) {
        unawaited(s.cancel());
      }
      _subs.clear();
    }
    if (_users == 0) return;
    final shown = _shown;
    for (final f in [..._subs.keys]) {
      if (!shown.contains(f)) unawaited(_subs.remove(f)!.cancel());
    }
    for (final f in shown) {
      if (!_subs.containsKey(f) && !_refused.containsKey(f)) _watch(f);
    }
  }

  void _watch(String folder) {
    final daemon = _daemon;
    if (daemon == null) return;
    _subs[folder] = daemon.client
        .watchChatFolder(
          WatchChatFolderRequest(
            chatId: chat.id,
            path: folder,
            ignored: filesIgnored.value,
          ),
        )
        .listen(
          (r) {
            for (final l in r.folders) {
              _listed[l.path] = l;
            }
            notifyListeners();
          },
          onError: (Object e) {
            _subs.remove(folder);
            // Refused: it stays so until it's opened again. Anything else
            // (the daemon went away): list again.
            if (e is ConnectException && e.code != Code.unavailable) {
              _refused[folder] = e.message;
              notifyListeners();
            } else {
              _again(folder);
            }
          },
          onDone: () {
            if (_subs.remove(folder) != null) _again(folder);
          },
          cancelOnError: true,
        );
  }

  void _again(String folder) => Timer(const Duration(seconds: 2), () {
    if (_users > 0 && !_subs.containsKey(folder)) _sync();
  });

  /// Lists everything again for what [filesIgnored] says: what shows
  /// meanwhile stays, so nothing blinks.
  void _ignoredChanged() {
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _refused.clear();
    _sync();
  }

  /// Every file listed so far (the ignored too, while they show), by
  /// path: what a filter looks through besides git's list.
  Iterable<String> get listedFiles sync* {
    for (final l in _listed.values) {
      for (final e in l.entries) {
        if (e.kind == 'file') {
          yield l.path.isEmpty ? e.name : '${l.path}/${e.name}';
        }
      }
    }
  }

  /// The tree's rows, as it shows now: folders first, an open folder's
  /// entries under it.
  List<TreeRow> rows() {
    _sync();
    final rows = <TreeRow>[];
    void walk(String folder, int depth) {
      final l = _listed[folder];
      if (_refused[folder] case final why?) {
        rows.add(TreeRow(folder, '', depth, TreeRowKind.note, note: why));
        return;
      }
      if (l == null) {
        rows.add(TreeRow(folder, '', depth, TreeRowKind.note, note: '…'));
        return;
      }
      if (l.missing || l.entries.isEmpty && l.more == 0) {
        rows.add(TreeRow(folder, '', depth, TreeRowKind.note, note: 'Empty'));
        return;
      }
      for (final e in l.entries) {
        final path = folder.isEmpty ? e.name : '$folder/${e.name}';
        final kind = switch (e.kind) {
          'folder' => TreeRowKind.folder,
          'file' => TreeRowKind.file,
          'link' => TreeRowKind.link,
          _ => TreeRowKind.other,
        };
        final isOpen = kind == TreeRowKind.folder && open.contains(path);
        rows.add(
          TreeRow(
            path,
            e.name,
            depth,
            kind,
            open: isOpen,
            ignored: e.ignored,
            linked: e.linked,
            size: e.size.toInt(),
            modified: e.modifiedMs == 0
                ? null
                : DateTime.fromMillisecondsSinceEpoch(e.modifiedMs.toInt()),
          ),
        );
        if (isOpen) walk(path, depth + 1);
      }
      if (l.more > 0) {
        rows.add(TreeRow(folder, '', depth, TreeRowKind.more, count: l.more));
      }
    }

    walk('', 0);
    return rows;
  }
}

final _trees = Expando<FolderTree>();

/// [chat]'s tree, made the first time it's asked for.
FolderTree folderTreeOf(ChatState chat) => _trees[chat] ??= FolderTree(chat);

/// The folders above [path] ('a/b/c': 'a', 'a/b').
Iterable<String> _ancestors(String path) sync* {
  for (var i = path.indexOf('/'); i >= 0; i = path.indexOf('/', i + 1)) {
    yield path.substring(0, i);
  }
}

/// The folder [path] is in ('' at the top).
String parentOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? '' : path.substring(0, slash);
}

/// The folders holding the files [wrote] names inside the chat's folder,
/// each once: a closed one holding a written file is marked too.
Set<String> foldersOf(Iterable<String> wrote) => {
  for (final f in wrote)
    if (!f.startsWith('/')) ..._ancestors(f),
};

/// The files [chat] wrote, and the folders holding them, for the tree's
/// marks.
({Set<String> files, Set<String> folders}) writtenMarks(ChatState chat) {
  final files = chatWrote(chat);
  return (files: files, folders: foldersOf(files));
}
