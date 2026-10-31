import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

/// The artifacts ([isArtifact]) [items] wrote or edited (a subagent's
/// calls too), each once, the one changed last first; a file deleted
/// since is left out. As the tool rows name them: relative to the chat's
/// folder when inside it.
List<String> chatFiles(Iterable<Item> items) {
  final files = <String>{}; // in the order last changed
  for (final it in items) {
    if (it.kind != ItemKind.ITEM_KIND_TOOL_CALL || it.status == 'failed') {
      continue;
    }
    if (isShow(it)) {
      if (previewPath(it) case final p?) {
        files
          ..remove(p)
          ..add(p);
      }
    } else if (it.toolKind == 'delete') {
      files.removeAll(it.paths);
    } else if (it.toolKind == 'edit' || it.diffs.isNotEmpty) {
      for (final p in {...it.paths, for (final d in it.diffs) d.path}) {
        if (!isArtifact(p)) continue;
        files
          ..remove(p)
          ..add(p);
      }
    }
  }
  return files.toList().reversed.toList();
}

/// [chatFiles] of a chat's items, all of them and those of its last turn
/// (from the last message of the user's on), as of its items' revision.
typedef _Written = ({int revision, List<String> all, Set<String> last});

final _written = Expando<_Written>();

_Written _writtenBy(ChatState chat) {
  final had = _written[chat];
  if (had != null && had.revision == chat.revision) return had;
  final items = chat.items;
  final turn = items.lastIndexWhere(
    (it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE && it.parent.isEmpty,
  );
  return _written[chat] = (
    revision: chat.revision,
    all: chatFiles(items),
    last: chatFiles(items.skip(turn + 1)).toSet(),
  );
}

/// [chatFiles] of [chat]'s items, worked out again only when they changed
/// but by text streaming in ([ChatState.revision]): every chunk builds the
/// details panel, which asks a few times.
List<String> chatFilesOf(ChatState chat) => _writtenBy(chat).all;

/// A chat's artifacts ([chatFiles]) in the order the owner cares about
/// them: the pinned (in the order pinned), then the recent (newest
/// first), and the rest, the older (newest first), folded away. The
/// header's button counts the pinned and the recent.
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
/// not [pins] (the phone: they're kept in the Mac's `app.json`).
Artifacts chatArtifacts(ChatState chat, {bool pins = true}) {
  final written = _writtenBy(chat);
  return sortArtifacts(
    written.all,
    last: written.last,
    now: clock(),
    pins: pins ? pinnedFiles.value[chat.id] ?? const [] : const [],
    open: chat.preview.value,
    opened: chat.opened.value,
  );
}

/// What [chatArtifacts] reads, to build again when it changes.
Listenable artifactsOf(ChatState chat) =>
    Listenable.merge([chat, chat.preview, chat.opened, pinnedFiles]);

/// Whether [file] is pinned in [chat].
bool pinned(ChatState chat, String file) =>
    pinnedFiles.value[chat.id]?.contains(file) ?? false;

/// Pins [file] in [chat] (last of its pins), or unpins it.
void togglePin(ChatState chat, String file) {
  final pins = [...?pinnedFiles.value[chat.id]];
  if (!pins.remove(file)) pins.add(file);
  pinnedFiles.value = {
    for (final MapEntry(:key, :value) in pinnedFiles.value.entries)
      if (key != chat.id) key: value,
    if (pins.isNotEmpty) chat.id: pins,
  };
}

/// A row's pin: filled and always shown when pinned, else an outline shown
/// only while [hover] (on the Mac, over its row).
Widget pinMark(ChatState chat, String file, {required bool hover}) {
  final on = pinned(chat, file);
  // The same room shown or not, so a row's text doesn't move.
  if (!on && !hover) return const SizedBox(width: 19);
  return Builder(
    builder: (context) => IconTap(
      on ? Icons.push_pin : Icons.push_pin_outlined,
      size: 13,
      padding: 3,
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

/// Opens the file the user picked in [chat]: its preview tab if it has one,
/// a new one with ⌘ held, else the side pane. The agent's `show` opens the
/// pane instead, whatever is held or open (ADR 0068).
void pickFile(ChatState chat, String path) {
  if (HardwareKeyboard.instance.isMetaPressed || chat.tabOf(path) != null) {
    chat.openTab(path);
  } else {
    chat.openPreview(path);
  }
}

/// [path] (relative to [folder], or absolute) as an absolute path.
String absoluteIn(String folder, String path) =>
    path.startsWith('/') ? path : '$folder/$path';

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

/// A menu of [chat]'s artifacts ([chatArtifacts]): the pinned, the recent,
/// then "Older (n)" opening the rest beside it; [current] checked, first
/// when it isn't one of them. Each row's pin shows on hover. Opened from
/// [label] (given the sorted artifacts) in a compact field; a pick opens
/// the file's preview. When each changed is read as it opens.
class FilesMenu extends StatefulWidget {
  const new({
    required this.chat,
    required this.label,
    super.key,
    this.current,
    this.tooltip,
  });

  final ChatState chat;
  final Widget Function(Artifacts artifacts) label;
  final String? current;
  final String Function(Artifacts artifacts)? tooltip;

  @override
  State<FilesMenu> createState() => _FilesMenuState();
}

class _FilesMenuState extends State<FilesMenu> {
  Map<String, DateTime?> _changed = const {};

  void _read(List<String> files) => setState(
    () => _changed = {
      for (final f in files) f: fileChanged(absoluteIn(widget.chat.folder, f)),
    },
  );

  MenuEntry _entry(String f) => MenuEntry(
    baseName(f),
    detail: fileDetail(f, _changed[f]),
    checked: f == widget.current,
    tooltip: f,
    onPick: () => pickFile(widget.chat, f),
    action: ({required hover}) => ListenableBuilder(
      listenable: pinnedFiles,
      builder: (context, _) => pinMark(widget.chat, f, hover: hover),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: artifactsOf(widget.chat),
    builder: (context, _) {
      final a = chatArtifacts(widget.chat);
      final shown = [
        if (widget.current case final c?
            when !a.pinned.contains(c) && !a.recent.contains(c))
          c,
        ...a.pinned,
        ...a.recent,
      ];
      final older = [
        for (final f in a.older)
          if (f != widget.current) f,
      ];
      return MenuField(
        compact: true,
        tooltip: widget.tooltip?.call(a) ?? '',
        label: widget.label(a),
        onOpen: () => _read([...shown, ...older]),
        entries: [
          for (final f in shown) _entry(f),
          if (older.isNotEmpty) ...[
            if (shown.isNotEmpty) MenuEntry.divider,
            MenuEntry(
              'Older (${older.length})',
              submenu: [for (final f in older) _entry(f)],
            ),
          ],
        ],
      );
    },
  );
}
