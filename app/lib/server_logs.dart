import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/dev_servers.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' hide Terminal;
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_find.dart' show terminalStyle;
import 'package:nushi/terminal_screen.dart' show terminalTheme;
import 'package:nushi/terminals.dart' show terminalPlatform;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:xterm2/xterm.dart';

// The logs drawer (ADR 0100): a dev server's output, live, at the bottom of
// the browser tab's pane, drawn by the terminal's renderer but read-only.

/// The API from which the daemon streams a server's output.
const serverLogsApi = 111;

/// A server's output as the daemon streams it (WatchServerLog), in an
/// emulator that acts on nothing: its bytes are the server's, and none of
/// them reach the app or the Mac. It has no `onOutput` (its
/// queries' answers go nowhere), clipboard handlers that do nothing (else
/// the view puts in its own, and OSC 52 would write the clipboard), and no
/// handler for a title, a notification or a link (OSC 8), which opens only
/// on a ⌘-click the drawer doesn't take.
class ServerLog extends ChangeNotifier {
  new(this.client, this.chatId, this.logId) {
    _create();
  }

  final NushiServiceClient client;
  final String chatId;

  /// The server whose output it is: DevServer.log_id.
  final String logId;

  late Terminal terminal;
  StreamSubscription<WatchServerLogResponse>? _sub;
  bool _disposed = false;

  /// Whether the daemon said the server ended: all of it is here.
  bool ended = false;

  /// Why its output couldn't be had (it's gone: the folder kept five
  /// ended servers since), or null.
  String? error;

  // The emulator watches once its view has given it a size, so the output
  // so far is laid out at the width it shows at.
  void _create() {
    unawaited(_sub?.cancel());
    _sub = null;
    terminal =
        Terminal(
            maxLines: 10000,
            platform: terminalPlatform,
            onClipboardStore: (_, _) {},
            onClipboardQuery: (_) => null,
          )
          ..resize(1, 1)
          ..onResize = (_, _, _, _) {
            if (_sub == null && !_disposed) _watch();
          };
  }

