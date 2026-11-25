import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_install.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/status_spend.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How often the memory is read while the window shows: a few
/// milliseconds of the daemon's time.
const _every = Duration(seconds: 5);

/// Today's spend ([TodaySpend]) and the memory Nushi takes (agents,
/// daemon, app), which opens a list of the awake chats, each with Sleep:
/// the card at the sidebar's foot (ADR 0111; a bar along the
/// window's bottom until then). It hides with the sidebar: a line under
/// the main pane in its place changed the pane's height each time the
/// sidebar came or went.
class StatusBar extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  /// The card's height.
  static const cardHeight = 34.0;

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late final Timer _timer;
  late final AppLifecycleListener _lifecycle;

  /// The daemon's last reading: the card goes and comes with the sidebar,
  /// and one that comes shows what the last read rather than nothing.
  static final _last = Expando<GetMemoryResponse>();
  late GetMemoryResponse? _memory = _last[widget.daemon];

  late final _spend = TodaySpend(widget.daemon);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_every, (_) {
      if (widget.daemon.macView.window) unawaited(_read());
    });
    // The window back from hidden reads at once: the last reading may be
    // hours old.
    _lifecycle = AppLifecycleListener(onShow: () => unawaited(_read()));
    unawaited(_read());
  }

  @override
  void dispose() {
    _timer.cancel();
    _lifecycle.dispose();
    _spend.dispose();
    super.dispose();
  }

  /// Whether the daemon said it can't read memory: then nothing asks
  /// again, the window shown or not.
  bool _unread = false;

  Future<void> _read() async {
    if (_unread || !widget.daemon.connected) return;
    try {
      final m = await widget.daemon.client.getMemory(
        GetMemoryRequest(appPid: pid),
      );
      // A reading that shows as the last did draws nothing: a frame
      // draws the whole window.
      if (!mounted || _memory != null && _shows(m) == _shows(_memory!)) {
        return;
      }
      _last[widget.daemon] = m;
      setState(() => _memory = m);
    } on ConnectException catch (e) {
      // The daemon's OS doesn't say (Windows, so far): asking again
      // won't change that, so the card shows no memory. Any other
      // failure keeps the last reading until the next one.
      if (e.code == Code.unimplemented) {
        _timer.cancel();
        _unread = true;
      }
    } on Object {
      // The last reading stays until the next one.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final small = theme
        .ui(t.textMuted, size: 12)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      height: StatusBar.cardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      // Two quiet figures, each with what says what it is: today's spend
      // at the start, the memory at the end, the remote's mark before it.
      // Without a spend the start is empty: the memory and the mark stay
      // where they are, so nothing moves as a spend comes or goes. A
      // narrow card scales the spend down rather than cutting it.
      child: ValueListenableBuilder(
        valueListenable: _spend,
        builder: (context, spent, _) {
          // Its list names the chats and offers Sleep as each one's look
          // says: it follows the daemon's list and each chat's look.
          final memory = switch (_memory) {
            final m? => ListenableBuilder(
              listenable: widget.daemon,
              builder: (context, _) => ListenableBuilder(
                listenable: Listenable.merge([
                  for (final c in widget.daemon.chats.values) c.look,
                ]),
                builder: (context, _) => _MemoryButton(
                  m,
                  widget.daemon,
                  onOpen: _read,
                  style: small,
                ),
              ),
            ),
            null => null,
          };
          final shown = widget.daemon.daemonApi >= usageApi ? spent : null;
          return Row(
            children: [
              Expanded(
                child: switch (shown) {
                  final s? => Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SpendButton(s, widget.daemon, style: small),
                    ),
                  ),
                  null => const SizedBox.shrink(),
                },
              ),
              const RemoteMark(),
              ?memory,
            ],
          );
        },
      ),
    );
  }
}

/// The whole of [m]: the agents', Nushi's and the rest.
int _total(GetMemoryResponse m) =>
    m.chats.values.fold(0, (a, n) => a + n.toInt()) +
    (m.daemon + m.app + m.other).toInt();

/// What [m] shows, in the bar and its menu, as the menu rounds it.
String _shows(GetMemoryResponse m) => [
  bytes(_total(m)),
  for (final id in m.chats.keys.toList()..sort())
    '$id ${bytes(m.chats[id]!.toInt())}',
  for (final n in [m.daemon, m.app, m.other]) bytes(n.toInt()),
].join(', ');

/// "1.2 GB", or "240 MB".
String bytes(int n) => n >= 1000 << 20
    ? '${(n / (1 << 30)).toStringAsFixed(1)} GB'
    : '${(n / (1 << 20)).round()} MB';

/// The total, and on a click what makes it up; [onOpen] reads it again.
class _MemoryButton extends StatelessWidget {
  const new(this.m, this.daemon, {required this.onOpen, required this.style});

