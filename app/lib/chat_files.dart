import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/preview.dart';

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
    if (it.toolKind == 'delete') {
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

/// The folder of [path] as [chatFiles] names it: '' for one at the top of
/// the chat's folder.
String folderOf(String path) {
  final slash = path.lastIndexOf('/');
  if (slash < 0) return '';
  final dir = path.substring(0, slash);
  return path.startsWith('/') ? tildePath(dir.isEmpty ? '/' : dir) : dir;
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
  if (changed != null) ago(DateTime.now().difference(changed), changed),
].where((s) => s.isNotEmpty).join(' · ');

/// A menu of [chat]'s files ([chatFiles]; [current] checked, first when
/// it isn't one of them), opened from [label] in a compact field; a pick
/// opens the file's preview. When each changed is read as it opens.
class FilesMenu extends StatefulWidget {
  const new({
    required this.chat,
    required this.files,
    required this.label,
    super.key,
    this.current,
    this.tooltip = '',
  });

  final ChatState chat;
  final List<String> files;
  final Widget label;
  final String? current;
  final String tooltip;

  @override
  State<FilesMenu> createState() => _FilesMenuState();
}

class _FilesMenuState extends State<FilesMenu> {
  Map<String, DateTime?> _changed = const {};

  List<String> get _files => [
    if (widget.current case final c? when !widget.files.contains(c)) c,
    ...widget.files,
  ];

  void _read() => setState(
    () => _changed = {
      for (final f in _files) f: fileChanged(absoluteIn(widget.chat.folder, f)),
    },
  );

  @override
  Widget build(BuildContext context) => MenuField(
    compact: true,
    tooltip: widget.tooltip,
    label: widget.label,
    onOpen: _read,
    entries: [
      for (final f in _files)
        MenuEntry(
          baseName(f),
          detail: fileDetail(f, _changed[f]),
          checked: f == widget.current,
          tooltip: f,
          onPick: () => widget.chat.openPreview(f),
        ),
    ],
  );
}
