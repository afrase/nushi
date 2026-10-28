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
          !e.message.contains('restarting')) {
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
class DaemonUpdateBar extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<DaemonUpdateBar> createState() => _DaemonUpdateBarState();
}

class _DaemonUpdateBarState extends State<DaemonUpdateBar> {
  bool _restarting = false;

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
            child: Text(
              'Nushi will update its daemon when the chats are idle.',
              style: theme.ui(t.textSecondary, size: 12),
            ),
          ),
          Button(
            label: _restarting ? 'Restarting…' : 'Restart now',
            onPressed: _restarting
                ? null
                : () async {
                    setState(() => _restarting = true);
                    // What it stops is asked first.
                    await restartDaemonAsking(context, widget.daemon);
                    if (mounted) setState(() => _restarting = false);
                  },
          ),
        ],
      ),
    );
  }
}

/// Says the daemon is older than the app and doesn't restart by itself,
/// with a way to restart it: the app shows nothing else until it has.
class OutdatedScreen extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<OutdatedScreen> createState() => _OutdatedScreenState();
}

class _OutdatedScreenState extends State<OutdatedScreen> {
  bool _restarting = false;

  Future<void> _restart() async {
    setState(() => _restarting = true);
    await tryOrShow(context, widget.daemon.restartDaemon);
    if (mounted) setState(() => _restarting = false);
  }

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
            if (widget.daemon.bundled != null)
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
