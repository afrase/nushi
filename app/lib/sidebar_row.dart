import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart' show agoShort;
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/sidebar_sections.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A chat in the list: click opens it, a right-click opens its menu
/// (Rename among it: a second click on a chat slow to open must not
/// start a rename; Move to section), and dragged ([movable]) it moves
/// within its list or into a section. One outside its project's group
/// ([project]: pinned, in a section, grouped otherwise) says its project
/// after its title, muted, in the place of its branch or Jira key. What
/// else it shows is the Arrange menu's Show ([sidebarShows]): its state's
/// dot, its agent's mark, its branch, and [time] as an age. A chat with a
/// color has a bar of it at the row's left ([ColorBar]); only the open
/// chat's row is filled, so a blue chat never reads as the open one.
class SidebarRow extends StatefulWidget {
  const new(
    this.chat, {
    required this.daemon,
    super.key,
    this.number,
    this.movable,
    this.project = false,
    this.time,
  });

  final ChatState chat;
  final Daemon daemon;
  final Movable? movable;
  final bool project;
  final DateTime? time;

  /// The number ⌘ opens it with, shown while ⌘ is held.
  final int? number;

  @override
  State<SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<SidebarRow> {
  bool _renaming = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final daemon = widget.daemon;
    final selected = daemon.selectedId == chat.id;
    // Under Settings, Jira or GitHub it stays marked, but quieter: the open
    // view's row is the one in the accent.
    final shown = selected && daemon.chatShows;
    final movable =
        widget.movable ?? (Widget child, {required bool enabled}) => child;
    final shows = sidebarShows.value;
    // Not the chat itself, which notifies at every streamed chunk.
    return ListenableBuilder(
      listenable: chat.look,
      builder: (context, _) => movable(
        enabled: !_renaming,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Menu(
            filter: false,
            entries: chatMenu(
              context,
              chat,
              daemon,
              onRename: () => setState(() => _renaming = true),
              more: [
                if (!chat.archived) moveToSectionEntry(context, daemon, chat),
              ],
            ),
            builder: (context, open) => ColorBar(
              color: chat.color,
              child: Tap(
                onTap: () => daemon.select(chat.id),
                // Built again as it opens: what its entries read (the
                // review comments, the side chat, a clean-up running) can
                // change without the row building again.
                onSecondaryTapUp: (d) {
                  setState(() {});
                  open(d.localPosition);
                },
                selected: selected,
                // The open chat in the accent's soft fill: the plain selected
                // gray is hardly apart from the sidebar's own.
                fill: shown ? t.accentSoft : null,
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: _renaming ? 1 : 5,
                ),
                child: LayoutBuilder(
                  builder: (context, space) {
                    final room = space.maxWidth;
                    return Row(
                      children: [
                        // Its state in a word on hover ("needs you"), which the
                        // row leaves to the dot so the title keeps its width.
                        if (shows.contains(RowPart.status)) ...[
                          Tooltip(
                            message: phaseWord(chat.phase, t).$1,
                            child: ChatDot(chat: chat, sparks: true),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (shows.contains(RowPart.agent)) ...[
                          Tooltip(
                            message: chat.agentName,
                            child: AgentMark(
                              chat.agent,
                              color: chat.archived ? t.textMuted : null,
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],
                        Expanded(
                          child: _renaming
                              ? RenameField(
                                  chat: chat,
                                  daemon: daemon,
                                  onDone: () =>
                                      setState(() => _renaming = false),
                                )
                              : Text(
                                  chat.shownTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.ui(
                                    chat.archived ? t.textSecondary : t.text,
                                    weight: shown ? FontWeight.w600 : null,
                                  ),
                                ),
                        ),
                        if (widget.project)
                          // At most a third of the row, so a narrow sidebar
                          // keeps the title.
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: room / 3),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                chat.scratch ? '' : folderParts(chat.home).$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.ui(t.textMuted, size: 11.5),
                              ),
                            ),
                          )
                        else if (!shows.contains(RowPart.branch))
                          const SizedBox.shrink()
                        else if (chat.jiraKey.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              chat.jiraKey,
                              style: theme.code(t.textMuted, size: 10.5),
                            ),
                          )
                        else if (chat.worktree case final wt?)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                wt.branch.replaceFirst('nushi/', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.code(t.textMuted, size: 10.5),
                              ),
                            ),
                          ),
                        if (chat.pull != null)
                          PullDot(chat, PullStates.of(daemon)),
                        if (chat.archived && !chat.scratch)
                          Text(
                            folderParts(chat.home).$1,
                            style: theme.ui(t.textMuted, size: 11.5),
                          ),
                        if (widget.time case final at?)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: at.toString().substring(0, 16),
                              child: Text(
                                agoShort(clock().difference(at)),
                                style: theme.code(t.textMuted, size: 10.5),
                              ),
                            ),
                          ),
                        if (widget.number case final n?)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: box(
                              t.fieldBorder,
                              fill: t.fieldFill,
                              radius: NushiTheme.tag,
                            ),
                            child: keyText(
                              keyLabel(chatNumberKey(n)),
                              theme.code(t.textSecondary, size: 11),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
