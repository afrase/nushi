import 'dart:async';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/acts.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/app_install.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/native.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/preview_find.dart' show focusedPreviewFind;
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/review.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/view_options.dart';
import 'package:nushi/web_find.dart' show focusedPageFind, pageFinds;
import 'package:nushi/web_views.dart' show webEmbedded;
import 'package:nushi/widgets.dart';

export 'package:nushi/acts.dart';

/// Every action, each as it is now (its title, whether it applies).
/// [context] is where its dialogs open.
List<AppAction> appActions(BuildContext context, Daemon d) {
  final chat = d.selected;
  final shown = d.chatShows ? chat : null;
  void tab(ChatTab t) => shown?.tab.value = t;
  final panes = paneActions(context, d, shown);
  // The browser tab in sight, under no dialog.
  final browser = switch (shown?.browser.shown.value) {
    final tab?
        when shown?.shownTab == ChatTab.chat &&
            !(Navigator.maybeOf(context)?.canPop() ?? false) =>
      tab.view,
    _ => null,
  };
  // The file the preview shows, being edited, in sight under no dialog.
  final edited = switch (shown?.shownFile) {
    final path?
        when shown?.shownTab == ChatTab.chat &&
            !(Navigator.maybeOf(context)?.canPop() ?? false) =>
      shown!.edits[path],
    _ => null,
  };
  final closing = shown == null ? null : tabToClose(shown);
  // The preview with the focus, which ⌘F finds in (issue 63); else the
  // chat's or Changes', not under a pane expanded over the transcript,
  // where its bar would open unseen.
  final preview = shown == null ? null : focusedPreviewFind();
  final chatFinds =
      shown != null &&
      (shown.shownTab == ChatTab.chat && shown.covered == null ||
          shown.shownTab == ChatTab.changes);
  return [
    AppAction(.newChat, 'New chat', run: () => newChat(context, d, '')),
    AppAction(
      .openFile,
      'Open file…',
      enabled: shown != null,
      run: () => unawaited(openFile(context, d)),
    ),
    AppAction(
      .closeTab,
      'Close tab',
      // Only a tab in sight, and never under a dialog: its ⌘W, which
      // Flutter's keys don't reach, comes here from the menu bar.
      enabled:
          closing != null &&
          shown?.shownTab == ChatTab.chat &&
          !(Navigator.maybeOf(context)?.canPop() ?? false),
      run: () => unawaited(closeTabSaving(context, shown!, closing!)),
    ),
    AppAction(
      .save,
      'Save the file',
      enabled: edited?.canSave ?? false,
      run: () => unawaited(edited!.save()),
    ),
    AppAction(
      .newBrowserTab,
      'New browser tab',
      enabled: shown != null,
      run: () => shown!.openBrowserTab(),
    ),
    // ⌘L and ⌘R are the menu bar's too, so they reach here while WebKit has
    // the keys (ADR 0094).
    AppAction(
      .address,
      'Open location…',
      enabled: browser != null,
      run: () => browser!.focusAddress(),
    ),
    AppAction(
      .reloadPage,
      'Reload page',
      // A page in the browser reloads there (ADR 0104).
      enabled: browser != null && webEmbedded,
      run: () => browser!.reload(),
    ),
    AppAction(
      .artifacts,
      'Artifacts…',
      enabled: shown != null && chatFilesOf(shown).isNotEmpty,
      run: () => revealArtifacts(context, shown!),
    ),
    AppAction(
      .find,
      preview != null
          ? 'Find in the file'
          : shown?.shownTab == ChatTab.changes
          ? 'Find in changes'
          : 'Find in the chat',
      // A preview with the focus finds in its file. A page's web view with
      // the keys gives ⌘F to the menu bar, which comes here: that page's
      // find, asked of the web views shown.
      enabled: preview != null || pageFinds.isNotEmpty || chatFinds,
      run: () {
        void own() {
          if (preview != null) {
            preview.open();
          } else if (chatFinds) {
            shown.shownTab == ChatTab.changes
                ? shown.changesFind.open()
                : shown.find.open();
          }
        }

        if (pageFinds.isEmpty) return own();
        unawaited(
          focusedPageFind().then(
            (page) => page == null ? own() : page.openFromPage(),
          ),
        );
      },
    ),
    AppAction(
      .chat,
      'Show chat',
      enabled: shown != null,
      run: () => tab(.chat),
    ),
    AppAction(
      .changes,
      'Show changes',
      enabled: shown != null,
      run: () => tab(.changes),
    ),
    AppAction(
      .pull,
      'Show pull request',
      enabled: shown?.pull != null,
      run: () => tab(.pull),
    ),
    AppAction(
      .previousTab,
      'Previous tab',
      enabled: shown != null,
      run: () => stepTab(shown!, -1),
    ),
    AppAction(
      .nextTab,
      'Next tab',
      enabled: shown != null,
      run: () => stepTab(shown!, 1),
    ),
    AppAction(
      .sidebar,
      sidebarShut ? 'Show the sidebar' : 'Hide the sidebar',
      run: toggleSidebar,
    ),
    AppAction(.back, 'Back', enabled: d.canGoBack, run: d.goBack),
    AppAction(.forward, 'Forward', enabled: d.canGoForward, run: d.goForward),
    panes.details,
    panes.files,
    ...viewActions(shown, d),
    AppAction(
      .chatWidth,
      chatFullWidth.value ? 'Center the chat' : 'Show the chat at full width',
      run: () => chatFullWidth.value = !chatFullWidth.value,
    ),
    AppAction(
      .unifiedDiff,
      diffUnified.value ? 'Show diffs side by side' : 'Show diffs unified',
      // One choice for the app, as a pull request's Files follows it too.
      run: () => diffUnified.value = !diffUnified.value,
    ),
    panes.terminal,
    AppAction(
      .rewind,
      'Rewind…',
      // A long chat's earlier messages may be rewound to once loaded; the
      // chat itself must allow it now, as each message's own check asks.
      enabled:
          shown != null &&
          (rewindChoices(shown).isNotEmpty ||
              (shown.older > 0 &&
                  shown.canRewind &&
                  !shown.busy &&
                  !shown.archived)),
      run: () => unawaited(pickRewind(context, d, shown!)),
    ),
    AppAction(
      .nextTypo,
      'Next typo',
      enabled: _spellOf(shown) != null,
      run: () => unawaited(_spellOf(shown)!.menu.next()),
    ),
    ...chatActions(context, d, shown),
    AppAction(.settings, 'Settings', run: d.toggleSettings),
    AppAction(
      .appearance,
      'Appearance and themes',
      run: () => d.openSettings(section: SettingsSection.appearance),
    ),
    AppAction(
      .shortcuts,
      'Keyboard shortcuts',
      run: () => d.openSettings(section: SettingsSection.shortcuts),
    ),
    AppAction(
      .jira,
      d.place is JiraPlace ? 'Close Jira' : 'Jira',
      run: () => d.toggle(const JiraPlace()),
    ),
    AppAction(
      .github,
      d.place is GitHubPlace ? 'Close GitHub' : 'GitHub',
      run: () => d.toggle(const GitHubPlace()),
    ),
    AppAction(
      .restart,
      'Restart daemon',
      enabled: native.install.restartsDaemon,
      run: () => unawaited(restartDaemonAsking(context, d)),
    ),
    AppAction(
      .checkUpdates,
      'Check for updates',
      enabled: d.connected && d.daemonApi >= updatesApi,
      run: () => unawaited(checkForUpdates(context, d)),
    ),
    if (!native.window.menuBar) ...[
      AppAction(
        .previousChat,
        'Previous chat',
        enabled: d.chats.isNotEmpty,
        run: () => stepChat(d, -1),
      ),
      AppAction(
        .nextChat,
        'Next chat',
        enabled: d.chats.isNotEmpty,
        run: () => stepChat(d, 1),
      ),
      AppAction(.quit, 'Quit Nushi', run: () => unawaited(_quit())),
    ],
  ];
}