  final GetMemoryResponse m;
  final Daemon daemon;
  final VoidCallback onOpen;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final total = _total(m);
    final chats = [
      for (final e in m.chats.entries)
        if (daemon.chats[e.key] case final c?) (c, e.value.toInt()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final asleep = daemon.chats.values
        .where((c) => c.asleep && !c.archived)
        .length;
    Widget row(Widget name, int n, {ChatState? chat, Widget? action}) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
          child: SizedBox(
            width: 340,
            child: Row(
              children: [
                if (chat != null) ...[
                  AgentMark(chat.agent, size: 12),
                  const SizedBox(width: 6),
                ],
                Expanded(child: name),
                Text(bytes(n), style: theme.ui(t.textSecondary, size: 12)),
                SizedBox(
                  width: 70,
                  child: action != null
                      ? Align(alignment: Alignment.centerRight, child: action)
                      : chat != null && chat.canSleep
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Button(
                            label: 'Sleep',
                            onPressed: () => sleepChat(
                              context,
                              chat,
                              daemon,
                            ).then((_) => onOpen()),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
    Widget label(String text, [String detail = '']) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text, style: theme.ui(t.text, size: 12)),
          if (detail.isNotEmpty)
            TextSpan(text: '  $detail', style: theme.ui(t.textMuted, size: 12)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final (c, n) in chats) row(label(c.shownTitle), n, chat: c),
        if (chats.isNotEmpty) const Divider(height: 9),
        // Apart: one large number for both read as the daemon's.
        if (m.app > 0) row(label('Nushi app'), m.app.toInt()),
        row(
          label('Nushi daemon'),
          m.daemon.toInt(),
          action: native.install.restartsDaemon
              ? Button(
                  label: daemon.restarting ? 'Restarting…' : 'Restart',
                  onPressed: daemon.restarting
                      ? null
                      : () => restartDaemonAsking(context, daemon),
                )
              : null,
        ),
        if (m.other > 0) row(label('Terminals and other'), m.other.toInt()),
        if (asleep > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
            child: Text(
              '$asleep asleep',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ),
      ],
      builder: (context, menu, _) => Tap(
        onTap: () {
          if (menu.isOpen) return menu.close();
          onOpen();
          menu.open();
        },
        tooltip: 'The memory Nushi takes',
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          spacing: 4,
          children: [
            Icon(Icons.memory, size: 12, color: t.textMuted),
            Text(bytes(total), style: style),
          ],
        ),
      ),
    );
  }
}

/// Restarts the daemon (the bundled one), first asking when that stops
/// something: a turn running, a chat with an agent, or a terminal running
/// a command (in any chat, an asleep one's too: its terminals end with the
/// daemon).
Future<void> restartDaemonAsking(BuildContext context, Daemon daemon) async {
  final awake = daemon.chats.values
      .where((c) => !c.asleep && !c.archived && c.canSleep)
      .length;
  final busy = daemon.chats.values.where((c) => c.busy).length;
  final running = await _runningTerminals(daemon);
  if (!context.mounted) return;
  final programs = running?.map((p) => '“$p”').join(', ');
  if (busy + awake > 0 || running == null || running.isNotEmpty) {
    final what = busy > 0
        ? 'It stops $busy running turn${busy == 1 ? '' : 's'} and closes '
              'terminals. Chats reopen when you next use them.'
        : awake > 0
        ? "Chats' agents stop and terminals close; chats reopen when "
              'you next use them.'
        : 'Terminals close.';
    final ok = await confirm(
      context,
      'Restart the daemon?',
      programs == null || programs.isEmpty
          ? what
          : '$what It ends what runs in them: $programs.',
      'Restart',
      destructive: busy > 0,
    );
    if (!ok) return;
  }
  if (!context.mounted) return;
  await tryOrShow(context, daemon.restartDaemon);
}

/// What runs in the chats' terminals (each foreground program), or null
/// when the daemon couldn't say. A daemon that doesn't answer within
/// [_terminalsWait] couldn't say: a stuck one is a reason to restart, and
/// Restart would otherwise do nothing at all.
Future<List<String>?> _runningTerminals(Daemon daemon) async {
  try {
    final lists = await Future.wait([
      for (final c in daemon.chats.values)
        if (!c.archived)
          daemon.client.listTerminals(ListTerminalsRequest(chatId: c.id)),
    ]).timeout(_terminalsWait);
    return [
      for (final l in lists)
        for (final t in l.terminals)
          if (t.program.isNotEmpty && !t.exited) t.program,
    ];
  } on Object {
    return null;
  }
}

/// How long Restart waits for the chats' terminals before asking anyway.
const _terminalsWait = Duration(seconds: 2);
