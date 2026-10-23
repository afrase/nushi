import 'dart:convert';

import 'package:flutter/material.dart';

import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
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

final _name = RegExp(r'^[A-Za-z0-9_-]+$');

/// The keys the form shows; others are kept as they are.
const _known = {'type', 'command', 'args', 'env', 'url', 'headers'};

/// Key/value rows: env vars or headers.
class _Pairs {
  final rows = <(TextEditingController, TextEditingController)>[];

  void load(Object? m) {
    rows.clear();
    for (final MapEntry(:key, :value) in (m as Map? ?? {}).entries) {
      add('$key', '$value');
    }
  }

  void add([String k = '', String v = '']) => rows.add((
    TextEditingController(text: k),
    TextEditingController(text: v),
  ));

  Map<String, String> get map => {
    for (final (k, v) in rows)
      if (k.text.trim().isNotEmpty) k.text.trim(): v.text,
  };
}

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
  final _env = _Pairs(), _headers = _Pairs();
  Map<String, dynamic> _extra = {}; // what the form doesn't show
  bool _asJson = false;
  final _json = TextEditingController();
  String _error = '';
  bool _saving = false;

  bool get _editing => widget.server != null;

  @override
  void initState() {
    super.initState();
    if (widget.server case final s?) _load(config(s));
  }

  /// Fills the form from a config; false when the form can't show it.
  bool _load(Map<String, dynamic> c) {
    final t = transport(c);
    final args = c['args'] ?? [];
    if (!{'stdio', 'http', 'sse'}.contains(t) || args is! List) return false;
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
      return 'A name can only have letters, digits, - and _.';
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
      'user' => 'For you, in every folder (Claude’s own config).',
      'project' =>
        'Adds to the repository’s .mcp.json, which is shared with everyone '
            'on the repo.',
      _ => 'For you, in ${folderParts(widget.list.folder).$1} only.',
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
                  _PairRows(_env, 'NAME', () => setState(() {})),
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
                  _PairRows(_headers, 'Header', () => setState(() {})),
                ],
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'A value left as •••• keeps the one it has.',
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

/// Key/value rows, each removable, and a row to add one.
class _PairRows extends StatelessWidget {
  const _PairRows(this.pairs, this.hint, this.changed);

  final _Pairs pairs;
  final String hint;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final mono = theme.code(t.text, size: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (k, v)) in pairs.rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: k,
                    style: mono,
                    decoration: InputDecoration(hintText: hint),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: v,
                    style: mono,
                    decoration: const InputDecoration(hintText: 'value'),
                  ),
                ),
                IconTap(
                  Icons.close,
                  tooltip: 'Remove',
                  size: 14,
                  onTap: () {
                    pairs.rows.removeAt(i);
                    changed();
                  },
                ),
              ],
            ),
          ),
        Button(
          label: 'Add',
          icon: Icons.add,
          kind: ButtonKind.ghost,
          height: 22,
          onPressed: () {
            pairs.add();
            changed();
          },
        ),
      ],
    );
  }
}
