import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/removed_chats.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';

void main() => runZonedGuarded(() {
  WidgetsFlutterBinding.ensureInitialized();
  catchErrors();
  runApp(NushiApp(daemon: Daemon()));
}, (e, s) => appLog.error('uncaught error', e, s));

class NushiApp extends StatefulWidget {
  const new({required this.daemon, super.key});

  final Daemon daemon;

  @override
  State<NushiApp> createState() => _NushiAppState();
}

class _NushiAppState extends State<NushiApp> {
  ThemeMode _mode = ThemeMode.system;
  final _navigator = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    watchPairings(_navigator, widget.daemon.client);
    // The app coming to the front shows its chat again; the daemon knows
    // whether the window shows (focused or not) or is hidden.
    _lifecycle = AppLifecycleListener(
      onResume: widget.daemon.shown,
      onStateChange: (s) => widget.daemon.macView.window =
          s == AppLifecycleState.resumed || s == AppLifecycleState.inactive,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  PlatformMenuItem _appearance(String label, ThemeMode mode) =>
      PlatformMenuItem(
        label: label,
        onSelected: () => setState(() => _mode = mode),
      );

  /// [act]'s item in the menu bar: its label and key; it runs as from
  /// the palette.
  PlatformMenuItem _item(Act act) => PlatformMenuItem(
    label: act.menuLabel!,
    shortcut: act.key,
    onSelected: () => runAct(_navigator.currentContext!, widget.daemon, act),
  );

  List<PlatformMenuItem> _items(ActMenu menu) => [
    for (final a in Act.values)
      if (a.menu == menu) _item(a),
  ];

  @override
  Widget build(BuildContext context) => PlatformMenuBar(
    menus: [
      PlatformMenu(
        label: 'Nushi',
        menus: [
          const PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.about,
          ),
          ..._items(ActMenu.nushi),
          const PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.hide,
          ),
          const PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.quit,
          ),
        ],
      ),
      PlatformMenu(label: 'File', menus: _items(ActMenu.file)),
      PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItem(
            label: 'Command Palette…',
            shortcut: paletteKey,
            onSelected: () => unawaited(
              showPalette(_navigator.currentContext!, widget.daemon),
            ),
          ),
          PlatformMenuItemGroup(members: _items(ActMenu.view)),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: 'Previous Chat',
                shortcut: previousChatKey,
                onSelected: () => stepChat(widget.daemon, -1),
              ),
              PlatformMenuItem(
                label: 'Next Chat',
                shortcut: nextChatKey,
                onSelected: () => stepChat(widget.daemon, 1),
              ),
              // Hold ⌘ to see the numbers in the sidebar.
              PlatformMenu(
                label: 'Open Chat',
                menus: [
                  for (var n = 1; n <= 9; n++)
                    PlatformMenuItem(
                      label: 'Chat $n in the Sidebar',
                      shortcut: chatNumberKey(n),
                      onSelected: () => openNthChat(widget.daemon, n),
                    ),
                ],
              ),
            ],
          ),
          _appearance('Light Appearance', ThemeMode.light),
          _appearance('Dark Appearance', ThemeMode.dark),
          _appearance('System Appearance', ThemeMode.system),
        ],
      ),
    ],
    child: MaterialApp(
      navigatorKey: _navigator,
      title: 'Nushi',
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.light).toThemeData(),
      darkTheme: const NushiTheme(Tokens.dark).toThemeData(),
      themeMode: _mode,
      scrollBehavior: const NativeScroll(),
      // The menu's keys don't reach the menu while Flutter has the keys:
      // they're bound here too, and a terminal, which keeps ⌘ and ⌃ keys,
      // passes them on as the same intents.
      home: Builder(
        builder: (context) => Actions(
          actions: {
            RunActIntent: CallbackAction<RunActIntent>(
              onInvoke: (i) => runAct(context, widget.daemon, i.act),
            ),
            OpenPaletteIntent: CallbackAction<OpenPaletteIntent>(
              onInvoke: (_) => unawaited(showPalette(context, widget.daemon)),
            ),
            OpenChatIntent: CallbackAction<OpenChatIntent>(
              onInvoke: (i) => openNthChat(widget.daemon, i.n),
            ),
            StepChatIntent: CallbackAction<StepChatIntent>(
              onInvoke: (i) => stepChat(widget.daemon, i.step),
            ),
            StepTabIntent: CallbackAction<StepTabIntent>(
              onInvoke: (i) {
                if (chatShown(widget.daemon)) {
                  stepTab(widget.daemon.selected!, i.step);
                }
                return null;
              },
            ),
          },
          // The actions' keys, ⌘K, ⌘1–⌘9, ⌘[ and ⌘], ⌃Tab and ⌃⇧Tab:
          // wherever the focus is.
          child: Shortcuts(
            shortcuts: {
              ...actKeys,
              paletteKey: const OpenPaletteIntent(),
              paletteKeyToo: const OpenPaletteIntent(),
              ...chatKeys,
            },
            // Focused when nothing in the window is, so the keys still
            // come here (an empty pane, after a click on the sidebar).
            child: Focus(
              autofocus: true,
              child: Scaffold(body: _Shell(widget.daemon)),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Shell extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: daemon,
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      // Never connected yet: nothing to show. Once it was, a lost
      // connection is a banner over the app, which keeps what's open.
      if (!daemon.connected && daemon.daemonApi == 0) {
        return Center(
          child: Text(
            bundledDaemon == null
                ? 'Daemon not running'
                : daemon.launchFailed
                ? "Couldn't start the daemon. Its log: "
                      '${tildePath('$dataDir/nushid.log')}'
                : 'Starting the daemon…',
            style: theme.ui(theme.t.textSecondary),
          ),
        );
      }
      if (daemon.outdated && !daemon.updatesWhenIdle) {
        return OutdatedScreen(daemon);
      }
      final chat = daemon.selected;
      final app = LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Resizable(
              name: 'sidebar',
              initial: 260,
              min: 200,
              max: min(480, box.maxWidth - 560),
              child: Sidebar(daemon: daemon),
            ),
            Expanded(
              child: daemon.trustAsk != null
                  ? TrustCard(daemon.trustAsk!)
                  : daemon.jiraOpen
                  ? JiraView(daemon)
                  : daemon.githubOpen
                  ? GitHubView(daemon)
                  : daemon.settings != null
                  ? SettingsView(daemon)
                  : chat == null
                  ? NothingOpen(daemon)
                  : _ChatPane(key: ValueKey(chat.id), chat, daemon),
            ),
          ],
        ),
      );
      // Always a column, the app its last child: the banner coming and
      // going keeps the app's state.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!daemon.connected)
            Container(
              color: theme.t.needsSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                daemon.updating
                    ? 'Starting the new daemon…'
                    : 'Lost the connection to the daemon; reconnecting…',
                style: theme.ui(theme.t.needs, size: 12),
              ),
            ),
          if (daemon.connected && daemon.updatesWhenIdle)
            DaemonUpdateBar(daemon),
          if (daemon.connected && daemon.removedChats.isNotEmpty)
            RemovedChatsBar(daemon),
          Expanded(child: app),
          StatusBar(daemon),
        ],
      );
    },
  );
}

