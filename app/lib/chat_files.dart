import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

/// The artifacts ([isArtifact]) [items] wrote, edited or showed (a
/// subagent's calls too), or with [any] every file they wrote or edited
/// (one only shown wasn't written), each once, the one changed last
/// first; a file deleted since is left out. Each by one name, however the
/// agent named it ([relativeIn] the chat's [folder]): relative to it when
/// inside it, as the daemon names a written file.
List<String> chatFiles(
  Iterable<Item> items, {
  String folder = '',
  bool any = false,
}) {
  String name(String p) => relativeIn(folder, p);
  final files = <String>{}; // in the order last changed
  for (final it in items) {
    if (it.kind != ItemKind.ITEM_KIND_TOOL_CALL || it.status == 'failed') {
      continue;
    }
    if (isShow(it)) {
      if (previewPath(it) case final p? when !any) {
        files
          ..remove(name(p))
          ..add(name(p));
      }
    } else if (it.toolKind == 'delete') {
      files.removeAll(it.paths.map(name));
    } else if (it.toolKind == 'edit' || it.diffs.isNotEmpty) {
      for (final p in {
        ...it.paths.map(name),
        for (final d in it.diffs) name(d.path),
      }) {
        if (!any && !isArtifact(p)) continue;
        files
          ..remove(p)
          ..add(p);
      }
    }
  }
  return files.toList().reversed.toList();
}

/// [chatFiles] of a chat's items, all of them and those of its last turn
/// (from the last message of the user's on), and every file it wrote, as
/// of its items' revision and its folder (a chat can move).
typedef _Written = ({
  int revision,
  String folder,
  List<String> all,
  Set<String> last,
  Set<String> any,
});

final _written = Expando<_Written>();

