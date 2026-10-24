import 'dart:math';

import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'chat.dart';
import 'chat_header.dart';
import 'chat_view.dart';
import 'daemon.dart';
import 'details_panel.dart';
import 'folder_button.dart';
import 'mcp.dart';
import 'panes.dart';
import 'settings.dart';
import 'settings_dialog.dart';
import 'sidebar.dart';
import 'terminal_panel.dart';
import 'theme/theme.dart';
import 'trust_card.dart';
import 'widgets.dart';

void main() => runApp(NushiApp(daemon: Daemon()));

class NushiApp extends StatefulWidget {
  const NushiApp({super.key, required this.daemon});

  final Daemon daemon;

  @override
  State<NushiApp> createState() => _NushiAppState();
}

class _NushiAppState extends State<NushiApp> {
  var _mode = ThemeMode.system;
  final _navigator = GlobalKey<NavigatorState>();

  PlatformMenuItem _appearance(String label, ThemeMode mode) =>
      PlatformMenuItem(
        label: label,
        onSelected: () => setState(() => _mode = mode),
      );

  @override
  Widget build(BuildContext context) => PlatformMenuBar(
    menus: [
      PlatformMenu(
        label: 'Nushi',
        menus: [
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
          PlatformMenuItem(
            label: 'Settings…',
            shortcut: settingsKey,
            onSelected: () => showSettings(_navigator.currentContext!),
          ),
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: [
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
      // The menu's ⌘, doesn't reach the menu while Flutter has the keys.
      home: Builder(
        builder: (context) => CallbackShortcuts(
          bindings: {settingsKey: () => showSettings(context)},
          child: Scaffold(body: _Shell(widget.daemon)),
        ),
      ),
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell(this.daemon);

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
      if (daemon.outdated) return _Outdated(daemon);
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
                  : daemon.mcpFolder != null
                  ? McpView(daemon: daemon, folder: daemon.mcpFolder!)
                  : chat == null
                  ? Center(
                      child: Text(
                        'Start a chat',
                        style: theme.ui(theme.t.textMuted),
                      ),
                    )
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
                'Lost the connection to the daemon; reconnecting…',
                style: theme.ui(theme.t.needs, size: 12),
              ),
            ),
          if (daemon.connected && daemon.replaced) _Replaced(daemon),
          Expanded(child: app),
        ],
      );
    },
  );
}

/// A chat under its header, with a switch between its transcript and its
/// folder's changes.
class _ChatPane extends StatefulWidget {
  const _ChatPane(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  bool _changes = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ValueListenableBuilder(
      valueListenable: showDetails,
      builder: (context, show, _) {
        // The panel goes when the chat would get too narrow.
        final fits =
            box.maxWidth >=
            paneWidth('details', DetailsPanel.width) + ChatView.minWidth;
        final panel = show && fits && !_changes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: widget.chat,
              builder: (context, _) => ChatHeader(
                widget.chat,
                widget.daemon,
                changes: _changes,
                onChanges: (v) => setState(() => _changes = v),
                panel: panel,
                onPanel: fits && !_changes
                    ? () => showDetails.value = !show
                    : null,
              ),
            ),
            Expanded(
              child: TerminalArea(
                chat: widget.chat,
                daemon: widget.daemon,
                onChanges: () => setState(() => _changes = true),
                child: _changes
                    ? ChangesView(chat: widget.chat, daemon: widget.daemon)
                    : ChatView(
                        chat: widget.chat,
                        daemon: widget.daemon,
                        details: panel
                            ? DetailsPanel(
                                chat: widget.chat,
                                daemon: widget.daemon,
                                onChanges: () =>
                                    setState(() => _changes = true),
                              )
                            : null,
                      ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Says a newer daemon was installed since the running one started (same
/// API), with a way to restart into it.
class _Replaced extends StatefulWidget {
  const _Replaced(this.daemon);

  final Daemon daemon;

  @override
  State<_Replaced> createState() => _ReplacedState();
}

class _ReplacedState extends State<_Replaced> {
  bool _restarting = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Container(
      color: t.raised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Text(
              'A newer daemon is installed. Restarting stops running turns '
              'and closes terminals.',
              style: theme.ui(t.textSecondary, size: 12),
            ),
          ),
          Button(
            label: _restarting ? 'Restarting…' : 'Restart daemon',
            kind: ButtonKind.ghost,
            height: 24,
            onPressed: _restarting
                ? null
                : () async {
                    setState(() => _restarting = true);
                    await tryOrShow(context, widget.daemon.restartDaemon);
                    if (mounted) setState(() => _restarting = false);
                  },
          ),
        ],
      ),
    );
  }
}

/// Says the daemon is older than the app, with a way to restart it: the app
/// shows nothing else until it has.
class _Outdated extends StatefulWidget {
  const _Outdated(this.daemon);

  final Daemon daemon;

  @override
  State<_Outdated> createState() => _OutdatedState();
}

class _OutdatedState extends State<_Outdated> {
  bool _restarting = false;

  Future<void> _restart() async {
    setState(() => _restarting = true);
    await tryOrShow(context, widget.daemon.restartDaemon);
    if (mounted) setState(() => _restarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The daemon is older than this app. Restarting it stops '
              'running turns and closes terminals; chats reopen as you open '
              'them.',
              textAlign: TextAlign.center,
              style: theme.ui(t.textSecondary),
            ),
            const SizedBox(height: 14),
            if (bundledDaemon != null)
              Button(
                label: _restarting ? 'Restarting…' : 'Restart daemon',
                kind: ButtonKind.primary,
                onPressed: _restarting ? null : _restart,
              )
            else
              Text('make stop daemon', style: theme.code(t.textMuted)),
          ],
        ),
      ),
    );
  }
}
