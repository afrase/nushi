import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// [path] with the home folder as "~".
String tildePath(String path) {
  // The phone doesn't know the Mac's home folder: /Users/<name> it is.
  final home = kIsWeb
      ? RegExp('^/Users/[^/]+').stringMatch(path) ?? ''
      : Platform.environment['HOME'] ?? '';
  return home.isNotEmpty && (path == home || path.startsWith('$home/'))
      ? '~${path.substring(home.length)}'
      : path;
}

/// A folder's name and its parent's path ("~" for the home folder), or "No
/// folder" and '' for a [scratch] folder.
(String, String) folderParts(String folder, {bool scratch = false}) {
  if (scratch) return ('No folder', '');
  final slash = folder.lastIndexOf('/');
  return (folder.substring(slash + 1), tildePath(folder.substring(0, slash)));
}

/// The recent folders as menu entries ([skip] left out, [checked] ticked),
/// then "Choose folder…", which picks null.
List<MenuEntry> folderEntries(
  Daemon daemon, {
  required void Function(String? folder) onPick,
  String? skip,
  String? checked,
}) {
  final recent = recentFolders(daemon.chats.values)
      .where((f) => f != skip)
      .take(8);
  return [
    for (final f in recent)
      MenuEntry(
        folderParts(f).$1,
        detail: folderParts(f).$2,
        checked: f == checked,
        onPick: () => onPick(f),
      ),
    if (recent.isNotEmpty) MenuEntry.divider,
    MenuEntry('Choose folder…', onPick: () => onPick(null)),
  ];
}

/// The chat's folder (in a worktree, its repository's): its name, then its
/// parent path, dimmed, on one line or, [stacked], on two. A click offers
/// the repository's other [worktrees] (given for a new chat, so it can
/// start in one), the recent folders and "Choose folder…", and moves the
/// chat to the one picked. Not while the agent works or waits on the user.
class FolderButton extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    super.key,
    this.stacked = false,
    this.path = true,
    this.worktrees = const [],
  });

  final ChatState chat;
  final Daemon daemon;
  final bool stacked;
  final List<GitWorktree> worktrees;

  /// Whether the one-line form shows the parent path after the name.
  final bool path;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final enabled = !chat.archived && !chat.busy && !chat.waiting;
    final (name, parent) = folderParts(chat.home, scratch: chat.scratch);
    final nameStyle = theme.ui(t.text, size: 12, weight: FontWeight.w500);
    final parentStyle = theme.ui(t.textMuted, size: 11.5);
    final chevron = Icon(Icons.expand_more, size: 14, color: t.textMuted);
    final others = worktrees.where((w) => !w.current).toList();
    return Menu(
      entries: [
        if (others.isNotEmpty) ...[
          MenuEntry.heading('Worktrees of $name'),
          for (final w in others)
            MenuEntry(
              w.branch.isEmpty ? 'detached HEAD' : w.branch,
              detail: w.main
                  ? 'the repository'
                  : folderParts(w.path).$1 + (w.locked ? ' · locked' : ''),
              tooltip: tildePath(w.path),
              onPick: () => moveChat(context, daemon, chat, to: w.path),
            ),
          MenuEntry.divider,
        ],
        ...folderEntries(
          daemon,
          skip: chat.home,
          onPick: (f) => moveChat(context, daemon, chat, to: f),
        ),
      ],
      builder: (context, open) => Tap(
        tooltip: chat.archived
            ? chat.home
            : enabled
            ? ''
            : 'Once the agent is done',
        onTap: enabled ? open : null,
        padding: stacked
            ? const EdgeInsets.only(left: 6)
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: stacked
            // The chevron beside both lines, so the parent's right edge
            // lines up with the name's.
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                        if (parent.isNotEmpty)
                          Text(
                            parent,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: parentStyle,
                          ),
                      ],
                    ),
                  ),
                  // Flush with the card's other values (MenuField's flush).
                  if (enabled)
                    Transform.translate(
                      offset: const Offset(2, 0),
                      child: chevron,
                    ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined, size: 14, color: t.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: name, style: nameStyle),
                          if (path)
                            TextSpan(text: '  $parent', style: parentStyle),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (enabled) ...[const SizedBox(width: 2), chevron],
                ],
              ),
      ),
    );
  }
}

/// The chats' folders (in a worktree, its repository's), the newest chat's
/// first, scratch folders left out.
List<String> recentFolders(Iterable<ChatState> chats) {
  final byNewest = chats.toList()
    ..sort((a, b) => b.created.compareTo(a.created));
  return {
    for (final c in byNewest)
      if (!c.scratch) c.home,
  }.toList();
}

/// Moves [chat] to [to], or a folder picked, asking first when it leaves a
/// worktree with its work; [gone]: its folder is gone, so it leaves nothing.
Future<void> moveChat(
  BuildContext context,
  Daemon daemon,
  ChatState chat, {
  String? to,
  bool gone = false,
}) async {
  final folder =
      to ??
      await getDirectoryPath(
        confirmButtonText: chat.fresh ? 'Open' : 'Move chat here',
      );
  if (folder == null || !context.mounted) return;
  final wt = chat.worktree;
  if (wt != null && !wt.found && !chat.fresh && !gone) {
    final move = await confirm(
      context,
      'Move to ${folderParts(folder).$1}?',
      'Its worktree ${tildePath(wt.path)} and branch ${wt.branch} stay, '
          'with their work; Delete offers to remove them.',
      'Move',
    );
    if (!move || !context.mounted) return;
  }
  await tryOrShow(context, () => daemon.moveChat(chat, folder));
}
