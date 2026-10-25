import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Reveals the daemon's log (nushid.log, app.log beside it) in Finder.
Future<void> showLogs() async {
  final log = '$dataDir/nushid.log';
  await Process.run(
    '/usr/bin/open',
    File(log).existsSync() ? ['-R', log] : [dataDir],
  );
}

/// Settings' Logs: Show logs, and whether the daemon's log has DEBUG lines
/// ([debug] null: the daemon didn't say, so no switch).
class LogsSection extends StatelessWidget {
  const new({
    required this.debug,
    required this.onDebug,
    super.key,
    this.reveal = showLogs,
  });

  final bool? debug;
  final ValueChanged<bool> onDebug;
  final Future<void> Function() reveal;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Logs', style: theme.ui(t.text, weight: FontWeight.w600)),
            const Spacer(),
            Button(
              label: 'Show logs',
              kind: ButtonKind.ghost,
              height: 24,
              onPressed: reveal,
            ),
          ],
        ),
        if (debug case final on?) ...[
          Row(
            children: [
              Text('Debug lines', style: theme.ui(t.textSecondary)),
              const Spacer(),
              SizedBox(
                height: 20,
                child: FittedBox(
                  child: Switch(value: on, onChanged: onDebug),
                ),
              ),
            ],
          ),
          Text(
            'Every agent and API call, with timings.',
            style: theme.ui(t.textSecondary, size: 12),
          ),
        ],
      ],
    );
  }
}
