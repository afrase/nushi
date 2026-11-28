import 'package:flutter/material.dart';

import 'package:nushi/agent_words.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What can be done to a server, on its row: its on/off switch for the
/// project (a project server's Approve and Reject while it waits for
/// approval, for an agent whose shape has approval), "Log in" when it
/// needs a sign-in, and a menu with Edit…, Remove… and, for a server with
/// a URL, Log out. An agent whose shape has no off switch has no switch.
/// Whether the agent can sign in or out is the daemon's to say: needs_auth
/// offers Log in, and a Log out it can't do fails with its error.
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
    final (scope, about) = scopeOf(list.agent, server.scope);
    final ok = await confirm(
      context,
      'Remove ${server.name}?',
      list.userOnly
          ? 'It goes from your ${agentTitle(list.agent)} settings '
                '(${tildePath(server.source)}).'
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
    final remote = config(server)['url'] != null;
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
        tooltip(
          context,
          tip,
          Button(label: label, onPressed: _working ? null : onPressed),
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
            list.shape.approval &&
            server.state == 'pending' &&
            !server.off &&
            !server.approved) ...[
          button(
            'Approve',
            () => _setOn(true),
            tip:
                'Chats here use it either way; ${agentTitle(list.agent)} in '
                'a terminal, once you trust the folder there.',
          ),
          button('Reject', () => _setOn(false)),
        ] else
          McpSwitch(list, server),
        if (menu.isNotEmpty)
          MenuIcon.line(
            LineIcon.more,
            size: 15,
            tooltip: 'More',
            entries: menu,
          ),
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

/// What turns a server on or off, and for where: a switch, with where it
/// reaches beside it ([label]): "in this project", or "in every folder"
/// for one of yours whose agent's switch is its own flag in your file
/// (McpShape.user_switch, PiG's), for the scopes Nushi can; otherwise a
/// note that only the agent in a terminal does (its own command, as
/// [agentWords] names it); nothing for an agent whose shape has no off
/// switch, and an empty place for a server the agent doesn't load
/// (untrusted). A switch set in another file (off_by) is drawn off with
/// the reason as its tooltip; one the daemon says can't act here (held)
/// too, with no words of where it reaches (its row says why). On the
/// page the words sit in a slot of the longest's width, so the switches,
/// and the state pills before them, line up down the page whatever the
/// words or the agent. A change reaches a chat when it restarts.
class McpSwitch extends StatelessWidget {
  const new(this.list, this.server, {super.key, this.label = true});

  final McpServers list;
  final McpServer server;
  final bool label;

  /// The words a switch's slot is as wide as the longest of.
  static const _words = ['in this project', 'in every folder'];

  Future<void> _set({required bool on}) async {
    await setServerOn(list, server, on: on);
    list.changed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11);
    final title = agentTitle(list.agent);
    if (!list.shape.offSwitch) return const SizedBox.shrink();
    final slot = label ? _slot(context, muted) : 0.0;
    // One the agent doesn't load: its row says why, and there's nothing to
    // turn off until the folder is trusted. Its place stays.
    if (server.untrusted) {
      return SizedBox(width: label ? 14 + slot + Toggle.size.width : 0);
    }
    if (!switchable.contains(server.scope)) {
      final command = agentWords(list.agent).mcpCommand;
      final withIt = command == null ? '' : ' with $command';
      return tooltip(
        context,
        '$title only lets you turn this off$withIt in a terminal'
        '${server.scope == 'plugin' ? ', or with its whole plugin' : ''}.',
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            label
                ? 'Off only$withIt in a terminal'
                : '${command ?? 'Terminal'} only',
            style: muted,
          ),
        ),
      );
    }
    final held = server.held.isNotEmpty;
    final elsewhere = server.offBy.isNotEmpty;
    final everywhere =
        server.scope == 'user' &&
        list.shape.userSwitch == McpUserSwitch.MCP_USER_SWITCH_EVERYWHERE;
    final now = server.off ? 'Off' : 'On';
    const restart = 'Chats pick up a change when they restart.';
    final file = server.source.isEmpty ? 'its file' : tildePath(server.source);
    final tip = held
        ? server.held
        : elsewhere
        ? 'Turned off in ${tildePath(server.offBy)}; turn it on there.'
        : everywhere
        ? '$now in every folder, for you only: set in $file. $restart'
        // A project server's switch whose file everyone on the
        // repository shares (McpShape.project_switch_shared, PiG's).
        : server.scope == 'project' && list.shape.projectSwitchShared
        ? '$now in this project, for everyone on it: set in $file. $restart'
        : server.scope == 'project' && server.state == 'pending' && !server.off
        ? 'Approved. $title in a terminal uses it once you trust the folder '
              'there.'
        : '$now in this project. $restart';
    return tooltip(
      context,
      tip,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: SizedBox(
                width: slot,
                child: Text(
                  held
                      ? ''
                      : everywhere
                      ? 'in every folder'
                      : 'in this project',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: muted,
                ),
              ),
            ),
          SettingsSwitch(
            value: !server.off,
            run: held || elsewhere ? null : _set,
          ),
        ],
      ),
    );
  }

  /// The slot's width: the longest of [_words] in [style], as a Text
  /// draws it here (over the inherited style, as Text merges it).
  static double _slot(BuildContext context, TextStyle style) {
    final drawn = DefaultTextStyle.of(context).style.merge(style);
    var width = 0.0;
    for (final w in _words) {
      final p = TextPainter(
        text: TextSpan(text: w, style: drawn),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width = width < p.width ? p.width : width;
      p.dispose();
    }
    return width.ceilToDouble();
  }
}