/// A chat under its header, with a switch between its transcript, its
/// folder's changes and its pull request.
class _ChatPane extends StatefulWidget {
  const new(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  ValueNotifier<ChatTab> get _tab => widget.chat.tab;

  /// Its pull request, looked for while the chat shows (for the tab).
  late final ChatPull _pull;

  @override
  void initState() {
    super.initState();
    _tab.value = ChatTab.chat; // a chat opens on its transcript
    widget.chat.addListener(_showFile);
    widget.chat.preview.addListener(_showPreview);
    _pull = ChatPull.of(widget.daemon, widget.chat)..follow();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_showFile);
    widget.chat.preview.removeListener(_showPreview);
    _pull.unfollow();
    super.dispose();
  }

  /// A file's preview opened (from Artifacts, or ⌘P) shows beside the chat.
  void _showPreview() {
    if (widget.chat.preview.value != null) _tab.value = ChatTab.chat;
  }

  /// A file to show (ChatState.showFile, from a review's finding) shows in
  /// the Changes view.
  void _showFile() {
    if (widget.chat.openPath != null) _tab.value = ChatTab.changes;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ListenableBuilder(
      listenable: Listenable.merge([showDetails, _tab]),
      builder: (context, _) {
        final show = showDetails.value;
        // The panel goes when the chat would get too narrow.
        final fits =
            box.maxWidth >=
            paneWidth('details', DetailsPanel.width) + ChatView.minWidth;
        widget.chat.panelFits = fits;
        // The pull request's tab goes with its link.
        final tab = widget.chat.shownTab;
        final panel = show && fits && tab == ChatTab.chat;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: widget.chat,
              builder: (context, _) => ChatHeader(
                widget.chat,
                widget.daemon,
                tab: widget.chat.shownTab,
                onTab: (t) => _tab.value = t,
                panel: panel,
                onPanel: fits && tab == ChatTab.chat
                    ? () => showDetails.value = !show
                    : null,
              ),
            ),
            Expanded(
              child: TerminalArea(
                chat: widget.chat,
                daemon: widget.daemon,
                onChanges: () => _tab.value = ChatTab.changes,
                child: switch (tab) {
                  ChatTab.changes => ChangesView(
                    chat: widget.chat,
                    daemon: widget.daemon,
                  ),
                  ChatTab.pull => PullTab(
                    chat: widget.chat,
                    daemon: widget.daemon,
                    onChat: () => _tab.value = ChatTab.chat,
                  ),
                  ChatTab.chat => ChatView(
                    chat: widget.chat,
                    daemon: widget.daemon,
                    details: panel
                        ? DetailsPanel(
                            chat: widget.chat,
                            daemon: widget.daemon,
                            onChanges: () => _tab.value = ChatTab.changes,
                            onPull: () => _tab.value = ChatTab.pull,
                          )
                        : null,
                  ),
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
