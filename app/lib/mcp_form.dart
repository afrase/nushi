import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:nushi/agent_words.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp_pairs.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Opens the form that adds a server to [list]'s folder (for its agent),
/// or edits [server] (its name and scope stay). The scopes offered, and
/// SSE, are the agent's McpShape's: Ante's are only yours, and only
/// Claude speaks SSE.
Future<void> mcpForm(
  BuildContext context,
  McpServers list, {
  McpServer? server,
}) => showDialog<void>(context: context, builder: (_) => _Form(list, server));

final _name = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_-]*$'); // as the daemon checks

/// The keys the form shows; others are kept as they are.
const _known = {'type', 'command', 'args', 'env', 'url', 'headers'};

class _Form extends StatefulWidget {
  const new(this.list, this.server);

  final McpServers list;
  final McpServer? server;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _nameCtl = TextEditingController(text: widget.server?.name);
  late String _scope = widget.server?.scope ?? 'user';
  String _transport = 'stdio';
  final _command = TextEditingController();
  final _args = TextEditingController(); // one per line
  final _url = TextEditingController();
  final _env = Pairs();
  final _headers = Pairs();
  Map<String, dynamic> _extra = {}; // what the form doesn't show
  bool _asJson = false;
  final _json = TextEditingController();
  String _error = '';
  bool _saving = false;

  bool get _editing => widget.server != null;

  /// The server's oauth block, which the form keeps without showing, has
  /// a part the daemon masked (shown as ••••).
  bool get _oauthHidden => jsonEncode(_extra['oauth'] ?? '').contains('••••');

