import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/pickers.dart' show ConfigNames;
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/window_drag.dart';

/// The chat's header, at the top of its pane (ADR 0111): its title
/// (double-click renames it), its Jira issue as a pill, the agent, its
/// model, and its state as a pill; then the Chat | Changes (| Pull request,
/// while it has one) switch, a filled track with the one showing raised,
/// the terminal's, the Files pane's, the browser's (ADR 0094) and the
/// panel's buttons, each filled in the accent while what it shows is
/// open, and the chat's menu. (Its folder is in the sidebar and the details
/// panel's Environment widget; the files it wrote are in Artifacts.) With
/// the sidebar hidden it starts past the traffic lights and the button that
/// shows the sidebar, and the chat's color, if it has one, is a chip before
/// the title (ADR 0080).
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

  /// How far its row is in from its pane's left edge, the transcript's
  /// gutter, and from its right one, where its icon buttons bring their own
  /// room.
  static const double start = NushiTheme.gutter;
  static const end = 12.0;

  // The title is a field (a double-click, ⋯'s Rename, or the palette's
  // and the Chat menu's, through the chat).
  bool get _renaming => chat.renaming.value;

  /// The daemon lists folders, so the Files pane can show.
  bool get _files => daemon.daemonApi >= filesApi;
  set _renaming(bool v) => chat.renaming.value = v;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final meta = theme.ui(t.textMuted);
    final model = chat.option('model');
    final modelName = model == null || model.current.isEmpty
        ? null
        : model.currentName;
    final titleStyle = theme.ui(t.text, size: 14, weight: FontWeight.w600);
    // The title and the model (a Codex model id is long) share what the
    // rest of the row leaves ([headerRow], the Pull request tab, the Files
    // and browser buttons and the rest more), so a narrow window cuts them
    // short rather than overflow. Where all of it fits with room over, the
    // row opens up to the bar's gaps (ADR 0072). Narrower still, the least
    // needed parts fold, so the chat's menu (⋯) stays at the row's end: the
    // browser's button into ⋯ (the palette and the pane's + open tabs too),
    // the model, the agent's name (its mark stays), the details button while
    // the panel can't show, the state's word (its dot stays, and its
    // tooltip says it), the tabs into a menu field, then the terminal's,
    // the files' and the details' buttons into ⋯. Changes counts the review
    // comments not sent yet (a small pill more); a hidden side chat's chip,
    // the Jira key and the GitHub chip take their own room. The row's own
    // words were measured in the bundled font: a picked one that sets them
    // wider (ADR 0114) takes that much more, so the row folds sooner
    // rather than run past its end.
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
              (shut ? hiddenHeaderStart - ChatHeader.start : 0) -
              (shut && chat.color != null ? _dotRoom : 0);
          final comments = unsentComments(chat.id).isNotEmpty;
          final side = chat.side.value != null && chat.sideHidden.value;
          // The Jira key's pill, and its gap, as wide as it is.
          final jira = chat.jiraKey.isEmpty
              ? 0.0
              : NushiTheme.barGap +
                    PillLink.room +
                    _textWidth(
                      context,
                      chat.jiraKey,
                      theme.code(t.text, size: 11.5),
                    );
          // The GitHub chip, and its gap: its number as wide as it is, and
          // room for every badge a pull request's can load, so it never
          // pushes ⋯ past the edge when its states land.
          final github = switch (chat.github) {
            null => 0.0,
            final link =>
              NushiTheme.barGap +
                  githubChipRoom +
                  (link.pull ? githubBadgesRoom : githubIssueBadgesRoom) +
                  _textWidth(
                    context,
                    '#${link.number}',
                    theme.code(t.link, size: 12),
                  ),
          };
          final folds = headerFolds(
            width,
            pull: chat.pull != null,
            panel: onPanel != null,
            files: _files,
            model: modelName != null,
            comments: comments,
            side: side,
            jira: jira,
            github: github,
            wider: _wider(context, theme),
          );
          final shown = modelName != null && !folds.model;
          // What the title and the model (its gap taken out) share.
          final room =
              width -
              headerRow -
              folds.gaps -
              folds.more +
              folds.saved -
              (shown ? (folds.roomy ? NushiTheme.barGap : 8) : 0);
          const least = 80.0;
          // The title takes what the model doesn't (all of it with none),
          // and 60% when both are too long for it.
          final modelWidth = shown ? _textWidth(context, modelName, meta) : 0.0;
          var title = max(room * 0.6, room - modelWidth).clamp(least, 360.0);
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
    // The review comments not sent yet, which Changes counts.
    final comments = unsentComments(chat.id).length;
    return SizedBox(
      height: PaneHeader.height,
      child: WindowDrag(
        background: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shut ? hiddenHeaderStart : ChatHeader.start,
              0,
              ChatHeader.end,
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
                          ColorChip(color, named: true),
                          const SizedBox(width: _dotRoom - ColorChip.width),
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
                        PillLink(
                          chat.jiraKey,
                          mono: true,
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
                        child: AgentMark(chat.agent, size: 18, ink: t.text),
                      ),
                      if (!folds.name) ...[
                        const SizedBox(width: 7),
                        Text(
                          chat.agentName,
                          style: theme.ui(t.text, weight: FontWeight.w500),
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
                      // Its state as a pill, the dot alone once the word
                      // folds (its tooltip says it).
                      if (chat.archived)
                        const PhasePill(ChatPhase.archived)
                      else if (folds.word)
                        Tooltip(
                          message: phaseWord(chat.phase, t).$1,
                          child: ChatDot(chat: chat),
                        )
                      else
                        PhasePill(chat.phase, lead: ChatDot(chat: chat)),
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
                    tooltip: _stepTabs,
                    entries: [
                      for (final (each, label) in _tabs(chat))
                        MenuEntry(
                          each == ChatTab.changes && comments > 0
                              ? '$label $comments'
                              : label,
                          detail: keyLabel(tabKey(each)),
                          checked: each == tab,
                          onPick: () => onTab(each),
                        ),
                    ],
                    label: Text(
                      _tabs(chat).firstWhere((s) => s.$1 == tab).$2 +
                          (tab == ChatTab.changes && comments > 0
                              ? ' $comments'
                              : ''),
                    ),
                  )
                else
                  Segmented(
                    value: tab,
                    segments: _tabs(chat),
                    badges: {if (comments > 0) ChatTab.changes: '$comments'},
                    onChanged: onTab,
                    roomy: true,
                    tooltip: (t) => '${keyLabel(tabKey(t))}   $_stepTabs',
                  ),
                SizedBox(width: roomy ? NushiTheme.barGap : 6),
                // In the order of what they show, the terminal under the
                // chat, then the Files pane, the preview's browser tab and
                // the details panel beside it, left to right.
                if (!folds.buttons) ...[
                  TerminalButton(chat: chat, daemon: daemon),
                  if (roomy) const SizedBox(width: NushiTheme.iconGap),
                  if (_files) ...[
                    FilesButton(chat: chat),
                    if (roomy) const SizedBox(width: NushiTheme.iconGap),
                  ],
                  if (!folds.browser) ...[
                    BrowserButton(chat: chat),
                    if (roomy) const SizedBox(width: NushiTheme.iconGap),
                  ],
                ],
                if (!folds.buttons && !folds.panel) ...[
                  IconTap.line(
                    LineIcon.details,
                    tooltip: onPanel == null
                        ? 'The window is too narrow'
                        : panel
                        ? 'Hide details'
                        : 'Show details',
                    padding: IconTap.header,
                    lit: panel,
                    onTap: onPanel,
                  ),
                  if (roomy) const SizedBox(width: NushiTheme.iconGap),
                ],
                MenuIcon.line(
                  LineIcon.more,
                  tooltip: 'Chat menu',
                  padding: IconTap.header,
                  filter: false,
                  entries: [
                    if (folds.browser && !folds.buttons) ...[
                      _browserEntry,
                      MenuEntry.divider,
                    ],
                    if (folds.buttons) ...[
                      if (!chat.archived)
                        MenuEntry(
                          terminalChats.value.contains(chat.id)
                              ? 'Hide terminal'
                              : 'Show terminal',
                          shortcut: keyLabel(toggleTerminalKey),
                          line: LineIcon.terminal,
                          onPick: () => toggleTerminal(chat.id),
                        ),
                      if (_files)
                        MenuEntry(
                          filesShown(chat) ? 'Hide files' : 'Show files',
                          shortcut: keyLabel(filesKey),
                          line: LineIcon.folder,
                          onPick: () => showOrHideFiles(chat),
                        ),
                      _browserEntry,
                      if (onPanel case final toggle?)
                        MenuEntry(
                          panel ? 'Hide details' : 'Show details',
                          line: LineIcon.details,
                          onPick: toggle,
                        ),
                      MenuEntry.divider,
                    ],
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

  /// How much wider the app's font sets the row's own words than the
  /// bundled one does, which [headerRow] was measured in: 1 for the
  /// bundled one, and never less (a narrower font only leaves room over).
  static double _wider(BuildContext context, NushiTheme theme) {
    if (theme.uiPicked == null) return 1;
    const words = 'OpenCode In background Chat Changes Pull request';
    double set(NushiTheme fonts) => _textWidth(
      context,
      words,
      fonts.ui(theme.t.text, weight: FontWeight.w600),
    );
    return max(1, set(theme) / set(NushiTheme(theme.t)));
  }

  /// The browser's button as a row of ⋯, once it folds there.
  MenuEntry get _browserEntry => MenuEntry(
    BrowserButton.tooltip(shown: chat.browserShown),
    line: LineIcon.globe,
    onPick: chat.showOrHideBrowser,
  );

  List<(ChatTab, String)> _tabs(ChatState chat) => [
    (ChatTab.chat, 'Chat'),
    (ChatTab.changes, 'Changes'),
    if (chat.pull != null) (ChatTab.pull, 'Pull request'),
  ];
}

/// How the tabs are stepped through, as their tooltips say.
String get _stepTabs =>
    '${keyLabel(nextTabKey)} the next tab, ${keyLabel(previousTabKey)} the '
    'one before';

/// The room the chat's color's chip takes, its gap to the title in it.
const double _dotRoom = ColorChip.width + 8;

/// The GitHub chip without its number: its padding, icon and the gap to the
/// number (`GitHubChip`).
const double githubChipRoom = 4 + 13 + 3 + 4.0;

/// The most a pull request's chip's badges take once loaded: the gap to
/// them, the checks' icon, the review's, and the unresolved threads' icon
/// and a count of two figures (`ItemBadges`, not wide).
const double githubBadgesRoom = 6 + 14 + 8 + 13 + 8 + 13 + 3 + 14.0;

/// What an issue's chip adds once loaded: only the gap to its (empty)
/// badges.
const githubIssueBadgesRoom = 6.0;

/// Measured: the header's row without its title and model takes about this
/// (OpenCode's name, "In background" in its pill, the Chat and Changes
/// segments, the terminal's, the details' and the menu's buttons), with its
/// tight gaps.
const headerRow = 524.0;

/// About how much of [headerRow] is its words, set in the app's font (the
/// agent's name, the state's word, the Chat and Changes segments), and how
/// much of the Pull request segment is: what a font wider than the bundled
/// one makes wider (ADR 0114).
const headerWords = 250.0;
const _pullWords = 80.0;

/// What the bar's full gaps add to [headerRow] (ADR 0072): the row without
/// the title takes 62 more, a model's gap 4, a hidden side chat's 4.
const headerGaps = 70.0;

/// What of the chat's header folds at a width, the least needed first, the
/// points that frees of the row's [headerRow] (the model's aren't in it),
/// what the row takes past [headerRow] (`more`: the Pull request tab, the
/// unsent comments' count, a hidden side chat's chip, the Files and browser
/// buttons, the Jira key, the GitHub chip),
/// whether nothing is near folding, so the row has the bar's gaps, and
/// what those add (`gaps`).
typedef HeaderFolds = ({
  bool roomy,
  bool browser,
  bool model,
  bool name,
  bool word,
  bool panel,
  bool tabs,
  bool buttons,
  bool any,
  double saved,
  double more,
  double gaps,
});

/// The parts of the header that fold in [width] (see [ChatHeader]): each
/// in turn until the title has its 80 points. The bar's gaps only come out of
/// room over, so they never make a part fold. [pull]: the chat has the
/// Pull request tab; [panel]: the details panel can show; [files]: the
/// Files button shows; [model]: the header names a model (40 points at
/// least, and its gap); [side]: a hidden side chat's chip shows; [jira]:
/// what the chat's Jira key takes, its gap with it; [github]: what its
/// GitHub chip takes, its gap with it; [wider]: how much wider than the
/// bundled font the app's sets the row's words (1: as wide), which the row
/// takes as so much `more`.
HeaderFolds headerFolds(
  double width, {
  required bool pull,
  required bool panel,
  required bool files,
  bool model = false,
  bool comments = false,
  bool side = false,
  double jira = 0,
  double github = 0,
  double wider = 1,
}) {
  // The Pull request segment is 106 more, the comments' count 32, the
  // Files button 32 and the browser's 32.
  const button = 32.0;
  final more =
      (pull ? 106.0 : 0.0) +
      (comments ? 32.0 : 0.0) +
      (side ? SideChip.width : 0.0) +
      (files ? button : 0.0) +
      button +
      jira +
      github +
      (wider - 1) * (headerWords + (pull ? _pullWords : 0));
  final gaps =
      headerGaps + NushiTheme.iconGap + (files ? NushiTheme.iconGap : 0);
  final need = headerRow + more + 80 + (model ? 50 : 0);
  var saved = 0.0;
  final folds = <String>{};
  // Each part and about how much folding it frees. The browser's button
  // goes first: what the header had before it then folds where it did.
  for (final (part, points) in [
    ('browser', button),
    if (model) ('model', 50.0),
    // What [headerRow] counts for each: the longest name and its gap, the
    // longest state's pill less its dot, the segments less a menu field.
    ('name', 71.0),
    if (!panel) ('panel', button),
    ('word', 106.0),
    ('tabs', (pull ? 160.0 : 72.0) + (comments ? 16 : 0)),
    ('buttons', (panel ? 2 : 1) * button + (files ? button : 0)),
  ]) {
    if (width + saved >= need) break;
    folds.add(part);
    saved += points;
  }
  final roomy = width >= need + gaps;
  return (
    roomy: roomy,
    browser: folds.contains('browser'),
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
    gaps: roomy ? gaps : 0,
  );
}
