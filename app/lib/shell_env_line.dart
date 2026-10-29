import 'package:flutter/material.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › Agents' last line: agents start with the login shell's
/// environment, read when, or why it couldn't be read; Reload reads it
/// again (ADR 0048). Nothing of the environment itself comes to the app.
class ShellEnvLine extends StatelessWidget {
  const new(this.client, {super.key});

  final NushiServiceClient client;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: shellEnvironment,
    builder: (context, env, _) {
      if (env == null) return const SizedBox.shrink();
      final t = NushiTheme.of(context).t;
      final shell = env.shell.split('/').last;
      final when = DateTime.fromMillisecondsSinceEpoch(env.readUnixMs.toInt());
      final text = env.problem.isEmpty
          ? "Agents start with $shell's environment, read "
                '${ago(clock().difference(when), when)}.'
          : "Couldn't read your shell's environment: ${env.problem}.";
      return SettingsGroup(
        children: [
          SettingsRow(
            'Shell environment',
            description: text,
            descriptionColor: env.problem.isEmpty ? null : t.needs,
            control: RunButton(
              label: 'Reload',
              running: 'Reloading…',
              tooltip: "Read your login shell's environment again",
              run: () => listAgents(client, reloadEnvironment: true),
            ),
          ),
        ],
      );
    },
  );
}