  @override
  void initState() {
    super.initState();
    if (widget.server case final s? when !_load(config(s))) {
      _json.text = const JsonEncoder.withIndent('  ').convert(config(s));
      _asJson = true;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtl, _command, _args, _url, _json]) {
      c.dispose();
    }
    _env.dispose();
    _headers.dispose();
    super.dispose();
  }

  /// Fills the form from a config; false when the form can't show it.
  bool _load(Map<String, dynamic> c) {
    final t = transport(c);
    final args = c['args'] ?? <Object?>[];
    // One argument a line: one that has a line break, is empty or isn't
    // text would come back changed, so the JSON shows instead.
    final lines =
        args is List &&
        args.every(
          (a) => a is String && a.trim().isNotEmpty && !a.contains('\n'),
        );
    // A value of another type would be changed by the form's fields.
    final shaped =
        [
          c['type'],
          c['command'],
          c['url'],
        ].every((v) => v == null || v is String) &&
        [c['env'], c['headers']].every((v) => v == null || v is Map);
    if (!{'stdio', 'http', 'sse'}.contains(t) || !lines || !shaped) {
      return false;
    }
    _transport = t;
    _command.text = '${c['command'] ?? ''}';
    _args.text = args.join('\n');
    _url.text = '${c['url'] ?? ''}';
    _env.load(c['env']);
    _headers.load(c['headers']);
    _extra = {
      for (final e in c.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    };
    return true;
  }

  Map<String, dynamic> _config() {
    final stdio = _transport == 'stdio';
    final args = _args.text.split('\n').where((a) => a.trim().isNotEmpty);
    return {
      ..._extra,
      if (stdio) ...{
        'command': _command.text.trim(),
        if (args.isNotEmpty) 'args': args.toList(),
        if (_env.map.isNotEmpty) 'env': _env.map,
      } else ...{
        'type': _transport,
        'url': _url.text.trim(),
        if (_headers.map.isNotEmpty) 'headers': _headers.map,
      },
    };
  }

  void _toggleJson() => setState(() {
    _error = '';
    if (!_asJson) {
      _json.text = const JsonEncoder.withIndent('  ').convert(_config());
      _asJson = true;
      return;
    }
    final c = _parse();
    if (c == null) return;
    if (_load(c)) {
      _asJson = false;
    } else {
      _error = 'The form can’t show this config; edit it as JSON.';
    }
  });

  Map<String, dynamic>? _parse() {
    try {
      return (jsonDecode(_json.text) as Map).cast<String, dynamic>();
    } on Object {
      _error = 'That isn’t a JSON object.';
      return null;
    }
  }

  /// What's wrong with the form, or ''.
  String _check(Map<String, dynamic> c) {
    if (!_name.hasMatch(_nameCtl.text)) {
      // design: the hyphen named, not a separator
      return 'A name can only have letters, digits, - and _, and can’t '
          'start with -.';
    }
    final url = '${c['url'] ?? ''}';
    if (c['url'] == null && '${c['command'] ?? ''}'.trim().isEmpty) {
      return 'A command is needed.';
    }
    if (c['url'] != null && !RegExp(r'^https?://\S+$').hasMatch(url)) {
      return 'The URL must start with http:// or https://.';
    }
    return '';
  }

  Future<void> _save() async {
    setState(() => _error = '');
    final c = _asJson ? _parse() : _config();
    if (c == null || (_error = _check(c)).isNotEmpty) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    final l = widget.list;
    final json = jsonEncode(c);
    final name = _nameCtl.text;
    try {
      if (_editing) {
        await l.daemon.client.editMcpServer(
          EditMcpServerRequest(
            agent: l.agent,
            folder: l.folder,
            scope: _scope,
            name: name,
            configJson: json,
          ),
        );
      } else {
        await l.daemon.client.addMcpServer(
          AddMcpServerRequest(
            agent: l.agent,
            folder: l.folder,
            scope: _scope,
            name: name,
            configJson: json,
          ),
        );
      }
      l.changed();
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final mono = theme.code(t.text, size: 12);
    final stdio = _transport == 'stdio';
    final list = widget.list;
    final shape = list.shape;
    final userOnly = list.userOnly;
    final title = agentTitle(list.agent);
    // An agent with folder trust of its own loads a project's servers only
    // in a folder it trusts: said where the daemon says it doesn't.
    final untrusted = list.folderTrusted == false
        ? ' $title loads it once you trust this folder.'
        : '';
    final where = switch (_scope) {
      _ when userOnly =>
        'Yours, in every folder: $title reads no project’s MCP servers, so '
            'there’s no other scope.',
      'user' => 'Yours, in every folder.',
      'project' =>
        'In ${agentWords(list.agent).mcpProjectFile ?? 'the repository’s '
                '.mcp.json'}, shared with everyone on it.$untrusted',
      _ => 'Yours, in ${folderParts(list.folder).$1} only.',
    };
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: theme.ui(t.textSecondary, size: 12)),
    );
    return nushiDialog(
      // Named for the agent: with several, the scopes read alike.
      _editing
          ? 'Edit $title’s ${widget.server!.name}'
          : 'Add an MCP server for $title',
      width: 520,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            label('Name'),
            TextField(
              controller: _nameCtl,
              enabled: !_editing,
              autofocus: !_editing,
              style: mono,
              decoration: const InputDecoration(hintText: 'my-server'),
            ),
            label('Scope'),
            Row(
              children: [
                if (_editing || userOnly)
                  Text(scopeOf(list.agent, _scope).$1, style: theme.ui(t.text))
                else
                  Segmented(
                    value: _scope,
                    onCard: true,
                    segments: [
                      for (final scope in shape.scopes)
                        (scope, scopeOf(list.agent, scope).$1),
                    ],
                    onChanged: (v) => setState(() => _scope = v),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(where, style: muted),
            if (_asJson) ...[
              label('Config'),
              TextField(
                controller: _json,
                minLines: 8,
                maxLines: 16,
                style: mono,
              ),
            ] else ...[
              label('Transport'),
              Row(
                children: [
                  Segmented(
                    value: _transport,
                    onCard: true,
                    segments: [
                      ('stdio', 'stdio'),
                      ('http', 'HTTP'),
                      if (shape.sse || _transport == 'sse') ('sse', 'SSE'),
                    ],
                    onChanged: (v) => setState(() => _transport = v),
                  ),
                ],
              ),
              if (stdio) ...[
                label('Command'),
                TextField(
                  controller: _command,
                  style: mono,
                  decoration: const InputDecoration(hintText: 'npx'),
                ),
                label('Arguments, one per line'),
                TextField(
                  controller: _args,
                  minLines: 1,
                  maxLines: 6,
                  style: mono,
                  // An example, as the command's; its line holds the
                  // field at a regular control's height (ADR 0122).
                  decoration: const InputDecoration(
                    hintText: '@playwright/mcp@latest',
                  ),
                ),
                label('Environment variables'),
                PairRows(_env, 'NAME', () => setState(() {})),
              ] else ...[
                label('URL'),
                TextField(
                  controller: _url,
                  style: mono,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/mcp',
                  ),
                ),
                // The form doesn't show oauth (kept as it is): where the
                // daemon masked part of it, an edit here is refused unless
                // that part is typed again, which only the JSON can.
                if (_oauthHidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Its OAuth settings have hidden parts: change them in '
                      'Edit as JSON.',
                      style: muted,
                    ),
                  ),
                label('Headers'),
                PairRows(_headers, 'Header', () => setState(() {})),
              ],
              if (_editing)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Values shown as •••• stay only if nothing else '
                    'changes; else type them again.',
                    style: muted,
                  ),
                ),
            ],
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error, style: theme.ui(t.crashed, size: 12)),
              ),
          ],
        ),
      ),
      // The switch to JSON at the left, under the fields; Cancel and Add
      // at the right.
      [
        SizedBox(
          width: 520,
          child: Row(
            children: [
              Button(
                label: _asJson ? 'Edit in the form' : 'Edit as JSON',
                onPressed: _toggleJson,
              ),
              const Spacer(),
              Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              Button(
                label: _saving ? 'Saving…' : (_editing ? 'Save' : 'Add'),
                kind: ButtonKind.primary,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
