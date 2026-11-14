import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/dev_servers.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;

// The Servers menu (ADR 0098), as Claude desktop's: a browser tab's title
// row's button, left of its ⋯, that lists the chat's folder's dev servers,
// each run or stopped from its row, and Add server, which asks the agent
// to write the launch file.

/// What Add server puts in the chat's box, for the user to send.
const addServerDraft =
    "Detect this project's dev servers and write them to .agents/launch.json "
    "in Claude's launch.json format (name, runtimeExecutable, runtimeArgs, "
    "port). Don't start them.";

/// What the menu says with no entries.
const noServers = 'No servers in .agents/launch.json or .claude/launch.json';

/// The Servers button: its menu lists [chat]'s folder's servers, read as
/// it opens and again as the daemon says they changed. Only on the Mac,
/// and only a daemon that runs them (API 109).
class ServersButton extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    super.key,
    this.size = 18,
    this.padding = 5,
    this.collapse,
  });

  final ChatState chat;
  final Daemon daemon;

  /// Collapses the pane when it's expanded over the chat, so Add server's
  /// text shows in the box; null when it isn't.
  final VoidCallback? collapse;

  /// Its glyph's size and the room around it ([IconTap]'s).
  final double size;
  final double padding;

  @override
  State<ServersButton> createState() => _ServersButtonState();
}

class _ServersButtonState extends State<ServersButton> {
  DevServers get _servers => widget.daemon.devServers;

  bool get _here =>
      !widget.daemon.remote && widget.daemon.daemonApi >= serversApi;

  @override
  void initState() {
    super.initState();
    if (_here) _servers.load(widget.chat.id).ignore();
  }

  @override
  Widget build(BuildContext context) {
    if (!_here) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _servers,
      // Under the button, ending under its right edge, as Claude's does.
      builder: (context, _) => TrailingMenus(
        child: MenuIcon.line(
          LineIcon.server,
          tooltip: 'Servers',
          size: widget.size,
          padding: widget.padding,
          color: NushiTheme.of(context).t.text,
          filter: false,
          heldOpen: true,
          onOpen: () => _servers.look(widget.chat.id).ignore(),
          entries: serverEntries(
            widget.chat,
            _servers,
            collapse: widget.collapse,
          ),
        ),
      ),
    );
  }
}

/// The Servers menu's rows for [chat]: its servers, Stop all servers when
/// more than one runs, and Add server, which first runs [collapse] (the
/// pane expanded over the chat hides its box).
List<MenuEntry> serverEntries(
  ChatState chat,
  DevServers servers, {
  VoidCallback? collapse,
}) {
  final list = servers.of(chat.id);
  final error = servers.errorOf(chat.id);
  final rows = list?.servers ?? const <DevServer>[];
  final broken = [
    for (final f in list?.files ?? const <LaunchFile>[])
      if (f.error.isNotEmpty) f,
  ];
  final running = rows.where(DevServers.runs).length;
  final addWhy = chat.scratch || chat.folder.isEmpty
      ? 'This chat has no folder'
      : chat.archived
      ? 'The chat is archived'
      : chat.sessionGone
      ? 'The chat can’t take a message'
      : null;
  return [
    const MenuEntry.heading('Servers'),
    if (error != null)
      MenuEntry.row((_) => _Note(error, danger: true))
    else if (list == null)
      MenuEntry.row((_) => const _Note('Reading the launch files…'))
    else ...[
      for (final why in servers.refusedGone(chat.id))
        MenuEntry.row((_) => _Note(why, danger: true)),
      for (final f in broken)
        MenuEntry.row(
          (_) => _Note(
            '${f.fromMain ? 'The main checkout’s ' : ''}${f.path}: ${f.error}',
            danger: true,
          ),
        ),
      if (rows.isEmpty && broken.isEmpty)
        MenuEntry.row((_) => const _Note(noServers)),
      for (final s in rows)
        MenuEntry.row(
          (close) =>
              ServerRow(server: s, chat: chat, servers: servers, close: close),
        ),
    ],
    if (running > 1)
      MenuEntry(
        'Stop all servers',
        onPick: () => servers.stopAll(chat.id).ignore(),
      ),
    MenuEntry.divider,
    MenuEntry(
      'Add server',
      tooltip: addWhy ?? '',
      onPick: addWhy != null
          ? null
          : () {
              collapse?.call();
              chat.draft.put.value = addServerDraft;
            },
    ),
  ];
}

