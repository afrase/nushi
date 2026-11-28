import 'dart:io';
import 'dart:math' show max;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

/// The artifacts ([isArtifact]) [items] wrote, edited or showed (a
/// subagent's calls too, and the files the workflows they launched wrote:
/// Workflow.written, API 156), or with [any] every file they wrote or
/// edited (one only shown wasn't written), each once, the one changed last
/// first; a file deleted since is left out. A workflow's files sit among
/// the items by when they changed, as the daemon places them (chats'
/// writtenBy): at each item a clock moves up to the item's time
/// ([_itemTime], or stays), the files changed not after it go in, oldest
/// first, and then the item, so an item at a file's time is the later; a
/// file whose time isn't known takes the clock at its launch, and those
/// changed after every item go in last. [before] is
/// what items before them wrote, the one changed last first
/// (GetChatResponse.older_written):
/// [items] go over it, so going over items it already counts changes
/// nothing. Each by one name, however the agent named it ([relativeIn] the
/// chat's [folder]): relative to it when inside it, as the daemon names a
/// written file. With [runs], it is filled with the run that changed
/// each file last ([runName]), for each file a workflow changed last.
List<String> chatFiles(
  Iterable<Item> items, {
  String folder = '',
  bool any = false,
  Iterable<String> before = const [],
  Map<String, String>? runs,
}) {
  String name(String p) => relativeIn(folder, p);
  final files = <String>{}; // in the order last changed
  void wrote(String p, [String? run]) {
    if (!any && !isArtifact(p)) return;
    files
      ..remove(p)
      ..add(p);
    if (run != null) {
      runs?[p] = run;
    } else {
      runs?.remove(p);
    }
  }

  before.toList().reversed.map(name).forEach(wrote);
  final ran = _workflowFiles(items);
  var next = 0;
  var clock = 0; // the latest time an item so far says
  for (final it in items) {
    clock = max(clock, _itemTime(it));
    // A tie goes in first: an item of the same millisecond is the later.
    for (; next < ran.length && ran[next].changed <= clock; next++) {
      wrote(name(ran[next].path), ran[next].run);
    }
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
      for (final p in it.paths.map(name)) {
        files.remove(p);
        runs?.remove(p);
      }
    } else if (it.toolKind == 'edit' || it.diffs.isNotEmpty) {
      <String>{
        ...it.paths.map(name),
        for (final d in it.diffs) name(d.path),
      }.forEach(wrote);
    }
  }
  for (final f in ran.skip(next)) {
    wrote(name(f.path), f.run); // changed after every item
  }
  return files.toList().reversed.toList();
}

/// The files the workflows [items] launched wrote, the one changed first
/// first, each with when it changed in Unix ms (one whose time isn't known
/// at its launch's: the latest time an item up to it says) and the run's
/// name ([runName]).
List<({String path, int changed, String run})> _workflowFiles(
  Iterable<Item> items,
) {
  final out = <({String path, int changed, String run})>[];
  var clock = 0;
  for (final it in items) {
    clock = max(clock, _itemTime(it));
    if (!it.hasWorkflow()) continue;
    final run = runName(it.workflow);
    for (final f in it.workflow.written.reversed) {
      final t = f.changed.toInt();
      // A file with no time whose launch has none either takes the time of
      // the last item before it that has one, and as a tie goes in before
      // that item: below a file the chat wrote before the run began. A
      // quirk of the rule, kept: the daemon's writtenBy does the same, and
      // the two lists must agree.
      out.add((path: f.path, changed: t == 0 ? clock : t, run: run));
    }
  }
  // List.sort isn't stable: the index keeps a run's own order on a tie.
  final order = [...out.indexed]
    ..sort(
      (a, b) => switch (a.$2.changed.compareTo(b.$2.changed)) {
        0 => a.$1.compareTo(b.$1),
        final c => c,
      },
    );
  return [for (final (_, f) in order) f];
}

/// A run's name as its card shows it: its script's name, its id while it
/// has none.
String runName(Workflow w) => w.name.isNotEmpty ? w.name : w.runId;

/// When the daemon saw [it], in Unix ms: a call's start (which follows the
/// items' order, where a long call's end would jump past its children),
/// else its end, a message's sending; 0 when it didn't (a replay).
int _itemTime(Item it) => [
  it.started,
  it.ended,
  it.sent,
].firstWhere((t) => t != 0, orElse: () => Int64.ZERO).toInt();

