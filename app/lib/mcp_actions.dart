import 'package:flutter/material.dart';

import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'mcp_form.dart';
import 'mcp_servers.dart';
import 'menu.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// What can be done to a server, on its row: a project server's on/off
/// switch (Approve and Reject while it waits for approval), "Log in" when
/// it needs a sign-in, and a menu with Edit…, Remove… and Log out.
class McpActions extends StatefulWidget {
  const McpActions(this.list, this.server, {super.key});

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

  Future<void> _setOn(bool on) => _do(
    () => list.daemon.client.setMcpServerOn(
      SetMcpServerOnRequest(folder: list.folder, name: server.name, on: on),
    ),
  );

  Future<void> _remove() async {
    final (scope, about) = scopes[server.scope]!;
    final ok = await confirm(
      context,
      'Remove ${server.name}?',
      'It goes from the $scope scope: ${about[0].toLowerCase()}'
          '${about.substring(1)}',
      'Remove',
    );
    if (!ok || !mounted) return;
    await _do(
      () => list.daemon.client.removeMcpServer(
        RemoveMcpServerRequest(
          folder: list.folder,
          scope: server.scope,
          name: server.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final daemon = list.daemon;
    final project = server.scope == 'project' && daemon.canMcpOn;
    final remote = config(server)['url'] != null && daemon.canMcpOn;
    final menu = [
      if ({'user', 'project', 'local'}.contains(server.scope) &&
          daemon.canMcpChange) ...[
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
              LogoutMcpServerRequest(folder: list.folder, name: server.name),
            ),
          ),
        ),
    ];
    Widget button(String label, VoidCallback onPressed, {String tip = ''}) =>
        Tooltip(
          message: tip,
          child: Button(
            label: label,
            kind: ButtonKind.ghost,
            height: 22,
            onPressed: _working ? null : onPressed,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_working && server.state == 'needs_auth')
          Text('Finish in the browser…', style: theme.ui(t.textMuted, size: 12))
        else if (server.state == 'needs_auth' && daemon.canMcpOn)
          button(
            'Log in',
            () => _do(
              () => daemon.client.loginMcpServer(
                LoginMcpServerRequest(folder: list.folder, name: server.name),
              ),
            ),
            tip: 'Opens the browser to sign in',
          ),
        if (project &&
            server.state == 'pending' &&
            !server.off &&
            !server.approved) ...[
          button(
            'Approve',
            () => _setOn(true),
            tip:
                'Adds it to enabledMcpjsonServers in the project’s '
                '.claude/settings.local.json. Claude in the terminal takes '
                'that once you’ve trusted the folder there; chats in Nushi '
                'use it either way.',
          ),
          button(
            'Reject',
            () => _setOn(false),
            tip:
                'Adds it to disabledMcpjsonServers in the project’s '
                '.claude/settings.local.json: off for this project.',
          ),
        ] else if (project)
          Tooltip(
            message: server.offBy.isNotEmpty
                ? 'Turned off in ${tildePath(server.offBy)}; turn it on there.'
                : server.off
                ? 'Off for this project'
                : server.state == 'pending'
                ? 'Approved in .claude/settings.local.json. Claude in the '
                      'terminal takes that once you’ve trusted the folder '
                      'there; chats in Nushi use it either way.'
                : 'On for this project',
            child: SizedBox(
              height: 20,
              child: FittedBox(
                child: Switch(
                  value: !server.off,
                  onChanged: _working || server.offBy.isNotEmpty
                      ? null
                      : _setOn,
                ),
              ),
            ),
          ),
        if (menu.isNotEmpty)
          Menu(
            tooltip: 'More',
            entries: menu,
            child: Icon(Icons.more_horiz, size: 15, color: t.textSecondary),
          ),
      ],
    );
  }
}
