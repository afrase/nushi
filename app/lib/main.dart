import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'package:nushi/alerts.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/chat_area.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/comment_drafts_mac.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/drafts_mac.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/images.dart' show limitImageCache;
import 'package:nushi/jira_view.dart';
import 'package:nushi/native.dart';
import 'package:nushi/native_linux.dart';
import 'package:nushi/native_macos.dart';
import 'package:nushi/nothing_open.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart' show baseName;
import 'package:nushi/remote.dart';
import 'package:nushi/removed_chats.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_modal.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/trust_card.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/widgets.dart' show confirm;

void main() => runZonedGuarded(() {
  WidgetsFlutterBinding.ensureInitialized();
  // The machine's native edge, the app's one test of the platform (ADR
  // 0097, 0104), before anything that may reach it.
  native = Platform.isLinux ? linuxNative() : macosNative();
  limitImageCache();
  catchErrors();
  themeFiles
    ..load()
    ..watch();
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
  late final ChatAlerts _alerts;

  @override
  void initState() {
    super.initState();
    watchPairings(_navigator, widget.daemon.client);
    _alerts = ChatAlerts(widget.daemon);
    widget.daemon.addListener(_pinChanged);
    sidebarHidden.addListener(_sidebarChanged);
    wrapLines.addListener(_sidebarChanged);
    showWhitespace.addListener(_sidebarChanged);
    diffUnified.addListener(_sidebarChanged);
    // The app coming to the front shows its chat again; the daemon knows
    // whether the window shows (focused or not) or is hidden, and the
    // notifications whether it's in front. Drafts are saved at once when
    // the app goes to the back or quits.
    final drafts = widget.daemon.drafts;
    final comments = widget.commentDrafts;
    // The window going to the back saves the files being edited too
    // (ADR 0096).
    void saveDrafts() {
      comments?.flush();
      unawaited(drafts?.flush());
      unawaited(saveEdits(widget.daemon));
    }

    _lifecycle = AppLifecycleListener(
      onResume: widget.daemon.shown,
      onInactive: saveDrafts,
      onHide: saveDrafts,
      onExitRequested: () async {
        if (!await _editsSaved()) return AppExitResponse.cancel;
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

  /// Saves the files being edited before the app quits: true when it may
  /// quit, every edit saved, or those that couldn't be, discarded after
  /// asking (ADR 0096).
  Future<bool> _editsSaved() async {
    await saveEdits(widget.daemon)
        .timeout(const Duration(seconds: 3), onTimeout: () => []);
    // Those a save left unsaved, or that a save still waits on.
    final left = [
      for (final c in widget.daemon.chats.values)
        ...c.edits.values.where((e) => e.unsaved),
    ];
    final context = _navigator.currentContext;
    if (left.isEmpty || context == null || !context.mounted) return true;
    final names = left.map((e) => plainPath(baseName(e.path))).join(', ');
    return await confirm(
      context,
      left.length == 1
          ? 'Quit without your changes to $names?'
          : 'Quit without your changes to ${left.length} files?',
      left.length == 1
          ? 'They couldn’t be saved: the file changed on disk, went, or '
                'can’t be written.'
          : '$names couldn’t be saved: each changed on disk, went, or '
                'can’t be written.',
      'Quit',
      destructive: true,
    );
  }

  /// Whether the shown chat is pinned: the Chat menu's Pin Chat says
  /// Unpin Chat then.
  bool _pinned = false;

  void _pinChanged() {
    final pinned = (widget.daemon.selected?.pin ?? 0) > 0;
    if (pinned != _pinned) setState(() => _pinned = pinned);
  }

  /// The View menu's Hide Sidebar says Show Sidebar while it's hidden,
  /// Wrap Lines says Don’t Wrap Lines while they wrap, and Show Whitespace
  /// says Hide Whitespace while it shows.
  void _sidebarChanged() => setState(() {});

  @override
  void didUpdateWidget(NushiApp old) {
    super.didUpdateWidget(old);
    if (widget.daemon != old.daemon) {
      old.daemon.removeListener(_pinChanged);
      widget.daemon.addListener(_pinChanged);
      _window = _makeWindow();
    }
  }

  @override
  void dispose() {
    sidebarHidden.removeListener(_sidebarChanged);
    wrapLines.removeListener(_sidebarChanged);
    showWhitespace.removeListener(_sidebarChanged);
    diffUnified.removeListener(_sidebarChanged);
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
      Act.wrap when wrapLines.value => 'Don’t Wrap Lines',
      Act.whitespace when showWhitespace.value => 'Hide Whitespace',
      Act.unifiedDiff when diffUnified.value => 'Show Diffs Side by Side',
      _ => act.menuLabel!,
    },
    shortcut: act.key,
    onSelected: () => runAct(_navigator.currentContext!, widget.daemon, act),
  );

  List<PlatformMenuItem> _items(ActMenu menu) => [
    for (final a in Act.values)
      if (a.menu == menu) _item(a),
  ];

  /// The window, under the system's menu bar where there's one: the
  /// actions' keys work without it (the Shortcuts in [_makeWindow]).
  @override
  Widget build(BuildContext context) => native.window.menuBar
      ? PlatformMenuBar(menus: _menus, child: _window)
      : _window;

  List<PlatformMenuItem> get _menus => [
    PlatformMenu(
      label: 'Nushi',
      menus: [
        const PlatformProvidedMenuItem(
          type: PlatformProvidedMenuItemType.about,
        ),
        ..._items(ActMenu.nushi),
        const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
        const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
      ],
    ),
    PlatformMenu(label: 'File', menus: _items(ActMenu.file)),
    PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItem(
          label: 'Command Palette…',
          shortcut: paletteKey,
          onSelected: () =>
              unawaited(showPalette(_navigator.currentContext!, widget.daemon)),
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
  ];

  /// The window below the menu bar, made again only for a new daemon: a
  /// menu label's change (the sidebar shown or hidden, the chat pinned)
  /// rebuilds the menus alone. The appearance picks the light or dark set,
  /// the theme the palette (ADR 0086); a change to either, or to the
  /// theme's file, repaints.
  late Widget _window = _makeWindow();

  Widget _makeWindow() => ListenableBuilder(
    listenable: Listenable.merge([appearance, colorTheme, themeFiles]),
    builder: (context, home) => MaterialApp(
      navigatorKey: _navigator,
      title: 'Nushi',
      debugShowCheckedModeBanner: false,
      theme: NushiTheme.forTheme(pickedTheme(), Brightness.light),
      darkTheme: NushiTheme.forTheme(pickedTheme(), Brightness.dark),
      themeMode: appearance.value,
      // Light and dark switch at once (NushiTheme.lerp), so no frames of a
      // theme animation, each a rebuild of what reads the theme.
      themeAnimationDuration: Duration.zero,
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
          // wherever the focus is; and Quit's without a menu bar.
          child: Shortcuts(
            shortcuts: {
              ...actKeys,
              paletteKey: const OpenPaletteIntent(),
              paletteKeyToo: const OpenPaletteIntent(),
              ...chatKeys,
              if (!native.window.menuBar) quitKey: const RunActIntent(.quit),
            },
            // Focused when nothing in the window is, so the keys still
            // come here (an empty pane, after a click on the sidebar).
            child: Focus(
              autofocus: true,
              child: Scaffold(
                // The Scaffold's text style blends to a new theme's over
                // 200 ms, rebuilding every text below on each frame;
                // this one switches at once, with the theme.
                body: Material(
                  type: MaterialType.transparency,
                  animationDuration: Duration.zero,
                  child: _Shell(widget.daemon),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The window (ADR 0111): its own background, the sidebar straight on it
/// at the left, and beside it the main area as a pane that floats
/// [NushiTheme.windowPad] in from the window's edges. A chat puts its
/// details beside its pane, as cards of their own ([ChatArea]). With the
/// sidebar hidden the pane reaches the left edge, its header starting past
/// the traffic lights, and what the sidebar's foot said (the agents'
/// counts, the memory) is a line under the pane.
class _Shell extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  /// The bars over the main view: one element wherever they're put (in a
  /// chat's pane or another view's), so a bar keeps its state, and its
  /// slide, as the view under it changes.
  static final GlobalKey _bars = GlobalKey();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([daemon, sidebarHidden]),
    builder: (context, _) => ColoredBox(
      color: NushiTheme.of(context).t.window,
      child: _window(context),
    ),
  );

  Widget _window(BuildContext context) {
    final theme = NushiTheme.of(context);
    // Never connected yet: nothing to show. Once it was, a lost
    // connection is a banner over the app, which keeps what's open.
    // Neither has a header: a band moves the window.
    if (!daemon.connected && daemon.daemonApi == 0) {
      return TitleBand(
        child: Center(
          child: Text(
            native.install.daemon == null
                ? 'Daemon not running'
                : daemon.launchFailed
                ? "Couldn't start the daemon. Its log: "
                      '${tildePath('$dataDir/nushid.log')}'
                : 'Starting the daemon…',
            style: theme.ui(theme.t.textSecondary),
          ),
        ),
      );
    }
    if (daemon.outdated && !daemon.updatesWhenIdle) {
      return TitleBand(child: OutdatedScreen(daemon));
    }
    final chat = daemon.selected;
    final shut = sidebarShut;
    // With the sidebar hidden the bars start at the window's left edge,
    // under the traffic lights, so their text starts past them; with
    // nothing over the content there (Linux), at their own margin.
    final barStart = shut ? max(lightsInset, 16.0) : 16.0;
    // The bars at the pane's top, over the view's own header. Always a
    // column of the same children: a bar coming and going keeps the
    // others' state.
    final bars = Column(
      key: _bars,
      mainAxisSize: MainAxisSize.min,
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
      ],
    );
    // A view under the bars, in the main pane. The view is always the
    // column's last child, so a bar coming and going keeps its state.
    Widget pane(Widget view) => Pane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bars,
          Expanded(child: view),
        ],
      ),
    );
    final app = LayoutBuilder(
      // The sidebar slides in and out over the view, which keeps its
      // state either way.
      builder: (context, box) => SidebarBeside(
        sidebar: shut
            ? null
            : Resizable(
                name: 'sidebar',
                initial: 260,
                min: 200,
                max: min(480, box.maxWidth - 560),
                line: false,
                child: Sidebar(daemon: daemon),
              ),
        // Beside the sidebar, which brings the gap between them, or alone
        // in the window, in from its left edge too.
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WindowEdge(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: shut ? NushiTheme.windowPad : 0,
                  right: NushiTheme.windowPad,
                ),
                child: daemon.trustAsk != null
                    ? pane(TrustCard(daemon.trustAsk!))
                    : switch (daemon.place) {
                        JiraPlace() => pane(JiraView(daemon)),
                        GitHubPlace() => pane(GitHubView(daemon)),
                        ChatPlace() when chat == null => pane(
                          NothingOpen(daemon),
                        ),
                        // Its pane has the bars too, its details beside it.
                        ChatPlace() => ChatArea(
                          key: ValueKey(chat!.id),
                          chat,
                          daemon,
                          top: bars,
                        ),
                      },
              ),
            ),
            // Under the pane what the hidden sidebar's foot said, or the
            // window's own margin.
            if (shut)
              StatusBar(daemon)
            else
              const SizedBox(height: NushiTheme.windowPad),
          ],
        ),
      ),
    );
    // Settings opens over all of it (ADR 0087). A newer release's toast,
    // in the bottom right corner.
    return SettingsModal(
      daemon: daemon,
      open: daemon.settingsOpen != null,
      app: Stack(
        children: [
          Positioned.fill(child: app),
          Positioned(
            right: UpdateToast.inset,
            // Clear of the line under the pane, while that shows.
            bottom:
                UpdateToast.inset +
                (shut ? StatusBar.lineHeight - NushiTheme.windowPad : 0),
            child: UpdateToast(daemon),
          ),
        ],
      ),
    );
  }
}
