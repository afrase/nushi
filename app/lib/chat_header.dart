import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/pickers.dart' show ConfigNames;
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/window_drag.dart';

/// The chat's header: its title (double-click renames it), the agent, its
/// model and status, the Chat | Changes (| Pull request, while it has one)
/// switch, the terminal's and the panel's buttons and the chat's menu. (Its
/// folder is in the sidebar and the details panel's Environment widget; the
/// files it wrote are in Artifacts.) With the sidebar hidden it starts past
/// the traffic lights and the button that shows the sidebar, and the chat's
/// color, if it has one, is a dot before the title (ADR 0080).
class ChatHeader extends StatelessWidget {
  const new(
    this.chat,
    this.daemon, {
    required this.tab,
    required this.onTab,
    required this.panel,
    required this.onPanel,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final ChatTab tab;
  final ValueChanged<ChatTab> onTab;
  final bool panel; // the details panel shows
  final VoidCallback? onPanel; // shows or hides it; null when it can't show

  // The title is a field (a double-click, ⋯'s Rename, or the palette's
  // and the Chat menu's, through the chat).
  bool get _renaming => chat.renaming.value;
  set _renaming(bool v) => chat.renaming.value = v;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final meta = theme.ui(t.textSecondary, size: 12);
    final model = chat.option('model');
    final modelName = model == null || model.current.isEmpty
        ? null
        : model.currentName;
    final titleStyle = theme.ui(t.text, weight: FontWeight.w600);
    // The title and the model (a Codex model id is long) share what the
    // rest of the row leaves (it takes about 455 points, the Pull request
    // tab 88 more), so a narrow window cuts them short rather than
    // overflow. Where all of it fits with room over, the row opens up to
    // the bar's gaps (ADR 0072). Narrower still, the least needed parts
    // fold, so the chat's menu (⋯) stays at the row's end: the model, the
    // agent's name (its mark stays), the details button while the panel
    // can't show, the tabs into a menu field, the status word (the dot's
    // tooltip says it), then the terminal's and the details' buttons into
    // ⋯. Changes counts the review comments not sent yet (14 points more);
    // a hidden side chat's chip takes its own room.
    return ListenableBuilder(
      listenable: Listenable.merge([
        chat.renaming,
        reviews,
        chat.side,
        chat.sideHidden,
        sidebarHidden,
        filesChats,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final shut = sidebarShut;
          // The row's room, less what a hidden sidebar's start and dot take.
          final width =
              box.maxWidth -
              (shut ? hiddenHeaderStart - NushiTheme.gutter : 0) -
              (shut && chat.color != null ? _dotRoom : 0);
          final comments = unsentComments(chat.id).isNotEmpty;
          final side = chat.side.value != null && chat.sideHidden.value;
          // The Jira key, and its gap, as wide as it is.
          final jira = chat.jiraKey.isEmpty
              ? 0.0
              : NushiTheme.barGap +
                    _textWidth(
                      context,
                      chat.jiraKey,
                      theme.code(t.text, size: 12),
                    );
          final folds = headerFolds(
            width,
            pull: chat.pull != null,
            panel: onPanel != null,
            model: modelName != null,
            comments: comments,
            side: side,
            jira: jira,
          );
          final shown = modelName != null && !folds.model;
          // What the title and the model (its gap taken out) share.
          final room =
              width -
              headerRow -
              (folds.roomy ? headerGaps : 0) -
              folds.more +
              folds.saved -
              (shown ? (folds.roomy ? NushiTheme.barGap : 8) : 0);
          const least = 80.0;
          var title = (room * 0.6).clamp(least, 320.0);
          if (shown) title = min(title, max(least, room - 40));
          return _row(
            context,
            titleStyle,
            meta,
            modelName,
            folds,
            titleMax: title,
            modelMax: (room - title).clamp(40.0, 200.0),
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    TextStyle titleStyle,
    TextStyle meta,
    String? modelName,
    HeaderFolds folds, {
    required double titleMax,
    required double modelMax,
  }) {
    final shut = sidebarShut;
    final t = NushiTheme.of(context).t;
    final theme = NushiTheme.of(context);
    // Controls and groups of them, and what's around the row's free space;
    // with no room to spare, what the row has always taken, in the gutters
    // the transcript has (its fold's numbers are the same either way).
    final roomy = folds.roomy;
    final gap = roomy ? NushiTheme.barGap : 8.0;
    final group = roomy ? NushiTheme.groupGap : NushiTheme.barGap;
    final around = roomy ? NushiTheme.groupGap : 6.0;
    return SizedBox(
      height: PaneHeader.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.borderSubtle)),
            ),
          ),
          const WindowDrag(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              shut ? hiddenHeaderStart : NushiTheme.gutter,
              0,
              NushiTheme.gutter,
              1, // the border's
            ),
            child: Row(
              children: [
                // What leads moves with the sidebar's edge as it slides;
                // the rest stays put.
                SidebarFollow(
                  shut: shut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shut)
                        if (chat.color case final color?) ...[
                          Tooltip(
                            message: color.label,
                            child: Container(
                              key: const Key('chat color'),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.ink(t),
                              ),
                            ),
                          ),
                          const SizedBox(width: _dotRoom - 8),
                        ],
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: titleMax),
                        child: _renaming
                            ? RenameField(
                                chat: chat,
                                daemon: daemon,
                                style: titleStyle,
                                onDone: () => _renaming = false,
                              )
                            : GestureDetector(
                                onDoubleTap: () => _renaming = true,
                                child: Text(
                                  chat.shownTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                      ),
                      if (chat.jiraKey.isNotEmpty) ...[
                        SizedBox(width: gap),
                        LinkText(
                          chat.jiraKey,
                          mono: true,
                          size: 12,
                          tooltip: 'Show ${chat.jiraKey} in Jira',
                          onTap: () =>
                              showIssue(daemon, chat.jiraSite, chat.jiraKey),
                        ),
                      ],
                      if (chat.github case final link?) ...[
                        SizedBox(width: gap),
                        GitHubChip(
                          key: ValueKey(link.id),
                          daemon: daemon,
                          link: link,
                        ),
                      ],
                      SizedBox(width: group),
                      Tooltip(
                        message: folds.name ? chat.agentName : '',
                        child: AgentMark(chat.agent, size: 16, ink: t.text),
                      ),
                      if (!folds.name) ...[
                        const SizedBox(width: 8),
                        Text(
                          chat.agentName,
                          style: theme.ui(
                            t.text,
                            size: 12,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (modelName != null && !folds.model) ...[
                        SizedBox(width: gap),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: modelMax),
                          child: Text(
                            modelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: meta,
                          ),
                        ),
                      ],
                      SizedBox(width: gap),
                      if (chat.archived)
                        Text('archived', style: meta)
                      else if (folds.word)
                        Tooltip(
                          message: phaseWord(chat.phase, t).$1,
                          child: ChatDot(chat: chat),
                        )
                      else ...[
                        ChatDot(chat: chat),
                        const SizedBox(width: 5),
                        ChatStatusWord(chat, style: meta),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: around),
                const Spacer(),
                SizedBox(width: around),
                if (chat.side.value != null && chat.sideHidden.value) ...[
                  SideChip(chat),
                  SizedBox(width: gap),
                ],
                if (folds.tabs)
                  MenuField(
                    compact: true,
                    tooltip: '⌃⇥ the next tab, ⌃⇧⇥ the one before',
                    entries: [
                      for (final (each, label) in _tabs(chat))
                        MenuEntry(
                          label,
                          detail: keyLabel(tabKey(each)),
                          checked: each == tab,
                          onPick: () => onTab(each),
                        ),
                    ],
                    label: Text(_tabs(chat).firstWhere((s) => s.$1 == tab).$2),
                  )
                else
                  PlainTabs(
                    value: tab,
                    tabs: _tabs(chat),
                    onChanged: onTab,
                    fill: true,
                    tooltip: (t) =>
                        '${keyLabel(tabKey(t))}   ⌃⇥ the next tab, ⌃⇧⇥ the one '
                        'before',
                  ),
                SizedBox(width: roomy ? NushiTheme.groupGap : 4),
                if (!folds.buttons) ...[
                  TerminalButton(chat: chat, daemon: daemon),
                  if (roomy) const SizedBox(width: NushiTheme.iconGap),
                ],
                if (!folds.buttons && !folds.panel) ...[
                  IconTap.line(
                    LineIcon.details,
                    tooltip: onPanel == null
                        ? 'The window is too narrow'
                        : panel
                        ? 'Hide details'
                        : 'Show details',
                    color: panel ? t.accentInk : t.textSecondary,
                    onTap: onPanel,
                  ),
                  if (roomy) const SizedBox(width: NushiTheme.iconGap),
                ],
                MenuIcon.line(
                  LineIcon.more,
                  tooltip: 'Chat menu',
                  filter: false,
                  entries: [
                    if (folds.buttons) ...[
                      if (!chat.archived)
                        MenuEntry(
                          terminalChats.value.contains(chat.id)
                              ? 'Hide terminal'
                              : 'Show terminal',
                          shortcut: '⌃`',
                          line: LineIcon.terminal,
                          onPick: () => toggleTerminal(chat.id),
                        ),
                      if (onPanel case final toggle?)
                        MenuEntry(
                          panel ? 'Hide details' : 'Show details',
                          line: LineIcon.details,
                          onPick: toggle,
                        ),
                    ],
                    if (daemon.daemonApi >= filesApi) ...[
                      MenuEntry(
                        filesOpen(chat) ? 'Hide files' : 'Show files',
                        shortcut: keyLabel(filesKey),
                        icon: Icons.folder_outlined,
                        onPick: () => toggleFiles(chat),
                      ),
                      MenuEntry.divider,
                    ] else if (folds.buttons)
                      MenuEntry.divider,
                    ...chatMenu(
                      context,
                      chat,
                      daemon,
                      onRename: () => _renaming = true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (shut) const ShowSidebarButton(),
        ],
      ),
    );
  }

  /// How wide [text] sets in [style].
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  List<(ChatTab, String)> _tabs(ChatState chat) => [
    (ChatTab.chat, 'Chat'),
    switch (unsentComments(chat.id).length) {
      0 => (ChatTab.changes, 'Changes'),
      final n => (ChatTab.changes, 'Changes $n'),
    },
    if (chat.pull != null) (ChatTab.pull, 'Pull request'),
  ];
}

/// The room the chat's color's dot takes, its gap to the title in it.
const _dotRoom = 16.0;

/// Measured: the header's row without its title and model takes about this
/// (oh-my-pi's name, "in background"), with what it has always spent on gaps.
const headerRow = 455.0;

/// What the bar's full gaps add to [headerRow] (ADR 0072): the row without
/// the title takes 76 more, a model's gap 2, a hidden side chat's 4.
const headerGaps = 82.0;

/// What of the chat's header folds at a width, the least needed first, the
/// points that frees of the row's [headerRow] (the model's aren't in it),
/// what the row takes past [headerRow] (`more`: the Pull request tab, the
/// unsent comments' count, a hidden side chat's chip, the Jira key), and
/// whether nothing is near folding, so the row has the bar's gaps.
typedef HeaderFolds = ({
  bool roomy,
  bool model,
  bool name,
  bool word,
  bool panel,
  bool tabs,
  bool buttons,
  bool any,
  double saved,
  double more,
});

/// The parts of the header that fold in [width] (see [ChatHeader]): each
/// in turn until the title has its 80 points. The bar's gaps only come out of
/// room over, so they never make a part fold. [pull]: the chat has the
/// Pull request tab; [panel]: the details panel can show; [model]: the
/// header names a model (40 points at least, and its gap); [side]: a
/// hidden side chat's chip shows; [jira]: what the chat's Jira key takes,
/// its gap with it.
HeaderFolds headerFolds(
  double width, {
  required bool pull,
  required bool panel,
  bool model = false,
  bool comments = false,
  bool side = false,
  double jira = 0,
}) {
  // The Pull request tab is 88 more, the comments' count 14.
  final more =
      (pull ? 88.0 : 0.0) +
      (comments ? 14.0 : 0.0) +
      (side ? SideChip.width : 0.0) +
      jira;
  final need = headerRow + more + 80 + (model ? 50 : 0);
  var saved = 0.0;
  final folds = <String>{};
  // Each part and about how much folding it frees.
  for (final (part, points) in [
    if (model) ('model', 50.0),
    ('name', 48.0),
    if (!panel) ('panel', 26.0),
    ('tabs', (pull ? 115.0 : 50.0) + (comments ? 14 : 0)),
    ('word', 45.0),
    ('buttons', panel ? 52.0 : 26.0),
  ]) {
    if (width + saved >= need) break;
    folds.add(part);
    saved += points;
  }
  return (
    roomy: width >= need + headerGaps,
    model: folds.contains('model'),
    name: folds.contains('name'),
    word: folds.contains('word'),
    panel: folds.contains('panel'),
    tabs: folds.contains('tabs'),
    buttons: folds.contains('buttons'),
    any: folds.isNotEmpty,
    // The model's points were never in the row's 455.
    saved: saved - (folds.contains('model') ? 50 : 0),
    more: more,
  );
}