/// [chatFiles] of a chat's items, all of them and those of its last turn
/// (from the last message of the user's on), and every file it wrote, as
/// of its items' revision and its folder (a chat can move); all and every
/// file reach past the loaded items to what the older ones wrote (issue
/// #62). Its workflows name the run that changed each file last, for the
/// files a workflow changed last.
typedef _Written = ({
  int revision,
  String folder,
  List<String> all,
  Set<String> last,
  Set<String> any,
  Map<String, String> workflows,
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
  // What the items not loaded wrote, as the daemon said and trimmed items
  // left it (ChatState.olderWritten); none from a daemon before
  // olderWrittenApi, whose chat lists only what's loaded.
  final before = chat.olderWritten ?? const <String>[];
  // A workflow still running before the loaded part writes on: what it
  // wrote since the daemon's list (or a trim) counted its files.
  final all = [
    for (final it in chat.runningBefore.where((it) => it.hasWorkflow()))
      _since(it, chat.olderRunFiles[it.id]),
    ...items,
  ];
  final runs = <String, String>{};
  return _written[chat] = (
    revision: chat.revision,
    folder: folder,
    all: chatFiles(all, folder: folder, before: before),
    last: chatFiles(items.skip(turn + 1), folder: folder).toSet(),
    any: chatFiles(
      all,
      folder: folder,
      any: true,
      before: before,
      runs: runs,
    ).toSet(),
    workflows: runs,
  );
}

/// A workflow's call [it] with only the files it wrote or changed again
/// since [counted] (each file's time then) was taken.
Item _since(Item it, Map<String, int>? counted) {
  if (counted == null || counted.isEmpty) return it;
  final w = it.workflow;
  return Item(
    id: it.id,
    kind: it.kind,
    status: it.status,
    toolKind: it.toolKind,
    started: it.started,
    ended: it.ended,
    sent: it.sent,
    workflow: Workflow(
      runId: w.runId,
      name: w.name,
      written: [
        for (final f in w.written)
          if (counted[f.path] != f.changed.toInt()) f,
      ],
    ),
  );
}

/// The name ([runName]) of the workflow that changed [file] last in
/// [chat], null when none of its loaded workflows did or the chat changed
/// it since: the Artifacts widget's row says so.
String? writtenByWorkflow(ChatState chat, String file) =>
    _writtenBy(chat).workflows[file];

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
  // Sets, not lists' contains: a workflow's thousand files would make
  // each build quadratic.
  final listed = files.toSet();
  final pinned = <String>{
    for (final p in pins)
      if (listed.contains(p)) p,
  };
  bool recent(String f) =>
      last.contains(f) ||
      f == open ||
      (opened[f] != null && now.difference(opened[f]!) < openedRecent);
  var fresh = <String>{
    for (final f in files)
      if (!pinned.contains(f) && recent(f)) f,
  };
  if (pinned.isEmpty && fresh.isEmpty) {
    fresh = files.take(recentAtLeast).toSet();
  }
  return (
    pinned: pinned.toList(),
    recent: fresh.toList(),
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
/// A file whose folder is gone (a worktree removed once its branch
/// merged, beside the chat's folder or under it) is left out
/// ([inGoneFolder]); one gone from a folder still there stays, a "Gone"
/// row.
Artifacts chatArtifacts(ChatState chat, {bool pins = true}) {
  final written = _writtenBy(chat);
  return sortArtifacts(
    [
      for (final f in written.all)
        if (!inGoneFolder(chat.folder, f)) f,
    ],
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

/// The file [chat]'s file tabs show, by its artifact's name ([relativeIn]).
String? openArtifact(ChatState chat) => switch (chat.shownFile) {
  final p? => relativeIn(chat.folder, p),
  null => null,
};

/// What [chatArtifacts] reads, to build again when it changes: the
/// minute's tick too, for a folder looked at again ([inGoneFolder]).
Listenable artifactsOf(ChatState chat) => Listenable.merge([
  chat,
  chat.files.shown,
  chat.opened,
  pinnedFiles,
  minuteClock,
]);

/// Whether the folder at an absolute path is there; true where that can't
/// be known (the phone, which keeps its whole list). Tests set their own.
bool Function(String folder) folderThere = _folderThere;

bool _folderThere(String folder) => kIsWeb || Directory(folder).existsSync();

/// Whether each folder [inGoneFolder] looked at was there, and when it
/// looked.
final Map<String, ({bool there, DateTime at})> _folders = runMap();

/// How long what [inGoneFolder] found of a folder holds.
const folderLooked = Duration(minutes: 1);

/// Whether [file], as [chatFiles] names it in the chat's [folder], is in a
/// folder that is gone: a worktree removed once its branch merged takes
/// all its files at once, one beside the chat's folder (an absolute name)
/// as one under it (Claude's `.claude/worktrees/<name>`, a relative
/// name). Each folder is looked at once (one stat for a run's many files
/// in it), and again at the first build after [folderLooked] (the widget
/// builds on the minute's tick), not per file nor per frame.
bool inGoneFolder(String folder, String file) {
  final path = absoluteIn(folder, file);
  final dir = path.substring(0, max(1, path.lastIndexOf('/')));
  final now = clock();
  if (_folders[dir] case final had?
      when now.difference(had.at) < folderLooked) {
    return !had.there;
  }
  final there = folderThere(dir);
  _folders[dir] = (there: there, at: now);
  return !there;
}

/// Whether a missing time from [fileChanged] means the file isn't there:
/// false on the phone, which can't look.
const bool filesLooked = !kIsWeb;

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
  if (pins.length == had) {
    pins.add(file);
    // Pinned, a provisional tab of it is kept (ADR 0070).
    if (chat.files.provisional.value case final p?
        when relativeIn(chat.folder, p.path) == file) {
      chat.files.keep(p);
    }
  }
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
/// it last changed ("docs, 2m ago").
String fileDetail(String path, DateTime? changed) => [
  folderOf(path),
  if (changed != null) ago(clock().difference(changed), changed),
].where((s) => s.isNotEmpty).join(', ');
