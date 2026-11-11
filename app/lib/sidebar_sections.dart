import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/inline_edit.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_group_header.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The sidebar's sections of the user's own ([sidebarSections], ADR 0089):
// under Pinned, above the groups, in an order dragged; a chat moves into
// one by a drag or its row's Move to section, and out by a drag onto the
// groups or Remove from section.

/// The section whose name is being edited in place, by id: a new one's
/// at once.
final renamingSection = ValueNotifier<String?>(null);

/// Makes a section, named "New section" to be renamed at once, with
/// [chat] moved into it if given, after the others.
void newSection(BuildContext context, Daemon daemon, {ChatState? chat}) {
  final taken = {for (final s in sidebarSections.value) s.id};
  var n = taken.length + 1;
  while (taken.contains('s$n')) {
    n++;
  }
  final id = 's$n';
  sidebarSections.value = [
    ...sidebarSections.value,
    Section(id: id, name: 'New section'),
  ];
  if (chat != null) moveToSection(context, daemon, chat, id);
  renamingSection.value = id;
}

/// Moves [chat] into section [id] (out of any other), first in it. A
/// pinned chat is unpinned, so it shows there: Pinned is above every
/// section.
void moveToSection(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  String id,
) {
  sidebarSections.value = [
    for (final s in sidebarSections.value)
      s.copyWith(
        chats: [if (s.id == id) chat.id, ...s.chats.where((c) => c != chat.id)],
      ),
  ];
  if (chat.pin > 0) {
    unawaited(
      tryOrShow(
        context,
        () => setChatPins(daemon, [
          for (final c in pinnedChats(daemon))
            if (c != chat) c.id,
        ]),
      ),
    );
  }
}

/// Takes the chat [id] out of its section: it goes back to its group.
void leaveSection(String id) => sidebarSections.value = [
  for (final s in sidebarSections.value)
    s.copyWith(chats: [...s.chats.where((c) => c != id)]),
];

/// The section of the chat [id], if it's in one.
Section? sectionOf(String id) =>
    sidebarSections.value.where((s) => s.chats.contains(id)).firstOrNull;

void _change(String id, Section Function(Section s) change) =>
    sidebarSections.value = [
      for (final s in sidebarSections.value)
        if (s.id == id) change(s) else s,
    ];

/// A chat row's Move to section: each section (the one it's in checked),
/// New section, and Remove from section while it's in one.
MenuEntry moveToSectionEntry(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) {
  final within = sectionOf(chat.id);
  final sections = sidebarSections.value;
  return MenuEntry(
    'Move to section',
    icon: Icons.drive_file_move_outline,
    submenu: [
      for (final s in sections)
        MenuEntry(
          s.name,
          checked: s.id == within?.id,
          onPick: s.id == within?.id
              ? null
              : () => moveToSection(context, daemon, chat, s.id),
        ),
      if (sections.isNotEmpty) MenuEntry.divider,
      MenuEntry(
        'New section',
        onPick: () => newSection(context, daemon, chat: chat),
      ),
      if (within != null)
        MenuEntry('Remove from section', onPick: () => leaveSection(chat.id)),
    ],
  );
}

/// What a section's header drag carries: the section.
class _MovingSection {
  const new(this.id);

  final String id;
}

/// The sections ([sections], each with the chats it shows), their headers
/// dragged into another order. Each takes a chat row dropped on it from
/// any other list; [reorders], its own rows move by dragging too (Manual
/// sort under Project grouping). [row] builds a chat's row.
class SidebarSections extends StatelessWidget {
  const new({
    required this.daemon,
    required this.sections,
    required this.reorders,
    required this.row,
    super.key,
  });

  final Daemon daemon;
  final List<(Section, List<ChatState>)> sections;
  final bool reorders;
  final Widget Function(ChatState chat, Movable movable) row;

  @override
  Widget build(BuildContext context) => SlideList<_MovingSection>(
    count: sections.length,
    accepts: (_) => true,
    // Every section shows, so the list's places are theirs.
    onMove: (from, to) {
      final all = [...sidebarSections.value];
      sidebarSections.value = all..insert(to, all.removeAt(from));
    },
    item: (i, drag) {
      final (section, chats) = sections[i];
      return _SectionView(
        key: ValueKey(section.key),
        daemon: daemon,
        section: section,
        chats: chats,
        reorders: reorders,
        drag: drag,
        row: row,
      );
    },
  );
}

