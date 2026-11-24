import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:nushi/alerts.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_area.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/checks_watch.dart';
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
import 'package:nushi/kept_notices.dart';
import 'package:nushi/key_choice.dart' show shortcutRecording;
import 'package:nushi/keys.dart' show menuShortcut;
import 'package:nushi/native.dart';
import 'package:nushi/native_linux.dart';
import 'package:nushi/native_macos.dart';
import 'package:nushi/native_windows.dart';
import 'package:nushi/nothing_open.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart' show baseName;
import 'package:nushi/remote.dart';
import 'package:nushi/remote_reset.dart';
import 'package:nushi/removed_chats.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_modal.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_beside.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/top_notices.dart';
import 'package:nushi/trust_card.dart';
import 'package:nushi/type_to_box.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/view_options.dart';
import 'package:nushi/widgets.dart' show ToastHost, confirm;

void main() => runZonedGuarded(() {
  WidgetsFlutterBinding.ensureInitialized();
  // The machine's native edge, the app's one test of the platform (ADR
  // 0097, 0104), before anything that may reach it.
  native = Platform.isLinux
      ? linuxNative()
      : Platform.isWindows
      ? windowsNative()
      : macosNative();
  // The Mac window's mouse repairs, logged (ADR 0080).
  if (Platform.isMacOS) logMouseRepairs();
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
  late final VoidCallback _unwatchPairings;

  @override
  void initState() {
    super.initState();
    _unwatchPairings = watchPairings(_navigator, widget.daemon.client);
    _alerts = ChatAlerts(widget.daemon);
    // A chat whose pull request's checks newly fail needs you (ADR 0138).
    ChecksWatch.of(widget.daemon).start();
    widget.daemon.addListener(_pinChanged);
    _followTab();
    sidebarHidden.addListener(_sidebarChanged);
    sidebarTucked.addListener(_sidebarTucked);
    // The Files pane's options' labels (view_options.dart).
    for (final p in _viewPrefs) {
      p.addListener(_sidebarChanged);
    }
    diffUnified.addListener(_sidebarChanged);
    shortcutKeys.addListener(_keysChanged);
    shortcutRecording.addListener(_recordingChanged);
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
  /// Unpin Chat then. Whether Back and Forward have somewhere to go:
  /// their View menu items are greyed out while they don't.
  bool _pinned = false;
  bool _back = false;
  bool _forward = false;

  /// View › Show/Hide File Tree as last built: it follows the shown chat
  /// and its tab ([_tabOf]), the daemon's tree and the prefs.
  String? _treeLabel;

  /// The chat whose tab the menu bar follows: the shown one.
  ChatState? _tabOf;

  /// Follows the shown chat's tab ([_tabOf]).
  void _followTab() {
    final shown = widget.daemon.selected;
    if (identical(shown, _tabOf)) return;
    _tabOf?.tab.removeListener(_pinChanged);
    _tabOf = shown?..tab.addListener(_pinChanged);
  }

  void _pinChanged() {
    final d = widget.daemon;
    _followTab();
    final pinned = (d.selected?.pin ?? 0) > 0;
    final back = d.canGoBack;
    final forward = d.canGoForward;
    final tree = viewMenuLabel(Act.fileTree, d.selected, d);
    if (pinned != _pinned ||
        back != _back ||
        forward != _forward ||
        tree != _treeLabel) {
      setState(() {
        _pinned = pinned;
        _back = back;
        _forward = forward;
        _treeLabel = tree;
      });
    }
  }

  /// The View menu's Hide Sidebar says Show Sidebar while it's hidden,
  /// Wrap Lines says Don’t Wrap Lines while they wrap, and Show Whitespace
  /// says Hide Whitespace while it shows.
  void _sidebarChanged() => setState(() {});

  /// The sidebar tucked away or back, as the window's layout decides: the
  /// menu bar's Show Sidebar follows after the frame, as it's set while
  /// what's under this is built.
  void _sidebarTucked() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() {});
  });

  @override
  void didUpdateWidget(NushiApp old) {
    super.didUpdateWidget(old);
    if (widget.daemon != old.daemon) {
      old.daemon.removeListener(_pinChanged);
      widget.daemon.addListener(_pinChanged);
      ChecksWatch.of(old.daemon).stop();
      ChecksWatch.of(widget.daemon).start();
      _window = _makeWindow();
    }
  }

  @override
  void dispose() {
    sidebarHidden.removeListener(_sidebarChanged);
    sidebarTucked.removeListener(_sidebarTucked);
    for (final p in _viewPrefs) {
      p.removeListener(_sidebarChanged);
    }
    diffUnified.removeListener(_sidebarChanged);
    shortcutKeys.removeListener(_keysChanged);
    shortcutRecording.removeListener(_recordingChanged);
    widget.daemon.removeListener(_pinChanged);
    _tabOf?.tab.removeListener(_pinChanged);
    _unwatchPairings();
    _alerts.dispose();
    ChecksWatch.of(widget.daemon).stop();
    _lifecycle.dispose();
    super.dispose();
  }

  /// The keys chosen in Settings changed: the menu bar's, and every
  /// label and tooltip that names a key, which read it as they build
  /// (ADR 0146).
  void _keysChanged() => _afterBuild(() {
    setState(() {});
    _rebuildAll();
  });

  /// Settings started or stopped taking a key: the menu bar's keys go or
  /// come back.
  void _recordingChanged() => _afterBuild(() => setState(() {}));

  /// [change] now, or after this frame when it comes mid-frame (a key
  /// field let go as Settings closes, while the tree is locked).
  void _afterBuild(VoidCallback change) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      change();
      return;
    }
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) change();
      })
      ..scheduleFrame();
  }

  /// Every widget built again, State kept: about twenty places name a key
  /// without a context to hear it change by, the kept [_window] and const
  /// widgets among them.
  void _rebuildAll() {
    void mark(Element e) {
      e
        ..markNeedsBuild()
        ..visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  /// What the View menu's Files options say follows: each option's pref,
  /// the tree's, and which chats have Files open.
  static final List<Listenable> _viewPrefs = [
    for (final o in viewToggles) o.pref,
    for (final c in viewChoices) c.pref,
    filesTree,
    filesChats,
  ];

  PlatformMenuItem _appearance(String label, ThemeMode mode) =>
      PlatformMenuItem(label: label, onSelected: () => appearance.value = mode);

  /// [act]'s item in the menu bar: its label and key; it runs as from
  /// the palette.
  PlatformMenuItem _item(Act act) => PlatformMenuItem(
    label: switch (act) {
      Act.pin when _pinned => 'Unpin Chat',
      Act.sidebar when sidebarShut => 'Show Sidebar',
      Act.unifiedDiff when diffUnified.value => 'Show Diffs Side by Side',
      _ =>
        viewMenuLabel(act, widget.daemon.selected, widget.daemon) ??
            act.menuLabel!,
    },
    shortcut: menuShortcut(act.key),
    onSelected: () => _run(act),
  );

  void _run(Act act) => runAct(_navigator.currentContext!, widget.daemon, act);

  List<PlatformMenuItem> _items(ActMenu menu) => [
    for (final a in Act.values)
      if (a.menu == menu)
        if (viewChoiceOf(a) case final choice?) _choice(choice) else _item(a),
  ];

  /// A Files option of a few values as a submenu, the value now disabled:
  /// the menu bar draws no checks.
  PlatformMenu _choice(ViewChoice<Object?> choice) => PlatformMenu(
    label: choice.viewLabel,
    menus: [
      for (final (value, name, _, _) in choice.values)
        PlatformMenuItem(
          label: name,
          onSelected: choice.pref.value == value
              ? null
              : () => choice.pref.value = value,
        ),
    ],
  );

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
          shortcut: menuShortcut(paletteKey),
          onSelected: () =>
              unawaited(showPalette(_navigator.currentContext!, widget.daemon)),
        ),
        PlatformMenuItemGroup(members: _items(ActMenu.view)),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Back',
              shortcut: menuShortcut(backKey),
              onSelected: _back ? () => _run(Act.back) : null,
            ),
            PlatformMenuItem(
              label: 'Forward',
              shortcut: menuShortcut(forwardKey),
              onSelected: _forward ? () => _run(Act.forward) : null,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Previous Chat',
              shortcut: menuShortcut(previousChatKey),
              onSelected: () => stepChat(widget.daemon, -1),
            ),
            PlatformMenuItem(
              label: 'Next Chat',
              shortcut: menuShortcut(nextChatKey),
              onSelected: () => stepChat(widget.daemon, 1),
            ),
            // Hold ⌘ to see the numbers in the sidebar.
            PlatformMenu(
              label: 'Open Chat',
              menus: [
                for (var n = 1; n <= 9; n++)
                  PlatformMenuItem(
                    label: 'Chat $n in the Sidebar',
                    shortcut: menuShortcut(chatNumberKey(n)),
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
  /// the theme the palette (ADR 0086), the fonts the families (ADR 0114);
  /// a change to any, or to the theme's file, repaints.
  late Widget _window = _makeWindow();

  /// The picked theme's set for [brightness], in the picked fonts (ADR
  /// 0114).
  ThemeData _theme(Brightness brightness) => NushiTheme.forTheme(
    pickedTheme(),
    brightness,
    ui: appFont.value,
    code: codeFont.value,
  );

  Widget _makeWindow() => ListenableBuilder(
    listenable: Listenable.merge([
      appearance,
      colorTheme,
      themeFiles,
      appFont,
      codeFont,
    ]),
    builder: (context, home) => MaterialApp(
      navigatorKey: _navigator,
      title: 'Nushi',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: appearance.value,
      // Light and dark switch at once (NushiTheme.lerp), so no frames of a
      // theme animation, each a rebuild of what reads the theme.
      themeAnimationDuration: Duration.zero,
      scrollBehavior: const NativeScroll(),
      // The toasts, over every view, Settings and a dialog (ADR 0128).
      // A kept file that couldn't be read says so there, once.
      builder: (context, child) => ToastHost(child: KeptNotices(child: child!)),
      // The menu's keys don't reach the menu while Flutter has the keys:
      // they're bound here too, and a terminal, which keeps ⌘ and ⌃ keys,
      // passes them on as the same intents.
      home: Builder(
        builder: (context) => Actions(
          actions: {
            RunActIntent: _RunAct((act) => runAct(context, widget.daemon, act)),
            OpenChatIntent: CallbackAction<OpenChatIntent>(
              onInvoke: (i) => openNthChat(widget.daemon, i.n),
            ),
            StepChatIntent: CallbackAction<StepChatIntent>(
              onInvoke: (i) => stepChat(widget.daemon, i.step),
            ),
          },
          // The actions' keys, ⌘K, ⌘1–⌘9, ⌥⌘↑ and ⌥⌘↓, ⌃Tab and ⌃⇧Tab:
          // wherever the focus is; and Quit's without a menu bar.
          child: Shortcuts(
            shortcuts: {
              ...appKeys,
              if (!native.window.menuBar) quitKey: const RunActIntent(.quit),
            },
            // A scope under these keys: a text field a click outside lets
            // go of (the framework's unfocus on the desktop) gives the focus
            // to its scope, and the route's, above them, heard none of them.
            // A character typed with the focus on it, or on the Focus in it,
            // or on the transcript, goes into the chat's box (ADR 0121).
            child: FocusScope(
              onKeyEvent: (node, e) => typeIntoBox(widget.daemon, node, e),
              // Focused when nothing in the window is, so the keys still
              // come here (an empty pane, after a click on the sidebar).
              child: Focus(
                autofocus: true,
                onKeyEvent: (node, e) => typeIntoBox(widget.daemon, node, e),
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

  /// The bars in their row under the main view's header: one element
  /// wherever they're put (in a chat's pane or under another view's
  /// header), so a bar keeps its state, and its slide, as the view changes.
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
    // Below the floor, or with no way to restart by itself: nothing else
    // until it has (ADR 0004). The pings keep asking it to restart once
    // idle meanwhile, so the screen clears by itself.
    if (daemon.blocked) {
      return TitleBand(child: OutdatedScreen(daemon));
    }
    final chat = daemon.selected;
    // The bars take a row of their own under the header (ADR 0128,
    // amended 2026-11-17): they stay for minutes, so they push the view
    // down rather than lie over its first lines. Always a column of the
    // same children: one coming and going keeps the others' state.
    final bars = Column(
      key: _bars,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DaemonBanner(daemon),
        // Each slides down as it comes and up as it goes,
        // saying what it said until it's gone.
        BarSlide(
          child: daemon.connected && daemon.updatesWhenIdle
              ? DaemonUpdateBar(daemon)
              : null,
        ),
        BarSlide(
          child: daemon.connected && daemon.removedChats.isNotEmpty
              ? RemovedChatsBar(daemon)
              : null,
        ),
        BarSlide(child: daemon.notice != null ? NoticeBar(daemon) : null),
      ],
    );
    // A view in the main pane. What has no header of its own still keeps
    // the top's line.
    Widget pane(Widget view, {bool header = false}) => Pane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header) ...[
            const PaneHeader(plain: true, child: SizedBox.shrink()),
            const BarsRow(),
          ],
          Expanded(child: view),
        ],
      ),
    );
    // Made here, outside the layout's builder, as the bars are: a new
    // layout (the window resized) leaves it as it was.
    final card = UpdateToast(daemon);
    final inChat =
        daemon.trustAsk == null && daemon.place is ChatPlace && chat != null;
    final app = LayoutBuilder(
      // The sidebar slides in and out over the view, which keeps its
      // state either way.
      builder: (context, box) {
        // A window too narrow for a chat beside the sidebar tucks it away
        // (never saved). Set before what's under it reads it as it's laid
        // out; its listeners are under it too, but for the app's menu
        // bar, which hears it after the frame.
        sidebarTucked.value =
            !sidebarHidden.value && sidebarTucksIn(box.maxWidth);
        final shut = sidebarShut;
        return SidebarBeside(
          daemon: daemon,
          shut: shut,
          // Shown, or floating over the view while it's hidden and peeks.
          sidebar: ({required floating}) => ListenableBuilder(
            listenable: Listenable.merge([projectRail, sidebarGroupBy]),
            builder: (context, child) => Resizable(
              name: 'sidebar',
              initial: sidebarInitial,
              min: sidebarLeast(box.maxWidth),
              max: sidebarMost(box.maxWidth),
              line: false,
              child: child!,
            ),
            child: Sidebar(daemon: daemon, floating: floating),
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        // A view but a chat puts the bars under its header.
                        child: TopBars(
                          bars: inChat ? null : bars,
                          child: daemon.trustAsk != null
                              ? pane(TrustCard(daemon.trustAsk!), header: true)
                              : switch (daemon.place) {
                                  JiraPlace() => pane(JiraView(daemon)),
                                  GitHubPlace() => pane(GitHubView(daemon)),
                                  ChatPlace() when chat == null => pane(
                                    NothingOpen(daemon),
                                    header: true,
                                  ),
                                  ChatPlace() => ChatArea(
                                    key: ValueKey(chat!.id),
                                    chat,
                                    daemon,
                                    notices: (bars: bars, card: card),
                                  ),
                                },
                        ),
                      ),
                      // The newer release's card; the bars and the toasts are
                      // under the view's header ([BarsRow]). A chat places
                      // all three itself (ADR 0128).
                      if (!inChat)
                        Positioned.fill(child: TopNotices(card: card)),
                    ],
                  ),
                ),
              ),
              // The window's margin, the same with the sidebar hidden: the
              // pane keeps its height as the sidebar comes and goes.
              const SizedBox(height: NushiTheme.windowPad),
            ],
          ),
        );
      },
    );
    // Settings opens over all of it (ADR 0087). A remote access reset is
    // said once as a toast (RemoteResetToast).
    return RemoteResetToast(
      daemon,
      child: SettingsModal(
        daemon: daemon,
        open: daemon.settingsOpen != null,
        app: app,
      ),
    );
  }
}

/// Runs an action from its key, unless the key is a text field's own
/// there ([actKeyTaken]): then it isn't handled, and goes on to the field.
class _RunAct extends Action<RunActIntent> {
  new(this._run);

  final void Function(Act act) _run;

  @override
  bool isEnabled(RunActIntent intent) => !actKeyTaken(intent.act);

  @override
  Object? invoke(RunActIntent intent) {
    _run(intent.act);
    return null;
  }
}