/// The buttons beside [chat]'s tabs as actions (the shown chat's, from
/// the palette; the header's own, folded into its ⋯): the terminal under
/// it, the Files pane and the details panel, each as it is now. The
/// header adds its own rule for the details (room for the panel).
({AppAction terminal, AppAction files, AppAction details}) paneActions(
  BuildContext context,
  Daemon d,
  ChatState? chat,
) {
  final details = showDetails.value;
  return (
    terminal: AppAction(
      .terminal,
      chat != null && terminalChats.value.contains(chat.id)
          ? 'Hide terminal'
          : 'Show terminal',
      enabled: chat != null && !chat.archived,
      run: () => toggleTerminal(chat!.id),
    ),
    files: AppAction(
      .files,
      chat != null && filesShown(chat) ? 'Hide files' : 'Show files',
      enabled: chat != null && d.daemonApi >= filesApi,
      run: () => showOrHideFiles(chat!),
    ),
    details: AppAction(
      .details,
      details ? 'Hide details' : 'Show details',
      enabled: chat?.shownTab == ChatTab.chat,
      run: () => showDetails.value = !details,
    ),
  );
}

/// Quits the app, where no menu bar's Quit does: what would be lost asks
/// first (the app's onExitRequested: edits that can't be saved), as a
/// cancelable exit's request does, and then the engine exits.
Future<void> _quit() async {
  final binding = ServicesBinding.instance;
  if (await binding.handleRequestAppExit() == AppExitResponse.exit) {
    await binding.exitApplication(AppExitType.required);
  }
}

