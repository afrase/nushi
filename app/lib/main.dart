import 'dart:async';
import 'dart:math';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'package:nushi/alerts.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/comment_drafts_mac.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/drafts_mac.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/nothing_open.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/removed_chats.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';
import 'package:nushi/update_toast.dart';

void main() => runZonedGuarded(() {
  WidgetsFlutterBinding.ensureInitialized();
  catchErrors();
  runApp(
    NushiApp(
      daemon: Daemon(drafts: Drafts(DraftFiles(dataDir))),
      commentDrafts: CommentDraftFile(dataDir),
    ),
  );
}, (e, s) => appLog.error('uncaught error', e, s));

class NushiApp extends StatefulWidget {
  const new({required this.daemon, this.commentDrafts, super.key});

  final Daemon daemon;

  /// Keeps GitHub's and Jira's drafts across a restart (none in tests).
  final CommentDraftFile? commentDrafts;

  @override
  State<NushiApp> createState() => _NushiAppState();
}

class _NushiAppState extends State<NushiApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;
  late final MacAlerts _alerts;

  @override
  void initState() {
    super.initState();
    watchPairings(_navigator, widget.daemon.client);
    _alerts = MacAlerts(widget.daemon);
    widget.daemon.addListener(_pinChanged);
    sidebarHidden.addListener(_sidebarChanged);
    // The app coming to the front shows its chat again; the daemon knows
    // whether the window shows (focused or not) or is hidden, and the
    // notifications whether it's in front. Drafts are saved at once when
    // the app goes to the back or quits.
    final drafts = widget.daemon.drafts;
    final comments = widget.commentDrafts;
    void saveDrafts() {
      comments?.flush();
      unawaited(drafts?.flush());
    }

    _lifecycle = AppLifecycleListener(
      onResume: widget.daemon.shown,
      onInactive: saveDrafts,
      onHide: saveDrafts,
      onExitRequested: () async {
        comments?.flush();
        try {
          await drafts?.flush().timeout(const Duration(seconds: 1));
        } on Object {
          // Quits all the same; the last save is at most 500 ms old.
        }
        return AppExitResponse.exit;
      },
      onStateChange: (s) {
        widget.daemon.macView.window =
            s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;
        _alerts.focused = s == AppLifecycleState.resumed;
      },
    );
  }

  /// Whether the shown chat is pinned: the Chat menu's Pin Chat says
  /// Unpin Chat then.
  bool _pinned = false;

  void _pinChanged() {
    final pinned = (widget.daemon.selected?.pin ?? 0) > 0;
    if (pinned != _pinned) setState(() => _pinned = pinned);
  }

  /// The View menu's Hide Sidebar says Show Sidebar while it's hidden.
  void _sidebarChanged() => setState(() {});

  @override
  void dispose() {
    sidebarHidden.removeListener(_sidebarChanged);
    widget.daemon.removeListener(_pinChanged);
    _alerts.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  PlatformMenuItem _appearance(String label, ThemeMode mode) =>
      PlatformMenuItem(label: label, onSelected: () => appearance.value = mode);

  /// [act]'s item in the menu bar: its label and key; it runs as from
  /// the palette.
  PlatformMenuItem _item(Act act) => PlatformMenuItem(
    label: switch (act) {
      Act.pin when _pinned => 'Unpin Chat',
      Act.sidebar when sidebarShut => 'Show Sidebar',
      _ => act.menuLabel!,
    },
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
      // The shown chat's actions, as its ⋯ menu has them.
      PlatformMenu(label: 'Chat', menus: _items(ActMenu.chat)),
    ],
    child: ValueListenableBuilder(
      valueListenable: appearance,
      builder: (context, mode, home) => MaterialApp(
        navigatorKey: _navigator,
        title: 'Nushi',
        debugShowCheckedModeBanner: false,
        theme: const NushiTheme(Tokens.light).toThemeData(),
        darkTheme: const NushiTheme(Tokens.dark).toThemeData(),
        themeMode: mode,
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
                  if (widget.daemon.chatShows) {
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
    ),
  );
}

class _Shell extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([daemon, sidebarHidden]),
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
      final shut = sidebarShut;
      // With the sidebar hidden the bars start at the window's left edge,
      // under the traffic lights, so their text starts past them.
      final barStart = shut ? lightsInset : 16.0;
      final app = LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!shut)
              Resizable(
                name: 'sidebar',
                initial: 260,
                min: 200,
                max: min(480, box.maxWidth - 560),
                child: Sidebar(daemon: daemon),
              ),
            // Beside the sidebar, clear of the traffic lights, or alone in
            // the window. Always a column, the view its last child: a bar
            // coming and going keeps the view's state. The row's last child
            // too, so the sidebar going keeps it as well.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // What has no header of its own still keeps the top's line.
                  // Always a child, so the banner under it keeps its state.
                  if (daemon.trustAsk != null ||
                      (daemon.place is ChatPlace && chat == null))
                    const PaneHeader(plain: true, child: SizedBox.shrink())
                  else
                    const SizedBox.shrink(),
                  DaemonBanner(daemon, start: barStart),
                  // Each slides down as it comes and up as it goes,
                  // saying what it said until it's gone.
                  BarSlide(
                    child: daemon.connected && daemon.updatesWhenIdle
                        ? DaemonUpdateBar(daemon, start: barStart)
                        : null,
                  ),
                  BarSlide(
                    child: daemon.connected && daemon.removedChats.isNotEmpty
                        ? RemovedChatsBar(daemon, start: barStart)
                        : null,
                  ),
                  BarSlide(
                    child: daemon.notice != null
                        ? NoticeBar(daemon, start: barStart)
                        : null,
                  ),
                  Expanded(
                    child: daemon.trustAsk != null
                        ? TrustCard(daemon.trustAsk!)
                        : switch (daemon.place) {
                            JiraPlace() => JiraView(daemon),
                            GitHubPlace() => GitHubView(daemon),
                            SettingsPlace() => SettingsView(daemon),
                            ChatPlace() when chat == null => NothingOpen(
                              daemon,
                            ),
                            ChatPlace() => _ChatPane(
                              key: ValueKey(chat!.id),
                              chat,
                              daemon,
                            ),
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A newer release's toast, in the bottom right corner.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: app),
                Positioned(
                  right: UpdateToast.inset,
                  bottom: UpdateToast.inset,
                  child: UpdateToast(daemon),
                ),
              ],
            ),
          ),
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
    // A chat opens on the tab it was left on (ChatState.tab), but on its
    // transcript when it needs you: what it asks is there.
    if (widget.chat.phase == ChatPhase.waiting) _tab.value = ChatTab.chat;
    widget.chat.addListener(_showFile);
    widget.chat.preview.addListener(_showPreview);
    widget.chat.showAsked.addListener(_showAsked);
    _tab.addListener(_showAsked);
    // After this frame: the panes beside the transcript aren't built yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showAsked();
    });
    _pull = ChatPull.of(widget.daemon, widget.chat)..follow();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_showFile);
    widget.chat.preview.removeListener(_showPreview);
    widget.chat.showAsked.removeListener(_showAsked);
    _tab.removeListener(_showAsked);
    _pull.unfollow();
    super.dispose();
  }

  /// A file's preview opened (from Artifacts, or ⌘P) shows beside the chat.
  void _showPreview() {
    if (widget.chat.preview.value != null) _tab.value = ChatTab.chat;
  }

  /// A file its agent asked to show opens while the transcript shows. This
  /// pane lives only while its chat is the one showing, so another chat or
  /// a view in its place leaves the ask waiting, and on Changes it waits
  /// too: the agent never moves the user (ADR 0068). In a window too narrow
  /// for the pane beside the transcript it stays closed, or it would lie
  /// over the box and any card waiting; the row's Preview opens it.
  void _showAsked() {
    final chat = widget.chat;
    final path = chat.showAsked.value;
    if (path == null || chat.shownTab != ChatTab.chat) return;
    chat.showAsked.value = null;
    if (chat.previewFits) chat.openPreview(path);
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
        widget.chat.previewFits =
            box.maxWidth -
                (panel ? paneWidth('details', DetailsPanel.width) : 0) -
                ChatView.previewWidth >=
            ChatView.leastBesideWide;
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
                            // It follows the chat it was made for.
                            key: ObjectKey(widget.chat),
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