_Written _writtenBy(ChatState chat) {
  final had = _written[chat];
  final folder = chat.folder;
  if (had != null && had.revision == chat.revision && had.folder == folder) {
    return had;
  }
  final items = chat.items;
  final turn = items.lastIndexWhere(
    (it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE && it.parent.isEmpty,
  );
  return _written[chat] = (
    revision: chat.revision,
    folder: folder,
    all: chatFiles(items, folder: folder),
    last: chatFiles(items.skip(turn + 1), folder: folder).toSet(),
    any: chatFiles(items, folder: folder, any: true).toSet(),
  );
}

/// [chatFiles] of [chat]'s items, worked out again only when they changed
/// but by text streaming in ([ChatState.revision]): every chunk builds the
/// details panel, which asks a few times.
List<String> chatFilesOf(ChatState chat) => _writtenBy(chat).all;

/// Every file [chat]'s tool calls wrote or edited, code and text too, as
/// [chatFiles] names them: the Files pane marks them.
Set<String> chatWrote(ChatState chat) => _writtenBy(chat).any;

/// A chat's artifacts ([chatFiles]) in the order the owner cares about
/// them: the pinned (in the order pinned), then the recent (newest
/// first), and the rest, the older (newest first), folded away. The
/// panel's Artifacts widget, collapsed, counts the pinned and the recent.
typedef Artifacts = ({
  List<String> pinned,
  List<String> recent,
  List<String> older,
});

/// How long a file opened stays among the recent.
const openedRecent = Duration(hours: 1);

/// When nothing is pinned or recent (an old chat come back to), this many
/// of the newest show as recent.
const recentAtLeast = 3;

/// A chat's artifacts, [files] ([chatFiles]), sorted: [pins] first, then
/// the recent: those the agent wrote in the last turn ([last]), [open] (the
/// file the preview shows), and those [opened] within [openedRecent] of
/// [now]; the others older. With nothing pinned or recent, the
/// [recentAtLeast] newest are the recent.
Artifacts sortArtifacts(
  List<String> files, {
  required Set<String> last,
  required DateTime now,
  List<String> pins = const [],
  String? open,
  Map<String, DateTime> opened = const {},
}) {
  final pinned = [
    for (final p in pins)
      if (files.contains(p)) p,
  ];
  bool recent(String f) =>
      last.contains(f) ||
      f == open ||
      (opened[f] != null && now.difference(opened[f]!) < openedRecent);
  var fresh = [
    for (final f in files)
      if (!pinned.contains(f) && recent(f)) f,
  ];
  if (pinned.isEmpty && fresh.isEmpty) {
    fresh = files.take(recentAtLeast).toList();
  }
  return (
    pinned: pinned,
    recent: fresh,
    older: [
      for (final f in files)
        if (!pinned.contains(f) && !fresh.contains(f)) f,
    ],
  );
}

/// [chat]'s artifacts sorted ([sortArtifacts]) now, with its pins unless
/// not [pins] (the phone: they're kept in the Mac's `app.json`). The open
/// file and the pins go by the artifacts' names ([relativeIn]): a show
/// call's row opens its file by the agent's.
Artifacts chatArtifacts(ChatState chat, {bool pins = true}) {
  final written = _writtenBy(chat);
  return sortArtifacts(
    written.all,
    last: written.last,
    now: clock(),
    pins: [
      ...{
        if (pins)
          for (final p in pinnedFiles.value[chat.id] ?? const <String>[])
            relativeIn(chat.folder, p),
      },
    ],
    open: openArtifact(chat),
    opened: chat.opened.value,
  );
}

/// The file [chat]'s preview shows, by its artifact's name ([relativeIn]).
String? openArtifact(ChatState chat) => switch (chat.preview.value) {
  final p? => relativeIn(chat.folder, p),
  null => null,
};

/// What [chatArtifacts] reads, to build again when it changes.
Listenable artifactsOf(ChatState chat) =>
    Listenable.merge([chat, chat.preview, chat.opened, pinnedFiles]);

/// Whether [file] is pinned in [chat], by whatever name it was.
bool pinned(ChatState chat, String file) =>
    pinnedFiles.value[chat.id]?.any(
      (p) => relativeIn(chat.folder, p) == file,
    ) ??
    false;

/// Pins [file] in [chat] (last of its pins), or unpins it.
void togglePin(ChatState chat, String file) {
  final pins = [...?pinnedFiles.value[chat.id]];
  final had = pins.length;
  pins.removeWhere((p) => relativeIn(chat.folder, p) == file);
  if (pins.length == had) pins.add(file);
  pinnedFiles.value = {
    for (final MapEntry(:key, :value) in pinnedFiles.value.entries)
      if (key != chat.id) key: value,
    if (pins.isNotEmpty) chat.id: pins,
  };
}

/// A row's pin, in its icon's place ([icon], 15 square): filled and
/// always shown when pinned, else an outline shown only while [hover] (on
/// the Mac, over its row).
Widget pinMark(
  ChatState chat,
  String file, {
  required bool hover,
  required Widget icon,
}) {
  final on = pinned(chat, file);
  if (!on && !hover) return icon;
  return Builder(
    builder: (context) => IconTap(
      on ? Icons.push_pin : Icons.push_pin_outlined,
      size: 13,
      padding: 1,
      color: on ? NushiTheme.of(context).t.text : null,
      tooltip: on ? 'Unpin' : 'Pin: always first',
      onTap: () => togglePin(chat, file),
    ),
  );
}

/// The folder of [path] as [chatFiles] names it: '' for one at the top of
/// the chat's folder.
String folderOf(String path) {
  final slash = path.lastIndexOf('/');
  if (slash < 0) return '';
  final dir = path.substring(0, slash);
  return path.startsWith('/') ? tildePath(dir.isEmpty ? '/' : dir) : dir;
}

/// When the file at an absolute path last changed; null when it isn't
/// there, or can't be known (the phone). Tests set their own.
DateTime? Function(String path) fileChanged = _modified;

DateTime? _modified(String path) {
  if (kIsWeb) return null;
  final s = FileStat.statSync(path);
  return s.type == FileSystemEntityType.notFound ? null : s.modified;
}

/// What a file's row says under or beside its name: its folder, and when
/// it last changed ("docs · 2m ago").
String fileDetail(String path, DateTime? changed) => [
  folderOf(path),
  if (changed != null) ago(clock().difference(changed), changed),
].where((s) => s.isNotEmpty).join(' · ');
