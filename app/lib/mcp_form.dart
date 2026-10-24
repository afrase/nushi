import 'dart:convert';

import 'package:flutter/material.dart';

import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'mcp_pairs.dart';
import 'mcp_servers.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// Opens the form that adds a server to [list]'s folder, or edits [server]
/// (its name and scope stay).
Future<void> mcpForm(
  BuildContext context,
  McpServers list, {
  McpServer? server,
}) => showDialog<void>(context: context, builder: (_) => _Form(list, server));

final _name = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_-]*$'); // as the daemon checks

/// The keys the form shows; others are kept as they are.
const _known = {'type', 'command', 'args', 'env', 'url', 'headers'};

class _Form extends StatefulWidget {
  const _Form(this.list, this.server);

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
  final _env = Pairs(), _headers = Pairs();
  Map<String, dynamic> _extra = {}; // what the form doesn't show
  bool _asJson = false;
  final _json = TextEditingController();
  String _error = '';
  bool _saving = false;

  bool get _editing => widget.server != null;

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
    final args = c['args'] ?? [];
    // One argument a line: one that has a line break, is empty or isn't
    // text would come back changed, so the JSON shows instead.
    final lines =
        args is List &&
        args.every(
          (a) => a is String && a.trim().isNotEmpty && !a.contains('\n'),
        );
    if (!{'stdio', 'http', 'sse'}.contains(t) || !lines) return false;
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
    final l = widget.list, json = jsonEncode(c), name = _nameCtl.text;
    try {
      if (_editing) {
        await l.daemon.client.editMcpServer(
          EditMcpServerRequest(
            folder: l.folder,
            scope: _scope,
            name: name,
            configJson: json,
          ),
        );
      } else {
        await l.daemon.client.addMcpServer(
          AddMcpServerRequest(
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
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final mono = theme.code(t.text, size: 12);
    final stdio = _transport == 'stdio';
    final where = switch (_scope) {
      'user' => 'Yours, in every folder.',
      'project' => 'In the repository’s .mcp.json, shared with everyone on it.',
      _ => 'Yours, in ${folderParts(widget.list.folder).$1} only.',
    };
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: theme.ui(t.textSecondary, size: 12)),
    );
    return AlertDialog(
      title: Text(_editing ? 'Edit ${widget.server!.name}' : 'Add MCP server'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
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
                  _editing
                      ? Text(scopes[_scope]!.$1, style: theme.ui(t.text))
                      : Segmented(
                          value: _scope,
                          segments: const [
                            ('user', 'User'),
                            ('project', 'Project'),
                            ('local', 'Local'),
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
                      segments: const [
                        ('stdio', 'stdio'),
                        ('http', 'HTTP'),
                        ('sse', 'SSE'),
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
      ),
      actions: [
        Button(
          label: _asJson ? 'Edit in the form' : 'Edit as JSON',
          kind: ButtonKind.ghost,
          onPressed: _toggleJson,
        ),
        const SizedBox(width: 60),
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context),
        ),
        Button(
          label: _saving ? 'Saving…' : (_editing ? 'Save' : 'Add'),
          kind: ButtonKind.primary,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