  void _watch() {
    final text = StringBuffer();
    // One decoder per watch, dropped with the stream it decodes: a message
    // may cut a character in two.
    // ignore: close_sinks
    final utf8 = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(text));
    late final StreamSubscription<WatchServerLogResponse> sub;
    _sub = sub = client
        .watchServerLog(WatchServerLogRequest(chatId: chatId, serverId: logId))
        .listen(
          (m) {
            utf8.add(m.data);
            final s = text.toString();
            text.clear();
            if (s.isNotEmpty) terminal.write(s);
            if (m.ended) {
              ended = true;
              notifyListeners();
            }
          },
          onError: (Object e) => _retry(sub, e),
          onDone: () => _retry(sub, null),
        );
  }

  // The stream closed before the server's end: this client fell behind or
  // the daemon went away. It watches again, from a fresh emulator (the
  // output so far comes again), unless the output is gone or refused.
  void _retry(StreamSubscription<WatchServerLogResponse> closed, Object? e) {
    if (_disposed || ended || error != null || _sub != closed) return;
    if (e is ConnectException &&
        (e.code == Code.notFound || e.code == Code.permissionDenied)) {
      error = errorText(e);
      notifyListeners();
      return;
    }
    Timer(const Duration(seconds: 1), () {
      if (_disposed || _sub != closed) return;
      _create();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

/// The drawer of [chat]'s [ChatState.serverLogs], under the page: a row
/// with the server's name, state and port, Stop while it runs and Close,
/// over its output. Its height is a draggable edge, leaving the page at
/// least [pageLeast] of the [room] the two share.
class ServerLogsDrawer extends StatelessWidget {
  const new({
    required this.chat,
    required this.servers,
    required this.room,
    super.key,
  });

  final ChatState chat;
  final DevServers servers;
  final double room;

  /// How tall it opens.
  static const height = 240.0;

  /// How much of the room the page keeps.
  static const pageLeast = 160.0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: chat.serverLogs,
    builder: (context, entry, _) => entry == null
        ? const SizedBox.shrink()
        : Resizable(
            name: 'server logs',
            initial: height,
            min: 100,
            max: room - pageLeast,
            top: true,
            child: ServerLogs(
              key: ValueKey(entry),
              chat: chat,
              servers: servers,
              entry: entry,
            ),
          ),
  );
}

/// One entry's logs: its row, then the output of its server
/// (DevServer.log_id), followed to the next run's as the entry runs again.
class ServerLogs extends StatefulWidget {
  const new({
    required this.chat,
    required this.servers,
    required this.entry,
    super.key,
  });

  final ChatState chat;
  final DevServers servers;
  final ServerEntry entry;

  @override
  State<ServerLogs> createState() => _ServerLogsState();
}

class _ServerLogsState extends State<ServerLogs> {
  ServerLog? _log;
  final _scroll = ScrollController();
  final _controller = TerminalController();

  /// The entry's row as last listed, or null once it no longer is.
  DevServer? get _row {
    final e = widget.entry;
    return widget.servers
        .of(widget.chat.id)
        ?.servers
        .where(
          (s) =>
              s.name == e.name &&
              s.source == e.source &&
              s.fromMain == e.fromMain,
        )
        .firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    widget.servers.addListener(_follow);
    _follow();
  }

  /// Watches the server the entry's row names now: a new run's output
  /// takes the last one's place. A row that names none, or is gone, leaves
  /// the output that shows.
  void _follow() {
    final id = _row?.logId ?? '';
    if (id.isEmpty || id == _log?.logId) return;
    setState(() {
      _log?.dispose();
      _log = ServerLog(widget.servers.client, widget.chat.id, id);
    });
  }

  @override
  void dispose() {
    widget.servers.removeListener(_follow);
    _log?.dispose();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close() => widget.chat.serverLogs.value = null;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final log = _log;
    return ColoredBox(
      color: t.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: widget.servers,
            builder: (context, _) => _Bar(
              entry: widget.entry,
              row: _row,
              onStop: (id) => widget.servers.stop(widget.chat.id, id).ignore(),
              onClose: _close,
            ),
          ),
          Expanded(
            child: log == null
                ? _Note('No output yet', color: t.textMuted)
                : ListenableBuilder(
                    listenable: Listenable.merge([
                      log,
                      terminalFont,
                      terminalFontSize,
                    ]),
                    builder: (context, _) => log.error != null
                        ? _Note(log.error!, color: t.crashed)
                        : TerminalView(
                            log.terminal,
                            key: ObjectKey(log.terminal),
                            controller: _controller,
                            scrollController: _scroll,
                            readOnly: true,
                            hardwareKeyboardOnly: true,
                            // No cursor: nothing is typed here.
                            theme: terminalTheme(t, cursor: t.base),
                            textStyle: terminalStyle(),
                            padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
                            cursorType: TerminalCursorType.verticalBar,
                            keyboardAppearance: t.brightness,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A muted line where the output would be.
class _Note extends StatelessWidget {
  const new(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Text(
      plainPath(text),
      style: NushiTheme.of(context).ui(color, size: 12.5),
    ),
  );
}

/// The drawer's row: Logs, the server's name, its state as a solid badge
/// and its port; at its end Stop (solid red) while it runs, and Close.
class _Bar extends StatelessWidget {
  const new({
    required this.entry,
    required this.row,
    required this.onStop,
    required this.onClose,
  });

  final ServerEntry entry;
  final DevServer? row;
  final void Function(String serverId) onStop;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final s = row;
    final runs = s != null && DevServers.runs(s) && s.serverId.isNotEmpty;
    final (word, fill) = switch (s?.state) {
      DevServerState.DEV_SERVER_STATE_STARTING => ('Starting', t.running),
      DevServerState.DEV_SERVER_STATE_RUNNING => ('Running', t.done),
      DevServerState.DEV_SERVER_STATE_NOT_ANSWERING => (
        'Not answering',
        t.needs,
      ),
      DevServerState.DEV_SERVER_STATE_FAILED => ('Failed', t.crashed),
      _ => ('Stopped', t.textMuted),
    };
    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        spacing: 8,
        children: [
          Text('Logs', style: theme.ui(t.textSecondary, size: 12.5)),
          Expanded(
            child: Row(
              spacing: 8,
              children: [
                Flexible(
                  child: Text(
                    plainPath(entry.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.text, weight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(NushiTheme.pill),
                  ),
                  child: Text(
                    word,
                    style: theme.ui(
                      t.base,
                      size: 11.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                if (s != null && s.port > 0)
                  Text(
                    ':${s.port}',
                    style: theme.code(t.textSecondary, size: 12),
                  ),
              ],
            ),
          ),
          if (runs)
            IconTap(
              Icons.stop_rounded,
              tooltip: 'Stop',
              padding: 4,
              danger: true,
              onTap: () => onStop(s.serverId),
            ),
          IconTap.line(
            LineIcon.close,
            tooltip: 'Close logs',
            size: 18,
            padding: 4,
            color: t.text,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}
