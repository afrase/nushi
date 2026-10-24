import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'agent_mark.dart';
import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'remote.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// How often the memory is read: a few milliseconds of the daemon's time.
const _every = Duration(seconds: 5);

/// The bar along the window's bottom: how many agents work, are awake and
/// sleep, and the memory Nushi takes (agents, daemon, app), which opens a
/// list of the awake chats, each with Sleep.
class StatusBar extends StatefulWidget {
  const StatusBar(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late final Timer _timer;
  GetMemoryResponse? _memory;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_every, (_) => _read());
    _read();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    if (!widget.daemon.connected) return;
    try {
      final m = await widget.daemon.client.getMemory(
        GetMemoryRequest(appPid: pid),
      );
      if (mounted) setState(() => _memory = m);
    } on Object {
      // The last reading stays until the next one.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final small = theme.ui(t.textSecondary, size: 11.5);
    // The chat list is the daemon's; each chat's status is its own.
    return ListenableBuilder(
      listenable: widget.daemon,
      builder: (context, _) => ListenableBuilder(
        listenable: Listenable.merge(widget.daemon.chats.values),
        builder: (context, _) {
          final live = widget.daemon.chats.values.where((c) => !c.archived);
          final working = live.where((c) => c.started != null).length;
          final asleep = live.where((c) => c.asleep).length;
          final awake = live.length - asleep;
          return Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: t.raised,
              border: Border(top: BorderSide(color: t.borderSubtle)),
            ),
            child: Row(
              children: [
                Tooltip(
                  message: '$working working, $awake awake, $asleep asleep',
                  child: Row(
                    spacing: 4,
                    children: [
                      _Dot(t.running, filled: true),
                      Text('$working', style: small),
                      const SizedBox(width: 6),
                      _Dot(t.idle),
                      Text('$awake', style: small),
                      const SizedBox(width: 6),
                      Icon(Icons.bedtime_outlined, size: 11, color: t.idle),
                      Text('$asleep', style: small),
                    ],
                  ),
                ),
                const Spacer(),
                const RemoteMark(),
                if (_memory case final m?)
                  _MemoryButton(m, widget.daemon, onOpen: _read, style: small),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.filled = false});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : null,
      border: filled ? null : Border.all(color: color, width: 1.5),
    ),
  );
}

/// "1.2 GB", or "240 MB".
String bytes(int n) => n >= 1000 << 20
    ? '${(n / (1 << 30)).toStringAsFixed(1)} GB'
    : '${(n / (1 << 20)).round()} MB';

/// The total, and on a click what makes it up; [onOpen] reads it again.
class _MemoryButton extends StatelessWidget {
  const _MemoryButton(
    this.m,
    this.daemon, {
    required this.onOpen,
    required this.style,
  });

  final GetMemoryResponse m;
  final Daemon daemon;
  final VoidCallback onOpen;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final agents = m.chats.values.fold(0, (a, n) => a + n.toInt());
    final nushi = (m.daemon + m.app).toInt();
    final total = agents + nushi + m.other.toInt();
    final chats = [
      for (final e in m.chats.entries)
        if (daemon.chats[e.key] case final c?) (c, e.value.toInt()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final asleep = daemon.chats.values
        .where((c) => c.asleep && !c.archived)
        .length;
    Widget row(Widget name, int n, {ChatState? chat}) => Padding(
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
              width: 58,
              child: chat != null && chat.canSleep
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Button(
                        label: 'Sleep',
                        kind: ButtonKind.ghost,
                        height: 22,
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
          TextSpan(text: text, style: theme.ui(t.text, size: 12.5)),
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
        for (final (c, n) in chats)
          row(label(c.title.isEmpty ? 'New chat' : c.title), n, chat: c),
        if (chats.isNotEmpty) const Divider(height: 9),
        row(label('Nushi', 'daemon and app'), nushi),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          spacing: 4,
          children: [
            Icon(Icons.memory, size: 12, color: t.textSecondary),
            Text(bytes(total), style: style),
          ],
        ),
      ),
    );
  }
}
