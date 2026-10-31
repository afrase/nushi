import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The chat's header: its title (double-click renames it), the agent, its
/// model and status, the folder while the details panel is hidden, the
/// Chat | Changes (| Pull request, while it has one) switch with the
/// preview tabs that fit in it, the rest in its overflow, the terminal's
/// and the panel's buttons and the chat's menu. (The files it wrote are in
/// the details panel's Artifacts widget.)
class ChatHeader extends StatefulWidget {
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
  final bool panel; // the details panel shows, with the folder in it
  final VoidCallback? onPanel; // shows or hides it; null when it can't show

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  // The title is a field (a double-click, ⋯'s Rename, or the palette's
  // and the Chat menu's, through the chat).
  bool get _renaming => widget.chat.renaming.value;
  set _renaming(bool v) => widget.chat.renaming.value = v;

  @override
  void initState() {
    super.initState();
    widget.chat.renaming.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChatHeader old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    old.chat.renaming.removeListener(_changed);
    widget.chat.renaming.addListener(_changed);
  }

  @override
  void dispose() {
    widget.chat.renaming.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final meta = theme.ui(t.textSecondary, size: 12);
    final model = chat.option('model');
    final modelName = model?.values
        .where((v) => v.value == model.current)
        .firstOrNull
        ?.name;
    final titleStyle = theme.ui(t.text, weight: FontWeight.w600);
    // The title and the model (a Codex model id is long) share what the
    // rest of the row leaves (it takes about 455 points, the Pull request
    // tab 88 more), so a narrow window cuts them short rather than
    // overflow. Narrower still, the least needed parts fold, so the
    // chat's menu (⋯) stays at the row's end: the model, the agent's name
    // (its mark stays), the details button while the panel can't show,
    // the tabs into a menu field, the status word (the dot's tooltip says
    // it), then the terminal's and the details' buttons into ⋯. Changes
    // counts the review comments not sent yet (14 points more); a hidden
    // side chat's chip takes its own room. Preview tabs only take what
    // the row can spare (past a first [previewTabsLeast] that folds what
    // it must), the title's next 120 points before them, and the rest go
    // in the overflow.
    return ListenableBuilder(
      listenable: Listenable.merge([reviews, chat.side, chat.sideHidden]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final files = chat.tabFiles;
          final comments = unsentComments(chat.id).isNotEmpty;
          final side = chat.side.value != null && chat.sideHidden.value;
          final more =
              (chat.pull == null ? 0 : 88) +
              (comments ? 14 : 0) +
              (side ? SideChip.width : 0);
          final folds = headerFolds(
            box.maxWidth,
            pull: chat.pull != null,
            panel: widget.onPanel != null,
            model: modelName != null,
            comments: comments,
            side: side,
            files: files.isNotEmpty,
          );
          final shown = modelName != null && !folds.model;
          // What the title, the model (its gap taken out) and the tabs
          // share.
          final spare =
              box.maxWidth - 455 - more + folds.saved - (shown ? 10 : 0);
          const least = 80.0;
          final fit = folds.tabs
              ? noTabs
              : fitTabs(
                  files,
                  chat.shownStop.file,
                  (f) => tabWidth(context, tabLabel(f, files)),
                  max(
                    min(spare - least, previewTabsLeast),
                    spare - least - 120 - (shown ? 40 : 0),
                  ),
                );
          final room =
              spare -
              fit.width -
              (folds.tabs && files.isNotEmpty ? _foldedFile : 0);
          var title = (room * 0.6).clamp(least, 320.0);
          if (shown) title = min(title, max(least, room - 40));
          return _row(
            context,
            titleStyle,
            meta,
            modelName,
            folds,
            fit,
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
    HeaderFolds folds,
    FittedTabs fit, {
    required double titleMax,
    required double modelMax,
  }) {
    final t = NushiTheme.of(context).t;
    final theme = NushiTheme.of(context);
    final chat = widget.chat;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: titleMax),
            child: _renaming
                ? RenameField(
                    chat: chat,
                    daemon: widget.daemon,
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
            const SizedBox(width: 10),
            LinkText(
              chat.jiraKey,
              mono: true,
              size: 12,
              tooltip: 'Show ${chat.jiraKey} in Jira',
              onTap: () =>
                  showIssue(widget.daemon, chat.jiraSite, chat.jiraKey),
            ),
          ],
          if (chat.github case final link?) ...[
            const SizedBox(width: 10),
            GitHubChip(
              key: ValueKey(link.id),
              daemon: widget.daemon,
              link: link,
            ),
          ],
          const SizedBox(width: 14),
          Tooltip(
            message: folds.name ? chat.agentName : '',
            child: AgentMark(chat.agent, size: 16, color: t.text),
          ),
          if (!folds.name) ...[
            const SizedBox(width: 8),
            Text(
              chat.agentName,
              style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
            ),
          ],
          if (modelName != null && !folds.model) ...[
            const SizedBox(width: 10),
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
          const SizedBox(width: 10),
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
          const SizedBox(width: 16),
          Expanded(
            // The folder, unless the panel has it or there's no room: it
            // goes before anything folds.
            child: LayoutBuilder(
              builder: (context, box) =>
                  widget.panel || box.maxWidth < 90 || folds.any
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: FolderButton(chat: chat, daemon: widget.daemon),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          if (chat.side.value != null && chat.sideHidden.value) ...[
            SideChip(chat),
            const SizedBox(width: 8),
          ],
          if (folds.tabs)
            MenuField(
              compact: true,
              tooltip: '⌃⇥ the next tab, ⌃⇧⇥ the one before',
              entries: [
                for (final (stop, label) in _tabs(chat, chat.tabFiles))
                  _entry(chat, stop, label),
              ],
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 45.0 + _foldedFile),
                child: Text(
                  _tabs(
                    chat,
                    chat.tabFiles,
                  ).firstWhere((s) => s.$1 == _stop).$2,
                ),
              ),
            )
          else
            Segmented(
              value: _stop,
              segments: _tabs(chat, fit.shown),
              onChanged: _pick,
              tooltip: (stop) => [
                _keyOf(chat, stop),
                stop.file ?? '⌃⇥ the next tab, ⌃⇧⇥ the one before',
              ].where((part) => part.isNotEmpty).join('   '),
              onClose: (stop) => switch (stop.file) {
                final file? => () => chat.closeTab(file),
                null => null,
              },
              after: fit.over.isEmpty
                  ? null
                  : MenuField(
                      compact: true,
                      tooltip: 'More preview tabs',
                      label: Text('+${fit.over.length}'),
                      entries: [
                        for (final f in fit.over)
                          _entry(chat, (
                            tab: ChatTab.preview,
                            file: f,
                          ), tabLabel(f, chat.tabFiles)),
                      ],
                    ),
            ),
          const SizedBox(width: 4),
          if (!folds.buttons) TerminalButton(chat: chat, daemon: widget.daemon),
          if (!folds.buttons && !folds.panel)
            IconTap(
              Icons.view_sidebar_outlined,
              tooltip: widget.onPanel == null
                  ? 'The window is too narrow'
                  : widget.panel
                  ? 'Hide details'
                  : 'Show details',
              color: widget.panel ? t.text : t.textSecondary,
              onTap: widget.onPanel,
            ),
          MenuIcon(
            Icons.more_horiz,
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
                    icon: Icons.terminal,
                    onPick: () => toggleTerminal(chat.id),
                  ),
                if (widget.onPanel case final toggle?)
                  MenuEntry(
                    widget.panel ? 'Hide details' : 'Show details',
                    icon: Icons.view_sidebar_outlined,
                    onPick: toggle,
                  ),
                MenuEntry.divider,
              ],
              ...chatMenu(
                context,
                chat,
                widget.daemon,
                onRename: () => _renaming = true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The tab showing, as the row marks it.
  TabStop get _stop => (
    tab: widget.tab,
    file: widget.tab == ChatTab.preview ? widget.chat.tabFile.value : null,
  );

  void _pick(TabStop stop) =>
      stop.file == null ? widget.onTab(stop.tab) : widget.chat.showStop(stop);

  String _keyOf(ChatState chat, TabStop stop) =>
      switch (tabKey(stop.tab, file: chat.tabFiles.indexOf(stop.file ?? ''))) {
        final key? => keyLabel(key),
        null => '',
      };

  /// A tab as a menu's row: a preview tab's has its close button.
  MenuEntry _entry(ChatState chat, TabStop stop, String label) => MenuEntry(
    label,
    detail: _keyOf(chat, stop),
    checked: stop == _stop,
    tooltip: stop.file ?? '',
    onPick: () => _pick(stop),
    action: switch (stop.file) {
      final file? => ({required hover}) => closeTabMark(chat, file),
      null => null,
    },
  );

  /// Chat, Changes, Pull request while it has one, then [files]' preview
  /// tabs.
  List<(TabStop, String)> _tabs(ChatState chat, List<String> files) => [
    ((tab: ChatTab.chat, file: null), 'Chat'),
    switch (unsentComments(chat.id).length) {
      0 => ((tab: ChatTab.changes, file: null), 'Changes'),
      final n => ((tab: ChatTab.changes, file: null), 'Changes $n'),
    },
    if (chat.pull != null) ((tab: ChatTab.pull, file: null), 'Pull request'),
    for (final f in files)
      ((tab: ChatTab.preview, file: f), tabLabel(f, chat.tabFiles)),
  ];
}

/// The header's room for preview tabs at the least: one at its widest,
/// and the overflow. Less, and the tabs fold.
const double previewTabsLeast =
    Segmented.closableLabel + Segmented.closableRest + tabOverflowWidth;

/// How much more the folded tabs' field takes with a file in it, cut short
/// if it must be, than with "Changes".
const _foldedFile = 60.0;

/// What of the chat's header folds at a width, the least needed first,
/// and the points that frees of the row's 455 (the model's aren't in it).
typedef HeaderFolds = ({
  bool model,
  bool name,
  bool word,
  bool panel,
  bool tabs,
  bool buttons,
  bool any,
  double saved,
});

/// The parts of the header that fold in [width] (see [ChatHeader]): each
/// in turn until the title has its 80 points. [pull]: the chat has the
/// Pull request tab; [panel]: the details panel can show; [model]: the
/// header names a model (40 points at least, and its gap); [side]: a
/// hidden side chat's chip shows; [files]: it has preview tabs.
HeaderFolds headerFolds(
  double width, {
  required bool pull,
  required bool panel,
  bool model = false,
  bool comments = false,
  bool side = false,
  bool files = false,
}) {
  // Measured: the row without its title and model takes about 455
  // points (oh-my-pi's name, "in background"), the Pull request tab 88
  // more.
  final need =
      455.0 +
      (pull ? 88 : 0) +
      (comments ? 14 : 0) +
      (side ? SideChip.width : 0) +
      80 +
      (model ? 50 : 0) +
      (files ? previewTabsLeast : 0);
  var saved = 0.0;
  final folds = <String>{};
  // Each part and about how much folding it frees.
  for (final (part, points) in [
    if (model) ('model', 50.0),
    ('name', 48.0),
    if (!panel) ('panel', 26.0),
    (
      'tabs',
      (pull ? 115.0 : 50.0) +
          (comments ? 14 : 0) +
          (files ? previewTabsLeast - _foldedFile : 0),
    ),
    ('word', 45.0),
    ('buttons', panel ? 52.0 : 26.0),
  ]) {
    if (width + saved >= need) break;
    folds.add(part);
    saved += points;
  }
  return (
    model: folds.contains('model'),
    name: folds.contains('name'),
    word: folds.contains('word'),
    panel: folds.contains('panel'),
    tabs: folds.contains('tabs'),
    buttons: folds.contains('buttons'),
    any: folds.isNotEmpty,
    // The model's points were never in the row's 455, nor the tabs'.
    saved:
        saved -
        (folds.contains('model') ? 50 : 0) -
        (files && folds.contains('tabs') ? previewTabsLeast - _foldedFile : 0),
  );
}
