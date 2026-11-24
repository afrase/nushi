import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_view.dart' show showItem;
import 'package:nushi/jira_view.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/pickers.dart' show ConfigNames;
import 'package:nushi/pull_states.dart' show GitHubLinkRef;
import 'package:nushi/pulls_chip.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/text_width.dart';
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
  final bool panel; // the details panel is wanted (it may be tucked away)
  final VoidCallback? onPanel; // shows or hides it; null when it can't show

  /// How far its row is in from its pane's left edge, the transcript's
  /// gutter, and from its right one, where its icon buttons bring their own
  /// room.
  static const double start = NushiTheme.gutter;
  static const end = 12.0;

  // The title is a field (a double-click, ⋯'s Rename, or the palette's
  // and the Chat menu's, through the chat).
  bool get _renaming => chat.renaming.value;

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
    // model, the agent's name (its mark stays), the details button while
    // the panel can't show, the state's word (its dot stays, and its
    // tooltip says it), the tabs into a menu field; beside a pane dragged
    // wide, the Jira and GitHub chips, the agent's mark and the tabs' field
    // (into ⋯); last, so the title keeps 80, the terminal's, Files',
    // the browser's and the details' buttons into ⋯, all together, so
    // opening a pane never takes one of its neighbours away. Changes
    // counts the review comments not sent yet (a small pill more); a
    // hidden side chat's chip, the Jira key and the GitHub chip take their
    // own room. The row's own words were measured in the bundled font: a
    // picked one that sets them wider (ADR 0114) takes that much more, so
    // the row folds sooner rather than run past its end.
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
          // An issue it started from keeps its chip; its pull requests
          // have theirs (ADR 0117), whose badges a narrow header drops
          // first.
          final issue = switch (chat.github) {
            final link? when !link.pull =>
              NushiTheme.barGap +
                  githubChipRoom +
                  githubIssueBadgesRoom +
                  _textWidth(
                    context,
                    '#${link.number}',
                    theme.code(t.link, size: 12),
                  ),
            _ => 0.0,
          };
          final pulls = chat.pulls;
          final more = pulls.length > 1 ? ' +${pulls.length - 1}' : '';
          final pullsChip = switch (chat.pull ?? pulls.firstOrNull) {
            null => 0.0,
            final link =>
              NushiTheme.barGap +
                  githubChipRoom +
                  _textWidth(
                    context,
                    '#${link.number}$more',
                    theme.code(t.link, size: 12),
                  ),
          };
          // Its agent's name as wide as it is (it never changes); the
          // state's word keeps the room of its longest ([headerRow]), so the
          // row folds nothing more or less as the chat's state changes.
          final nameStyle = theme.ui(t.text, weight: FontWeight.w500);
          final name = max(
            0.0,
            headerName +
                _textWidth(context, chat.agentName, nameStyle) -
                _textWidth(context, _longestName, nameStyle),
          );
          HeaderFolds foldsWith(double badges) => headerFolds(
            width,
            name: name,
            pull: chat.pull != null,
            panel: onPanel != null,
            files: true,
            model: modelName != null,
            comments: comments,
            side: side,
            jira: jira,
            github: issue + pullsChip + badges,
            wider: _wider(context, theme),
          );
          var folds = foldsWith(pullsChip > 0 ? githubBadgesRoom : 0);
          final badges = !folds.any;
          if (!badges) folds = foldsWith(0);
          final shown = modelName != null && !folds.model;
          // What the title and the model (its gap taken out) share.
          final room =
              width -
              headerRow -
              folds.gaps -
              folds.more +
              folds.saved -
              (shown ? (folds.roomy ? NushiTheme.barGap : 8) : 0);
          const least = headerTitleLeast;
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
            badges: badges,
            // With no model beside it, the title takes all the room the
            // rest leaves it (a short state's word leaves it more).
            titleMax: shown ? title : double.infinity,
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
    required bool badges,
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
                // the rest stays put. It takes what the rest leaves, its
                // title cut short when even its folds leave too little (a
                // header beside a pane dragged wide, ADR 0123).
                Expanded(
                  child: SidebarFollow(
                    shut: shut,
                    child: Row(
                      children: [
                        if (shut)
                          if (chat.color case final color?) ...[
                            ColorChip(color, named: true),
                            const SizedBox(width: _dotRoom - ColorChip.width),
                          ],
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: titleMax),
                            child: _renaming
                                ? RenameField(
                                    chat: chat,
                                    daemon: daemon,
                                    style: titleStyle,
                                    onDone: () => _renaming = false,
                                  )
                                // A double-click on the title renames it.
                                // design: the title isn't a button
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
                        ),
                        if (chat.jiraKey.isNotEmpty && !folds.links) ...[
                          SizedBox(width: gap),
                          PillLink(
                            chat.jiraKey,
                            mono: true,
                            tooltip: 'Show ${chat.jiraKey} in Jira',
                            onTap: () =>
                                showIssue(daemon, chat.jiraSite, chat.jiraKey),
                          ),
                        ],
                        if (chat.github case final link?
                            when !link.pull && !folds.links) ...[
                          SizedBox(width: gap),
                          GitHubChip(
                            key: ValueKey(link.id),
                            daemon: daemon,
                            link: link,
                          ),
                        ],
                        if ((chat.pull != null || chat.pulls.isNotEmpty) &&
                            !folds.links) ...[
                          SizedBox(width: gap),
                          PullsChip(
                            daemon,
                            chat,
                            badges: badges,
                            onShow: () => onTab(ChatTab.pull),
                          ),
                        ],
                        SizedBox(width: group),
                        if (!folds.mark)
                          tooltip(
                            context,
                            folds.name ? chat.agentName : '',
                            AgentMark(chat.agent, size: 18, ink: t.text),
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
                        if (!folds.mark) SizedBox(width: gap),
                        // Its state as a pill, the dot alone once the word
                        // folds (its tooltip says it, and whose it is once
                        // the mark folds too).
                        if (chat.archived)
                          const PhasePill(ChatPhase.archived)
                        else if (folds.word)
                          tooltip(
                            context,
                            folds.mark
                                ? '${chat.agentName}: '
                                      '${phaseWord(chat.phase, t).$1}'
                                : phaseWord(chat.phase, t).$1,
                            _stateMark(chat),
                          )
                        else
                          PhasePill(chat.phase, lead: _stateMark(chat)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: around * 2),
                // The rest ends where the panes beside the chat start: it
                // glides with them as they come and go (ADR 0123).
                Glide(
                  token: Beside.glideOf(context),
                  scene: Beside.sceneOf(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chat.side.value != null && chat.sideHidden.value) ...[
                        SideChip(chat),
                        SizedBox(width: gap),
                      ],
                      if (folds.tabsInMore)
                        const SizedBox.shrink()
                      else if (folds.tabs)
                        MenuField(
                          compact: true,
                          tooltip: withKey('Next tab', keyLabel(nextTabKey)),
                          entries: _tabEntries(comments, inMore: false),
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
                          badges: {
                            if (comments > 0) ChatTab.changes: '$comments',
                          },
                          onChanged: onTab,
                          roomy: true,
                          tooltip: (t) => withKey(
                            _tabs(chat).firstWhere((s) => s.$1 == t).$2,
                            keyLabel(tabKey(t)),
                          ),
                        ),
                      if (!folds.tabsInMore)
                        SizedBox(width: roomy ? NushiTheme.barGap : 6),
                      // In the order of what they show, the terminal under
                      // the chat, then the Files pane, the preview's browser
                      // tab and the details panel beside it, left to right.
                      if (!folds.buttons) ...[
                        TerminalButton(chat: chat, daemon: daemon),
                        if (roomy) const SizedBox(width: NushiTheme.iconGap),
                        FilesButton(chat: chat),
                        if (roomy) const SizedBox(width: NushiTheme.iconGap),
                        BrowserButton(chat: chat),
                        if (roomy) const SizedBox(width: NushiTheme.iconGap),
                      ],
                      if (!folds.buttons && !folds.panel) ...[
                        IconTap.line(
                          LineIcon.details,
                          // Off on Changes and Pull request, or with no
                          // room for it: it says which.
                          tooltip: onPanel == null
                              ? tab != ChatTab.chat
                                    ? 'Details show on the Chat tab'
                                    : 'The window is too narrow'
                              : !panel
                              ? 'Show details'
                              : Beside.railHeldOf(context)
                              ? 'Hide details (tucked away while the '
                                    'panes need the room)'
                              : 'Hide details',
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
                          // The tabs, once their field folds here too.
                          if (folds.tabsInMore) ...[
                            ..._tabEntries(comments, inMore: true),
                            MenuEntry.divider,
                          ],
                          // Only a pull request's link, with the tabs here
                          // too, adds nothing: no empty section.
                          if (folds.links)
                            if (_linkEntries(tabs: !folds.tabsInMore)
                                case final links when links.isNotEmpty) ...[
                              ...links,
                              MenuEntry.divider,
                            ],
                          if (folds.buttons) ...[
                            ..._paneEntries(context),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// How wide [text] sets in [style].
  static double _textWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) => textWidth(context, text, style, merge: false);

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

  /// The Jira key and the GitHub chips, folded into ⋯; the pull request's
  /// only while the tabs aren't there too ([tabs]), whose Pull request is
  /// the same.
  List<MenuEntry> _linkEntries({required bool tabs}) => [
    if (chat.jiraKey.isNotEmpty)
      MenuEntry(
        'Show ${chat.jiraKey} in Jira',
        onPick: () => showIssue(daemon, chat.jiraSite, chat.jiraKey),
      ),
    if (chat.github case final link? when !link.pull)
      MenuEntry(
        'Show #${link.number} from GitHub',
        onPick: () => showItem(daemon, link.asRef, pull: false),
      ),
    if (chat.pull case final link? when tabs)
      MenuEntry(
        'Show pull request #${link.number}',
        onPick: () => onTab(ChatTab.pull),
      ),
  ];

  /// The buttons beside the tabs as rows of ⋯, once they fold there: the
  /// palette's terminal and Files actions for this chat ([paneActions]),
  /// those that apply, and the browser's, which has none. The details'
  /// row is the button's own: it toggles through [onPanel], which comes
  /// only while the panel can show (on Chat, where the palette's applies
  /// too, with room for it), and says what [panel] is.
  List<MenuEntry> _paneEntries(BuildContext context) {
    final panes = paneActions(context, daemon, chat);
    MenuEntry entry(AppAction a, LineIcon line) => MenuEntry(
      a.title,
      shortcut: a.shortcut ?? '',
      line: line,
      onPick: a.run,
    );
    return [
      if (panes.terminal.enabled) entry(panes.terminal, LineIcon.terminal),
      if (panes.files.enabled) entry(panes.files, LineIcon.folder),
      _browserEntry,
      if (onPanel case final toggle?)
        MenuEntry(
          panel ? 'Hide details' : 'Show details',
          line: LineIcon.details,
          onPick: toggle,
        ),
    ];
  }

  /// The browser's button as a row of ⋯, once the buttons fold there.
  MenuEntry get _browserEntry => MenuEntry(
    BrowserButton.tooltip(shown: chat.browserShown),
    line: LineIcon.globe,
    onPick: chat.showOrHideBrowser,
  );

  /// The tabs as rows, Changes with its unsent comments' count, and each
  /// one's key: as a shortcut in ⋯ ([inMore]), else in the field's detail.
  List<MenuEntry> _tabEntries(int comments, {required bool inMore}) => [
    for (final (each, label) in _tabs(chat))
      MenuEntry(
        each == ChatTab.changes && comments > 0 ? '$label $comments' : label,
        detail: inMore ? '' : keyLabel(tabKey(each)),
        shortcut: inMore ? keyLabel(tabKey(each)) : '',
        checked: each == tab,
        onPick: () => onTab(each),
      ),
  ];

  /// The chat's tabs ([ChatState.tabs]: Pull request only with a pull)
  /// and their names.
  List<(ChatTab, String)> _tabs(ChatState chat) => [
    for (final tab in chat.tabs)
      (
        tab,
        switch (tab) {
          ChatTab.chat => 'Chat',
          ChatTab.changes => 'Changes',
          ChatTab.pull => 'Pull request',
        },
      ),
  ];
}

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

/// The least the title keeps: every other part of the row folds first.
const headerTitleLeast = 80.0;

/// Measured: what the row takes once every part [headerFolds] counts has
/// folded, with Chat in the tabs' field: its two ends (28), the agent's
/// mark and the state's dot with their gaps (49), the gap before the rest
/// (12), the field and its gap (54) and ⋯ (32).
const headerFolded = 176.0;

/// What the tabs' field takes with Chat in it, and its gap ([headerFolded]).
const double _fieldRoom = 54;

/// What folding the agent's mark frees: the mark and its gap to the dot.
const double _markRoom = 18 + 8;

/// How wide the tabs' names set in their field (measured): what the field
/// takes past Chat's is the name's width past Chat's.
const ({double chat, double changes, double counted, double pull}) _tabWords = (
  chat: 25,
  changes: 46,
  counted: 64,
  pull: 65,
);

/// What of [headerRow] the longest agent's name takes, with its gap: a
/// shorter name ([headerFolds]' `name`) leaves the row that much less.
const headerName = 71.0;

/// The longest agent's name, which [headerRow] was measured with.
const _longestName = 'OpenCode';

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
  bool model,
  bool name,
  bool word,
  bool panel,
  bool tabs,
  bool buttons,
  bool links,
  bool mark,
  bool tabsInMore,
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
/// takes as so much `more`; [name]: what the agent's name takes with its
/// gap, the longest's ([headerName]) unless said.
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
  double name = headerName,
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
      (name - headerName) +
      (wider - 1) * (headerWords + (pull ? _pullWords : 0));
  final gaps =
      headerGaps + NushiTheme.iconGap + (files ? NushiTheme.iconGap : 0);
  final need = headerRow + more + headerTitleLeast + (model ? 50 : 0);
  var saved = 0.0;
  final folds = <String>{};
  // Each part and about how much folding it frees.
  for (final (part, points) in [
    if (model) ('model', 50.0),
    // What the row counts for each: the agent's name and its gap, the
    // longest state's pill less its dot, the segments less a menu field.
    ('name', name),
    if (!panel) ('panel', button),
    ('word', 106.0),
    ('tabs', (pull ? 160.0 : 72.0) + (comments ? 16 : 0)),
  ]) {
    if (width + saved >= need) break;
    folds.add(part);
    saved += points;
  }
  // With all of that folded, the title still keeps its least: what's left
  // of the row is measured ([headerFolded]), with the widest of the tabs'
  // names in their field, so a switch of tab never folds more or less.
  // The agent's mark goes first (the state's dot says whose it is), then
  // the tabs' field, into ⋯ (ADR 0123), then the pane buttons, all of
  // them together: they toggle what's open beside the chat, so opening a
  // pane (which narrows the chat) mustn't take one away, and one alone
  // gone (the browser's, as it was) reads as a bug. Last, in a header as
  // narrow as beside a pane dragged wide, the Jira key and the GitHub
  // chips, into ⋯ too.
  final buttons = (panel ? 3 : 2) * button + (files ? button : 0);
  if (width + saved < need) {
    final label =
        (pull
            ? _tabWords.pull
            : comments
            ? _tabWords.counted
            : _tabWords.changes) -
        _tabWords.chat;
    var left =
        width -
        headerFolded -
        label -
        (side ? SideChip.width + 8 : 0) -
        (wider - 1) * (_tabWords.chat + label) -
        buttons -
        jira -
        github;
    if (left < headerTitleLeast) {
      folds.add('mark');
      left += _markRoom;
    }
    if (left < headerTitleLeast) {
      folds.add('tabsInMore');
      left += _fieldRoom + label + (wider - 1) * (_tabWords.chat + label);
    }
    if (left < headerTitleLeast) {
      folds.add('buttons');
      saved += buttons;
      left += buttons;
    }
    if (left < headerTitleLeast && jira + github > 0) {
      folds.add('links');
      saved += jira + github;
    }
  }
  final roomy = width >= need + gaps;
  return (
    roomy: roomy,
    model: folds.contains('model'),
    name: folds.contains('name'),
    word: folds.contains('word'),
    panel: folds.contains('panel'),
    tabs: folds.contains('tabs'),
    buttons: folds.contains('buttons'),
    links: folds.contains('links'),
    mark: folds.contains('mark'),
    tabsInMore: folds.contains('tabsInMore'),
    any: folds.isNotEmpty,
    // The model's points were never in the row's 455.
    saved: saved - (folds.contains('model') ? 50 : 0),
    more: more,
    gaps: roomy ? gaps : 0,
  );
}

/// The chat's state's mark beside its word: its dot, or asleep, the moon
/// (the list's dot draws nothing for a sleeping chat).
Widget _stateMark(ChatState chat) =>
    chat.phase == ChatPhase.asleep ? const SleepMark() : ChatDot(chat: chat);