/// The width of a server's row's text.
const double _rowWidth = 260;

/// A muted line in the menu, in place of rows.
class _Note extends StatelessWidget {
  const new(this.text, {this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _rowWidth + 90),
        child: Text(
          plainPath(text),
          style: theme.ui(danger ? t.crashed : t.textMuted, size: 12.5),
        ),
      ),
    );
  }
}

/// One server's row: its name (a click opens its page beside the chat
/// while it runs), under it a muted line (its command, or why it can't run,
/// failed or isn't answering), and at the end Logs while it has output
/// (ADR 0100), then ▶ (Run), ■ (Stop) or a spinner while it starts. Its
/// tooltip has the whole command, its folder and env, or a failure's last
/// lines.
class ServerRow extends StatelessWidget {
  const new({
    required this.server,
    required this.chat,
    required this.servers,
    required this.close,
    super.key,
  });

  final DevServer server;
  final ChatState chat;
  final DevServers servers;
  final VoidCallback close;

  bool get _runs => DevServers.runs(server);

  /// Opens the server's page beside the chat.
  void _open() {
    close();
    chat.showServer(server.url);
  }

  /// Opens its logs drawer at the bottom of the browser pane.
  void _logs() {
    close();
    chat.serverLogs.value = (
      name: server.name,
      source: server.source,
      fromMain: server.fromMain,
    );
  }

  /// Runs it; its page opens once it answers (the user started it, so
  /// ADR 0068's "the agent never moves the user" doesn't hold it back).
  void _run() =>
      servers.start(chat.id, server, onReady: chat.showServer).ignore();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final s = server;
    final runnable = s.problem.isEmpty && !s.attach && s.index >= 0;
    final opens =
        s.url.isNotEmpty &&
        (s.attach ||
            s.state == DevServerState.DEV_SERVER_STATE_RUNNING ||
            s.state == DevServerState.DEV_SERVER_STATE_NOT_ANSWERING);
    final failed = s.state == DevServerState.DEV_SERVER_STATE_FAILED;
    final refused = s.state == DevServerState.DEV_SERVER_STATE_STOPPED
        ? servers.refusedOf(chat.id, s)
        : null;
    final (line, lineColor) = switch (s.state) {
      _ when s.problem.isNotEmpty => (s.problem, t.crashed),
      _ when refused != null => (refused, t.crashed),
      DevServerState.DEV_SERVER_STATE_FAILED => (s.error, t.crashed),
      DevServerState.DEV_SERVER_STATE_NOT_ANSWERING => (
        'Not answering on port ${s.port}',
        t.needs,
      ),
      DevServerState.DEV_SERVER_STATE_RUNNING when s.changed => (
        'Changed: restart to apply',
        t.textMuted,
      ),
      _ when s.attach => (s.url, t.textMuted),
      _ => (_command(s), t.textMuted),
    };
    final hint = [
      if (s.fromMain) 'main checkout',
      if (s.source == '.claude/launch.json') '.claude',
    ].join(', ');
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Flexible(
          child: Text(
            plainPath(s.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(
              runnable || s.attach ? t.text : t.textMuted,
              size: 13.5,
              weight: FontWeight.w400,
            ),
          ),
        ),
        if (hint.isNotEmpty)
          Text(hint, style: theme.ui(t.textMuted, size: 11.5)),
        if (!s.nameOk) const _NameMark(),
      ],
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 1,
      children: [
        if (opens)
          Pressable(
            onTap: _open,
            tooltip: 'Open ${s.url}',
            builder: (context, look) => DecoratedBox(
              decoration: BoxDecoration(
                color: look.hover ? t.hover : null,
                borderRadius: BorderRadius.circular(NushiTheme.control),
              ),
              child: name,
            ),
          )
        else
          name,
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Flexible(
              child: Text(
                plainPath(line),
                // Why it failed or can't run reads whole, in two lines.
                maxLines: lineColor == t.textMuted ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.code(lineColor, size: 11.5),
              ),
            ),
            for (final k in s.flaggedEnv)
              Text(k, style: theme.code(t.needs, size: 11.5)),
          ],
        ),
      ],
    );
    final logs = s.logId.isNotEmpty;
    // design: a server's output, in code type, which tooltip() doesn't set.
    return Tooltip(
      message: failed && s.output.isNotEmpty
          ? [_tail(s.output), if (logs) _seeLogs].join('\n\n')
          : _details(s),
      waitDuration: const Duration(milliseconds: 600),
      textStyle: theme.code(t.text, size: 11.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            SizedBox(width: _rowWidth, child: text),
            // In a box of one width, so each row's ▶ lines up.
            SizedBox(
              width: 50,
              // A menu's row: compact (ADR 0122).
              child: logs
                  ? ControlScale.compact(
                      child: Button(
                        label: 'Logs',
                        tooltip: 'Show its output below the page',
                        onPressed: _logs,
                      ),
                    )
                  : null,
            ),
            _button(context),
          ],
        ),
      ),
    );
  }

  /// ▶, ■ or the spinner, in a box of one size.
  Widget _button(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final s = server;
    if (s.state == DevServerState.DEV_SERVER_STATE_STARTING) {
      return IconTap.working(
        (size, color) => SizedBox.square(
          dimension: size,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Spinner(color: color),
          ),
        ),
        Icons.stop_rounded,
        tooltip: 'Stop',
        size: 18,
        padding: 6,
        color: t.text,
        onTap: () => servers.stop(chat.id, s.serverId).ignore(),
      );
    }
    if (_runs) {
      return IconTap(
        Icons.stop_rounded,
        tooltip: 'Stop',
        size: 18,
        padding: 6,
        danger: true,
        onTap: () => servers.stop(chat.id, s.serverId).ignore(),
      );
    }
    final runnable = s.problem.isEmpty && !s.attach && s.index >= 0;
    if (!runnable) return const SizedBox.square(dimension: 30);
    return IconTap.line(
      LineIcon.play,
      tooltip: s.state == DevServerState.DEV_SERVER_STATE_FAILED
          ? 'Run again'
          : 'Run',
      size: 18,
      padding: 6,
      color: t.text,
      held: true,
      onTap: _run,
    );
  }
}

