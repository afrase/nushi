import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'theme/theme.dart';

/// The chat's folder: its name, then its parent path, dimmed ("No folder"
/// for a scratch folder), on one line or, [stacked], on two. A click offers
/// the recent folders and "Choose folder…", and moves the chat to the one
/// picked. Not while the agent works or waits on the user.
class FolderButton extends StatelessWidget {
  const FolderButton({
    super.key,
    required this.chat,
    required this.daemon,
    this.stacked = false,
  });

  final ChatState chat;
  final Daemon daemon;
  final bool stacked;

  Future<void> _pick(BuildContext context) async {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final box = context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(box.size.bottomLeft(Offset.zero));
    final recent = daemon.recentFolders.where((f) => f != chat.folder).take(8);
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        for (final f in recent)
          PopupMenuItem(
            value: f,
            height: 30,
            child: _FolderName(f, theme: theme, maxWidth: 360),
          ),
        if (recent.isNotEmpty) const PopupMenuDivider(height: 9),
        PopupMenuItem(
          value: '',
          height: 30,
          child: Text('Choose folder…', style: theme.ui(t.text)),
        ),
      ],
    );
    if (picked == null || !context.mounted) return;
    final folder = picked.isNotEmpty
        ? picked
        : await getDirectoryPath(confirmButtonText: 'Move chat here');
    if (folder == null || !context.mounted) return;
    await tryOrShow(context, () => daemon.moveChat(chat.id, folder));
  }

  /// The name, and the parent path under it, to the right.
  Widget _stacked(NushiTheme theme, bool enabled) {
    final t = theme.t;
    final folder = chat.folder;
    final slash = folder.lastIndexOf('/');
    final scratch = isScratch(folder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                scratch ? 'No folder' : folder.substring(slash + 1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
              ),
            ),
            if (enabled)
              Icon(Icons.expand_more, size: 14, color: t.textSecondary),
          ],
        ),
        if (!scratch)
          Text(
            _home(folder.substring(0, slash)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textMuted, size: 11.5),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final enabled =
        daemon.canMove && !chat.archived && !chat.busy && !chat.waiting;
    return Tooltip(
      message: !daemon.canMove || chat.archived
          ? chat.folder
          : enabled
          ? 'Change the folder'
          : 'The folder can change once the agent is done',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        borderRadius: BorderRadius.circular(NushiTheme.control),
        onTap: enabled ? () => _pick(context) : null,
        child: Padding(
          padding: stacked
              ? const EdgeInsets.only(left: 6)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: stacked
              ? _stacked(theme, enabled)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: t.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: _FolderName(chat.folder, theme: theme)),
                    if (enabled) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.expand_more, size: 14, color: t.textMuted),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// A folder's name, then its parent path in small, dimmed print.
class _FolderName extends StatelessWidget {
  const _FolderName(this.folder, {required this.theme, this.maxWidth});

  final String folder;
  final NushiTheme theme;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = theme.t;
    final slash = folder.lastIndexOf('/');
    final text = Text.rich(
      TextSpan(
        children: isScratch(folder)
            ? [TextSpan(text: 'No folder', style: theme.ui(t.text, size: 12))]
            : [
                TextSpan(
                  text: folder.substring(slash + 1),
                  style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
                ),
                TextSpan(
                  text: '  ${_home(folder.substring(0, slash))}',
                  style: theme.ui(t.textMuted, size: 11.5),
                ),
              ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return maxWidth == null
        ? text
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: text,
          );
  }
}

/// [path] with the home folder as "~".
String _home(String path) {
  final home = Platform.environment['HOME'] ?? '';
  return home.isNotEmpty && (path == home || path.startsWith('$home/'))
      ? '~${path.substring(home.length)}'
      : path;
}
