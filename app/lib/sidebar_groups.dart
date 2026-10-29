import 'package:flutter/material.dart';
import 'package:nushi/card_list.dart' show reordered;
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The sidebar's project groups ([sidebarGroups]), each a header and its
/// chats. A header is the folder's name on one line, its path in its
/// tooltip; two projects of the same name show their parents after it. A
/// group moves by dragging its header, the others sliding apart where it
/// would go ([SlideList]; the order is kept in [sidebarOrder]); the
/// header's chevron collapses it (kept in [sidebarCollapsed]). A collapsed
/// group shows the most urgent of its chats' states as one dot beside its
/// name, and of its rows only the selected chat's.
class SidebarGroups extends StatelessWidget {
  const new({
    required this.groups,
    required this.selectedId,
    required this.starting,
    required this.row,
    required this.onNew,
    required this.onTerminal,
    super.key,
  });

  final Map<String, List<ChatState>> groups;
  final String? selectedId;

  /// The folder a chat is starting in, while one is.
  final String? starting;
  final Widget Function(ChatState chat, Movable movable) row;

  /// A new chat in a folder ('' for none); null while one starts.
  final void Function(String folder)? onNew;

  /// A terminal in a folder, in one of its group's chats.
  final void Function(String folder, List<ChatState> chats) onTerminal;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final entries = groups.entries.toList();
    final parents = twinParents(groups.keys);
    return SlideList<_Moving>(
      count: entries.length,
      accepts: (_) => true,
      onMove: (from, to) => sidebarOrder.value = reordered(
        sidebarOrder.value,
        groups.keys.toList(),
        from,
        to,
      ),
      item: (i, drag) {
        final MapEntry(key: folder, value: chats) = entries[i];
        final shown = [...shownChats(folder, chats, selectedId)];
        return Column(
          key: ValueKey(folder),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              folder,
              twin: parents[folder] ?? '',
              chats: chats,
              collapsed: sidebarCollapsed.value.contains(folder),
              onNew: switch (onNew) {
                final f? => () => f(folder),
                null => null,
              },
              onTerminal: folder.isEmpty || chats.isEmpty
                  ? null
                  : () => onTerminal(folder, chats),
              drag: drag,
            ),
            if (starting == folder)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                child: Text(
                  'Starting…',
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ),
            MovableRows(
              group: folder,
              chats: shown,
              row: row,
              onMove: (from, to) => moveInProject(folder, shown, from, to),
            ),
          ],
        );
      },
    );
  }
}

/// What a header's drag carries: its group's folder.
class _Moving {
  const new(this.folder);

  final String folder;
}

/// Moves the chat at [from] of [shown] (the rows of [folder]'s group) to
/// [to], in [sidebarChats]; a chat it doesn't show (pinned, archived)
/// keeps its place there.
void moveInProject(String folder, List<ChatState> shown, int from, int to) {
  sidebarChats.value = {
    ...sidebarChats.value,
    folder: reordered(
      sidebarChats.value[folder] ?? const [],
      [for (final c in shown) c.id],
      from,
      to,
    ),
  };
}

/// For the folders of [folders] that share their name with another: what
/// tells them apart, their parent's name ("work" for ~/work/app), or its
/// path when that's shared too.
Map<String, String> twinParents(Iterable<String> folders) {
  final byName = <String, List<String>>{};
  for (final f in folders.where((f) => f.isNotEmpty)) {
    (byName[folderParts(f).$1] ??= []).add(f);
  }
  final out = <String, String>{};
  for (final twins in byName.values.where((l) => l.length > 1)) {
    final names = [for (final f in twins) folderParts(folderParts(f).$2).$1];
    final unique = names.toSet().length == names.length;
    for (final (i, f) in twins.indexed) {
      out[f] = unique && names[i].isNotEmpty ? names[i] : folderParts(f).$2;
    }
  }
  return out;
}

/// A group's header: the folder's name (its path in the tooltip; [twin]
/// after it, muted, when another project has the same name), or "No
/// folder" ('') for chats in scratch folders; a chevron button that
/// collapses the group, with the summary dot beside the name while it's
/// collapsed; a + for a new chat there, shown under the pointer or with
/// keyboard focus (its room kept, so names don't move). Dragged, it moves
/// the group.
class _Header extends StatefulWidget {
  const new(
    this.folder, {
    required this.twin,
    required this.chats,
    required this.collapsed,
    required this.onNew,
    required this.onTerminal,
    required this.drag,
  });

  final String folder;
  final String twin;
  final List<ChatState> chats;
  final bool collapsed;
  final VoidCallback? onNew;
  final VoidCallback? onTerminal; // a terminal there, in one of its chats
  final ItemDrag<_Moving> drag;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _hover = false;
  bool _focus = false; // the + has keyboard focus

  void _toggle() => sidebarCollapsed.value = widget.collapsed
      ? ({...sidebarCollapsed.value}..remove(widget.folder))
      : {...sidebarCollapsed.value, widget.folder};

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final folder = widget.folder;
    final name = folder.isEmpty ? 'No folder' : folderParts(folder).$1;
    return Menu(
      entries: [
        MenuEntry('New chat here', onPick: widget.onNew),
        MenuEntry('Open in terminal', onPick: widget.onTerminal),
      ],
      builder: (context, open) => LayoutBuilder(
        builder: (context, box) => widget.drag.draggable(
          data: _Moving(folder),
          feedback: Lifted(name, width: box.maxWidth),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (d) => open(d.localPosition),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 6, 2),
                child: Row(
                  children: [
                    IconTap(
                      widget.collapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      tooltip: widget.collapsed ? 'Expand' : 'Collapse',
                      size: 12,
                      padding: 6,
                      color: t.textMuted,
                      onTap: _toggle,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: folder.isEmpty
                          ? _name(theme, name)
                          : Tooltip(
                              message: tildePath(folder),
                              child: _name(theme, name),
                            ),
                    ),
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onFocusChange: (f) => setState(() => _focus = f),
                      child: Opacity(
                        opacity: _hover || _focus ? 1 : 0,
                        child: IconTap(
                          Icons.add,
                          tooltip: 'New chat here',
                          onTap: widget.onNew,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _name(NushiTheme theme, String name) {
    final t = theme.t;
    final chats = widget.chats;
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              text: name,
              children: [
                if (widget.twin.isNotEmpty)
                  TextSpan(
                    text: '  · ${widget.twin}',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text, weight: FontWeight.w600),
          ),
        ),
        if (widget.collapsed)
          ListenableBuilder(
            listenable: Listenable.merge(chats),
            builder: (context, _) => switch (groupPhase(chats)) {
              final phase? => Padding(
                padding: const EdgeInsets.only(left: 5),
                child: PhaseDot(phase),
              ),
              null => const SizedBox.shrink(),
            },
          ),
      ],
    );
  }
}
