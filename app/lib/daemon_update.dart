import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

extension SendPrompt on Daemon {
  /// Sends a prompt. One the daemon refused because it's restarting into a
  /// newer build goes again once the new one answers (a minute at most).
  Future<void> sendPrompt(SendPromptRequest r) async {
    try {
      await client.sendPrompt(r);
    } on connect.ConnectException catch (e) {
      if (e.code != connect.Code.unavailable ||
          !refusedFor(e, 'restarting', (m) => m.contains('restarting'))) {
        rethrow;
      }
      final before = daemonBuild;
      for (var i = 0; i < 300 && !(connected && daemonBuild != before); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await client.sendPrompt(r);
    }
  }
}

/// Over the app while the daemon is older than the bundled one and
/// restarts into it by itself once nothing runs (Daemon.updatesWhenIdle),
/// with a way to restart now. A daemon too old for that gets
/// [OutdatedScreen].
class DaemonUpdateBar extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      color: t.raised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: daemon,
              builder: (context, _) => _Waiting(daemon),
            ),
          ),
          ListenableBuilder(
            listenable: daemon,
            builder: (context, _) => Button(
              label: daemon.restarting ? 'Restarting…' : 'Restart now',
              // What it stops is asked first.
              onPressed: daemon.restarting
                  ? null
                  : () => restartDaemonAsking(context, daemon),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Nushi will update its daemon when the chats are idle.", then what it
/// waits for, each a link to its chat: "Waiting for: Fix the login
/// redirect (working), a terminal running npm run dev in Release notes".
class _Waiting extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = theme.ui(t.textSecondary, size: 12);
    final holds = [
      for (final h in daemon.restartHolds)
        if (daemon.chats[h.chatId] case final c?) (h, c),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          'Nushi will update its daemon when the chats are idle.',
          style: style,
        ),
        if (holds.isNotEmpty) Text('Waiting for:', style: style),
        for (final (i, (h, c)) in holds.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (h.terminal) Text('a terminal ${h.why} in ', style: style),
              LinkText(
                c.shownTitle,
                size: 12,
                tooltip: 'Show the chat',
                onTap: () => daemon.select(c.id),
              ),
              Text(
                '${h.terminal ? '' : ' (${h.why})'}'
                '${i < holds.length - 1 ? ',' : ''}',
                style: style,
              ),
            ],
          ),
      ],
    );
  }
}

/// Says the daemon is older than the app and doesn't restart by itself,
/// with a way to restart it: the app shows nothing else until it has.
class OutdatedScreen extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            if (daemon.bundled != null)
              ListenableBuilder(
                listenable: daemon,
                builder: (context, _) => Button(
                  label: daemon.restarting ? 'Restarting…' : 'Restart daemon',
                  kind: ButtonKind.primary,
                  onPressed: daemon.restarting
                      ? null
                      : () => tryOrShow(context, daemon.restartDaemon),
                ),
              )
            else
              Text('make stop daemon', style: theme.code(t.textMuted)),
          ],
        ),
      ),
    );
  }
}
