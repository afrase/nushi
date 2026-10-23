import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'menu.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// [path] with the home folder as "~".
String tildePath(String path) {
  final home = Platform.environment['HOME'] ?? '';
  return home.isNotEmpty && (path == home || path.startsWith('$home/'))
      ? '~${path.substring(home.length)}'
      : path;
}

/// A folder's name and its parent's path ("~" for the home folder), or "No
/// folder" and '' for a scratch folder.
(String, String) folderParts(String folder) {
  if (isScratch(folder)) return ('No folder', '');
  final slash = folder.lastIndexOf('/');
  return (folder.substring(slash + 1), tildePath(folder.substring(0, slash)));
}

/// The chat's folder (in a worktree, its repository's): its name, then its
/// parent path, dimmed, on one line or, [stacked], on two. A click offers
/// the recent folders and "Choose folder…", and moves the chat to the one
/// picked. Not while the agent works or waits on the user.
class FolderButton extends StatelessWidget {
  const FolderButton({
    super.key,
    required this.chat,
    required this.daemon,
    this.stacked = false,
    this.path = true,
  });

  final ChatState chat;
  final Daemon daemon;
  final bool stacked;

  /// Whether the one-line form shows the parent path after the name.
  final bool path;

  Future<void> _move(BuildContext context, String? folder) async {
    folder ??= await getDirectoryPath(
      confirmButtonText: chat.fresh ? 'Open' : 'Move chat here',
    );
    if (folder == null || !context.mounted) return;
    final wt = chat.worktree;
    if (wt != null && !chat.fresh) {
      final move = await confirm(
        context,
        'Move to ${folderParts(folder).$1}?',
        'The chat goes on in ${tildePath(folder)}, knowing the conversation '
            'so far.\n\nIts worktree ${tildePath(wt.path)} and its branch '
            '${wt.branch} stay, with their work. Delete… on the chat offers '
            'to remove them.',
        'Move',
      );
      if (!move || !context.mounted) return;
    }
    await tryOrShow(context, () => daemon.moveChat(chat, folder!));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final enabled =
        daemon.canMove && !chat.archived && !chat.busy && !chat.waiting;
    final recent = daemon.recentFolders.where((f) => f != chat.home).take(8);
    final (name, parent) = folderParts(chat.home);
    final nameStyle = theme.ui(t.text, size: 12, weight: FontWeight.w500);
    final parentStyle = theme.ui(t.textMuted, size: 11.5);
    final chevron = Icon(Icons.expand_more, size: 14, color: t.textMuted);
    return Menu(
      entries: [
        for (final f in recent)
          MenuEntry(
            folderParts(f).$1,
            detail: folderParts(f).$2,
            onPick: () => _move(context, f),
          ),
        if (recent.isNotEmpty) MenuEntry.divider,
        MenuEntry('Choose folder…', onPick: () => _move(context, null)),
      ],
      builder: (context, open) => Tap(
        tooltip: !daemon.canMove || chat.archived
            ? chat.home
            : enabled
            ? 'Change the folder'
            : 'The folder can change once the agent is done',
        onTap: enabled ? open : null,
        padding: stacked
            ? const EdgeInsets.only(left: 6)
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),
                      if (enabled) chevron,
                    ],
                  ),
                  if (parent.isNotEmpty)
                    Text(
                      parent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: parentStyle,
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