/// What ends a failed server's tooltip: where the rest of its output is.
const _seeLogs = 'The whole output is in Logs.';

/// How many of a failed server's last lines its tooltip shows: the end,
/// where the error is, in a tooltip no taller than the window.
const _tailLines = 18;

/// The last [_tailLines] of [output], each as the menu shows text.
String _tail(String output) {
  final lines = output.split('\n');
  return lines
      .skip(lines.length > _tailLines ? lines.length - _tailLines : 0)
      .map(plainPath)
      .join('\n');
}

/// [s]'s command as one line: its words, each quoted when it has a space.
String _command(DevServer s) => [
  s.command,
  ...s.args,
].map((w) => w.contains(' ') || w.isEmpty ? '"$w"' : w).join(' ');

/// The tooltip of [s]'s row: the whole command, where it runs, from which
/// file, its env (the flagged keys marked) and where it answers.
String _details(DevServer s) {
  final env = [
    for (final MapEntry(:key, :value) in s.env.entries)
      '${s.flaggedEnv.contains(key) ? '⚠ ' : ''}$key=$value',
  ]..sort();
  return [
    if (s.problem.isNotEmpty) s.problem,
    if (s.command.isNotEmpty) _command(s),
    if (s.program.isNotEmpty && s.program != s.command) 'runs ${s.program}',
    if (s.cwd.isNotEmpty) 'in ${s.cwd}',
    'from ${s.fromMain ? 'the main checkout’s ' : ''}${s.source}',
    ...env,
    if (s.url.isNotEmpty) s.url,
  ].map(plainPath).join('\n');
}

/// On an entry whose name an agent's tools can't use (ADR 0095): its
/// preview_list counts it as unnamed and preview_start can't start it, so
/// only this menu runs it. The needs' ink on its soft fill, as a pill.
class _NameMark extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return tooltip(
      context,
      'The agent can’t start this server: a name it can use has only '
      'letters, digits and : _ . -, starts with a letter or digit, and '
      'is 64 characters at most. Rename it in its launch file, or run '
      'it from here.',
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: t.needsSoft,
          borderRadius: BorderRadius.circular(NushiTheme.pill),
        ),
        child: Text(
          'Agent can’t name it',
          maxLines: 1,
          softWrap: false,
          style: theme.ui(t.needs, size: 11, weight: FontWeight.w600),
        ),
      ),
    );
  }
}