class _SectionView extends StatelessWidget {
  const new({
    required this.daemon,
    required this.section,
    required this.chats,
    required this.reorders,
    required this.drag,
    required this.row,
    super.key,
  });

  final Daemon daemon;
  final Section section;
  final List<ChatState> chats;
  final bool reorders;
  final ItemDrag<_MovingSection> drag;
  final Widget Function(ChatState chat, Movable movable) row;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return DragTarget<MovingChat>(
      // A row of another list; its own rows move inside it.
      onWillAcceptWithDetails: (d) => d.data.group != section.key,
      onAcceptWithDetails: (d) {
        if (daemon.chats[d.data.id] case final chat?) {
          moveToSection(context, daemon, chat, section.id);
        }
      },
      builder: (context, over, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: over.isEmpty ? null : t.accentSoft,
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(section: section, chats: chats, drag: drag),
            if (chats.isEmpty && !section.collapsed)
              const GroupHint('Drag chats here'),
            MovableRows(
              group: section.key,
              chats: chats,
              collapsed: section.collapsed,
              reorders: reorders,
              selectedId: daemon.selectedId,
              row: row,
              onMove: (from, to) => _change(section.id, (s) {
                final ids = [for (final c in chats) c.id];
                ids.insert(to, ids.removeAt(from));
                // Those it doesn't show (pinned, archived) keep their
                // places after.
                return s.copyWith(
                  chats: [...ids, ...s.chats.where((c) => !ids.contains(c))],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section's header: its name (a field while it's renamed), the
/// chevron that collapses it, and a ⋯ under the pointer or with the focus
/// (Rename, Delete section; a right-click opens the same). Dragged, it
/// moves the section.
class _SectionHeader extends StatefulWidget {
  const new({required this.section, required this.chats, required this.drag});

  final Section section;
  final List<ChatState> chats;
  final ItemDrag<_MovingSection> drag;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final section = widget.section;
    final entries = [
      MenuEntry(
        'Rename',
        icon: Icons.edit_outlined,
        onPick: () => renamingSection.value = section.id,
      ),
      MenuEntry(
        'Delete section',
        icon: Icons.delete_outline,
        danger: true,
        tooltip: 'Its chats go back to their groups',
        onPick: () => sidebarSections.value = [
          for (final s in sidebarSections.value)
            if (s.id != section.id) s,
        ],
      ),
    ];
    return ValueListenableBuilder(
      valueListenable: renamingSection,
      builder: (context, renaming, _) {
        final editing = renaming == section.id;
        final header = GroupHeader(
          title: section.name,
          chats: widget.chats,
          collapsed: section.collapsed,
          onToggle: () =>
              _change(section.id, (s) => s.copyWith(collapsed: !s.collapsed)),
          titleWidget: editing
              ? SizedBox(
                  width: 180,
                  child: InlineEdit(
                    text: section.name,
                    style: GroupHeader.style(theme).copyWith(color: t.text),
                    onDone: (name) {
                      if (name != null && name.isNotEmpty) {
                        _change(section.id, (s) => s.copyWith(name: name));
                      }
                      renamingSection.value = null;
                    },
                  ),
                )
              : null,
          trailing: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (f) => setState(() => _focus = f),
            child: Opacity(
              opacity: _hover || _focus ? 1 : 0,
              child: MenuIcon.line(
                LineIcon.more,
                tooltip: 'Section menu',
                entries: entries,
                filter: false,
              ),
            ),
          ),
        );
        return Menu(
          filter: false,
          entries: entries,
          builder: (context, open) => LayoutBuilder(
            builder: (context, box) => widget.drag.draggable(
              data: _MovingSection(section.id),
              enabled: !editing,
              feedback: Lifted(section.name, width: box.maxWidth),
              child: MouseRegion(
                cursor: editing ? MouseCursor.defer : SystemMouseCursors.grab,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapUp: (d) => open(d.localPosition),
                  child: header,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [child], the groups under the sections: a chat row of a section
/// dropped on it leaves the section, back to its group.
class LeaveSectionTarget extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<MovingChat>(
    onWillAcceptWithDetails: (d) =>
        d.data.group is String &&
        (d.data.group as String).startsWith('section:'),
    onAcceptWithDetails: (d) => leaveSection(d.data.id),
    builder: (context, _, _) => child,
  );
}
