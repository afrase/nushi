import 'package:flutter/material.dart';

import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What can be done to a server, on its row: its on/off switch for the
/// project (a project server's Approve and Reject while it waits for
/// approval), "Log in" when it needs a sign-in, and a menu with Edit…,
/// Remove… and Log out. Ante's have Edit… and Remove… only: it has no off
/// switch nor sign-in Nushi can use.
class McpActions extends StatefulWidget {
  const new(this.list, this.server, {super.key});

  final McpServers list;
  final McpServer server;

  @override
  State<McpActions> createState() => _McpActionsState();
}

class _McpActionsState extends State<McpActions> {
  bool _working = false; // a change or a sign-in is under way

  McpServers get list => widget.list;
  McpServer get server => widget.server;

  Future<void> _do(Future<void> Function() call) async {
    setState(() => _working = true);
    await tryOrShow(context, () async {
      await call();
      list.changed();
    });
    if (mounted) setState(() => _working = false);
  }

  Future<void> _setOn(bool on) => _do(() => setServerOn(list, server, on: on));

  Future<void> _remove() async {
    final (scope, about) = scopes[server.scope]!;
    final ok = await confirm(
      context,
      'Remove ${server.name}?',
      list.ante
          ? 'It goes from your Ante settings (${tildePath(server.source)}).'
          : 'It goes from the $scope scope: ${about[0].toLowerCase()}'
                '${about.substring(1)}',
      'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _do(
      () => list.daemon.client.removeMcpServer(
        RemoveMcpServerRequest(
          agent: list.agent,
          folder: list.folder,
          scope: server.scope,
          name: server.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final daemon = list.daemon;
    final project = server.scope == 'project';
    final remote = config(server)['url'] != null && !list.ante;
    final menu = [
      if ({'user', 'project', 'local'}.contains(server.scope)) ...[
        MenuEntry(
          'Edit…',
          onPick: () => mcpForm(context, list, server: server),
        ),
        MenuEntry('Remove…', onPick: _remove),
      ],
      if (remote)
        MenuEntry(
          'Log out',
          tooltip: 'Forget its sign-in',
          onPick: () => _do(
            () => daemon.client.logoutMcpServer(
              LogoutMcpServerRequest(
                agent: list.agent,
                folder: list.folder,
                name: server.name,
              ),
            ),
          ),
        ),
    ];
    Widget button(String label, VoidCallback onPressed, {String tip = ''}) =>
        Tooltip(
          message: tip,
          child: Button(label: label, onPressed: _working ? null : onPressed),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_working && server.state == 'needs_auth')
          Text('Finish in the browser…', style: theme.ui(t.textMuted, size: 12))
        else if (server.state == 'needs_auth')
          button(
            'Log in',
            () => _do(
              () => daemon.client.loginMcpServer(
                LoginMcpServerRequest(
                  agent: list.agent,
                  folder: list.folder,
                  name: server.name,
                ),
              ),
            ),
          ),
        if (project &&
            server.state == 'pending' &&
            !server.off &&
            !server.approved) ...[
          button(
            'Approve',
            () => _setOn(true),
            tip:
                'Chats here use it either way; Claude in a terminal, once '
                'you trust the folder there.',
          ),
          button('Reject', () => _setOn(false)),
        ] else
          McpSwitch(list, server),
        if (menu.isNotEmpty)
          MenuIcon(Icons.more_horiz, tooltip: 'More', size: 15, entries: menu),
      ],
    );
  }
}

/// Turns [server] on or off for the folder's project.
Future<void> setServerOn(
  McpServers list,
  McpServer server, {
  required bool on,
}) => list.daemon.client.setMcpServerOn(
  SetMcpServerOnRequest(
    agent: list.agent,
    folder: list.folder,
    scope: server.scope,
    name: server.name,
    on: on,
  ),
);

/// The scopes whose servers Nushi turns on and off: a project server's
/// approval, a user or local one as /mcp does (ADR 0050).
const switchable = {'project', 'user', 'local'};

/// What turns a server on or off, and for where: a switch, "in this
/// project" beside it ([label]), for the scopes Nushi can; otherwise a
/// note that only /mcp in a terminal does; nothing for Ante's, which
/// can't be turned off. A change reaches a chat when it restarts.
class McpSwitch extends StatefulWidget {
  const new(this.list, this.server, {super.key, this.label = true});

  final McpServers list;
  final McpServer server;
  final bool label;

  @override
  State<McpSwitch> createState() => _McpSwitchState();
}

class _McpSwitchState extends State<McpSwitch> {
  bool _working = false;

  McpServer get server => widget.server;

  Future<void> _set(bool on) async {
    setState(() => _working = true);
    await tryOrShow(context, () async {
      await setServerOn(widget.list, server, on: on);
      widget.list.changed();
    });
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11);
    if (widget.list.ante) return const SizedBox.shrink(); // no off switch
    if (!switchable.contains(server.scope)) {
      return Tooltip(
        message:
            'Claude only lets you turn this off with /mcp in a terminal'
            '${server.scope == 'plugin' ? ', or with its whole plugin' : ''}.',
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            widget.label ? 'Off only with /mcp in a terminal' : '/mcp only',
            style: muted,
          ),
        ),
      );
    }
    final elsewhere = server.offBy.isNotEmpty;
    final tip = elsewhere
        ? 'Turned off in ${tildePath(server.offBy)}; turn it on there.'
        : server.scope == 'project' && server.state == 'pending' && !server.off
        ? 'Approved. Claude in a terminal uses it once you trust the folder '
              'there.'
        : '${server.off ? 'Off' : 'On'} in this project. Chats pick up a '
              'change when they restart.';
    return Tooltip(
      message: tip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 2),
              child: Text('in this project', style: muted),
            ),
          SizedBox(
            height: 20,
            child: FittedBox(
              child: Switch(
                value: !server.off,
                onChanged: _working || elsewhere ? null : _set,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