/// Clean up the worktree…: with the tab's pull request whole, for its
/// branch on GitHub (read now unless the tab shows it; ADR 0140).
Future<void> _cleanUp(BuildContext context, Daemon d, ChatState chat) async {
  final cp = ChatPull.of(d, chat);
  final l = cp.current;
  final pull = l == null ? null : await cp.whole(context, l);
  if (!context.mounted) return;
  await showCleanUp(context, d, chat, pull: pull);
}

/// The spell check ⌘; goes through in [chat], while it runs: its prompt
/// box's, or its side chat's if that one has the focus. The box must be in
/// sight.
SpellCheck? _spellOf(ChatState? chat) {
  if (chat == null || chat.shownTab != ChatTab.chat) return null;
  final side = chat.side.value?.draft.text.spell;
  final spell = side?.focus.hasFocus ?? false ? side : chat.draft.text.spell;
  return (spell?.on ?? false) ? spell : null;
}

/// What can be done to [chat] (the shown one, from the palette and the
/// menu bar; any, from its ⋯ menu or its sidebar row's), each as it is now:
/// the Chat menu's actions. Without a chat they don't apply, but MCP
/// servers and Skills, which open their Settings sections. [onRename]
/// renames in place (a sidebar row); else the header's title does.
List<AppAction> chatActions(
  BuildContext context,
  Daemon d,
  ChatState? chat, {
  VoidCallback? onRename,
}) {
  final live = chat != null && !chat.archived && !chat.sessionGone;
  final comments = chat == null ? 0 : unsentComments(chat.id).length;
  return [
    AppAction(
      .sideChat,
      switch (chat?.side.value) {
        null => 'Side chat',
        _ when chat!.sideHidden.value => 'Show the side chat',
        _ => 'Hide the side chat',
      },
      enabled: live && (chat.canFork || chat.side.value != null),
      run: () => unawaited(toggleSide(context, d, chat!)),
    ),
    AppAction(
      .fork,
      'Fork chat',
      short: 'Fork',
      enabled: canForkChat(d, chat),
      run: () => unawaited(forkChat(context, d, chat!)),
    ),
    AppAction(
      .sendComments,
      'Send review comments to agent ($comments)',
      short: 'Send review comments ($comments)',
      enabled: live && comments > 0,
      run: () => reviewToBox(chat!),
    ),
    AppAction(
      .stop,
      'Stop the turn',
      short: 'Stop',
      enabled: chat != null && chat.started != null && !chat.stopping,
      run: () => unawaited(stopTurn(context, chat!, d)),
    ),
    AppAction(
      .rename,
      'Rename chat',
      short: 'Rename',
      enabled: chat != null,
      run: onRename ?? () => chat!.renaming.value = true,
    ),
    AppAction(
      .pin,
      (chat?.pin ?? 0) > 0 ? 'Unpin chat' : 'Pin chat',
      short: (chat?.pin ?? 0) > 0 ? 'Unpin' : 'Pin',
      enabled: canPinChat(d, chat),
      run: () => tryOrShow(context, () => toggleChatPin(d, chat!)),
    ),
    AppAction(
      .sleep,
      'Sleep chat',
      short: 'Sleep',
      enabled: chat != null && chat.canSleep && !chat.archived,
      run: () => unawaited(sleepChat(context, chat!, d)),
    ),
    AppAction(
      .reload,
      'Reload chat',
      short: 'Reload',
      enabled: live && !chat.busy && !chat.asleep && !chat.reopenFailed,
      // Nothing in the chat shows a reload: a toast says it.
      run: () => unawaited(reloadChat(context, chat!, d, say: true)),
    ),
    AppAction(
      .linkPull,
      chat?.pull == null ? 'Link pull request…' : 'Link another pull request…',
      enabled: live,
      run: () => unawaited(linkPull(context, ChatPull.of(d, chat!))),
    ),
    AppAction(
      .cleanUp,
      'Clean up the worktree…',
      short: 'Clean up…',
      enabled:
          chat != null && chat.worktree != null && !CleanUpJob.of(chat).running,
      run: () => unawaited(_cleanUp(context, d, chat!)),
    ),
    AppAction(
      .archive,
      'Archive chat',
      short: 'Archive',
      enabled: chat != null && !chat.archived,
      run: () => tryOrShow(context, () => archiveChat(context, chat!, d)),
    ),
    AppAction(
      .unarchive,
      'Unarchive chat',
      short: 'Unarchive',
      enabled: chat != null && chat.archived,
      run: () => tryOrShow(context, () => archiveChat(context, chat!, d)),
    ),
    AppAction(
      .mcp,
      'MCP servers',
      short: 'MCP servers…',
      enabled: knownAgents[chat?.agent]?.mcp ?? true,
      run: () => chat == null
          ? d.openSettings(section: SettingsSection.mcp)
          : d.showMcp(chat.folder),
    ),
    AppAction(
      .skills,
      'Skills',
      short: 'Skills…',
      run: () => chat == null
          ? d.openSettings(section: SettingsSection.skills)
          : d.showSkills(chat.folder, agent: chat.agent),
    ),
    AppAction(
      .delete,
      'Delete chat…',
      short: 'Delete…',
      enabled: chat != null,
      run: () => unawaited(showDeleteChat(context, chat!, d)),
    ),
  ];
}

/// Runs [act] as it is now, if it applies.
void runAct(BuildContext context, Daemon d, Act act) {
  // The palette is no row of its own; its key never reaches here past
  // Settings, so it shuts nothing.
  if (act == Act.palette) return unawaited(showPalette(context, d));
  // Only the menu bar (and Linux's Quit) reaches here past Settings (it
  // stops the keys): what runs is elsewhere, so Settings shuts first (ADR
  // 0087).
  if (!const {
    Act.settings,
    Act.appearance,
    Act.shortcuts,
    Act.quit,
  }.contains(act)) {
    d.closeSettings();
  }
  final a = appActions(context, d).firstWhere((a) => a.act == act);
  if (a.enabled) a.run();
}
