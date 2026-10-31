/// A tool row's parts: its title, its body's input and output, and its
/// Preview button.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// An MCP tool's name as Claude Code makes it, `mcp__<server>__<tool>`:
/// the server up to the next `__`, the tool the rest.
(String, String)? mcpName(String name) {
  if (!name.startsWith('mcp__')) return null;
  final rest = name.substring(5);
  final sep = rest.indexOf('__');
  if (sep <= 0 || sep + 2 >= rest.length) return null;
  return (rest.substring(0, sep), rest.substring(sep + 2));
}

/// Nushi's show tool (ADR 0068) as Claude's agents and Codex's adapter
/// title its calls; the daemon's `isShow` knows them too.
const showTitles = {'mcp__nushi__show', 'mcp.nushi.show'};

/// Whether [it] is a show call, or the ask to run one.
bool isShow(Item it) => showTitles.contains(it.title);

/// The file a show call names, from its input: `path`, inside `arguments`
/// on Codex. Null while its input hasn't come (Claude's comes just after
/// the call), or when it was cut short.
String? showPath(Item it) {
  if (!isShow(it) || it.input.isEmpty) return null;
  try {
    final input = jsonDecode(it.input);
    final args = input is Map ? input['arguments'] ?? input : null;
    final path = args is Map ? args['path'] : null;
    return path is String && path.isNotEmpty ? plainPath(path) : null;
  } on FormatException {
    return null;
  }
}

final _unprintable = RegExp('[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]');

/// [path], an agent's, with what could make it read as something else
/// (new lines, bidi controls) marked. It only names the file: the daemon
/// checks whatever the app asks for.
String plainPath(String path) => path.replaceAll(_unprintable, '�');

/// A tool call's title: the agent's, but an MCP call titled with its raw
/// name reads "server · tool", and "· inner" when its input names the tool
/// it runs (a gateway's `tool`, `tool_name` or `name`).
String toolTitle(Item it) {
  if (isShow(it)) return 'Showing a file';
  final mcp = mcpName(it.title);
  if (mcp == null) return it.title;
  final (server, tool) = mcp;
  final inner = innerTool(it.input);
  return [server, tool, ?inner].join(' · ');
}

final _innerKey = RegExp(
  r'^  "(tool|tool_name|name)": ("(?:[^"\\]|\\.)*")',
  multiLine: true,
);

final _argsKey = RegExp(
  '^  "(arguments|args|params|parameters)": ',
  multiLine: true,
);

/// The tool an input names at its top level (`tool`, then `tool_name`, each
/// a string; `name` only beside the call's `arguments`, as a gateway's, so
/// that a tool's own `name` argument isn't taken for one), read from the
/// indented JSON the daemon keeps, which may be cut short.
String? innerTool(String input) {
  final found = {for (final m in _innerKey.allMatches(input)) m[1]!: m[2]!};
  final keys = ['tool', 'tool_name', if (_argsKey.hasMatch(input)) 'name'];
  for (final key in keys) {
    final quoted = found[key];
    if (quoted == null) continue;
    try {
      final name = (jsonDecode(quoted) as String).trim();
      if (name.isNotEmpty) return name;
    } on FormatException {
      continue;
    }
  }
  return null;
}

/// Whether a call runs a command: its title is the command.
bool isCommand(Item it) =>
    it.toolKind == 'execute' && it.title.isNotEmpty && !isShow(it);

/// Whether a call's input shows: it has one and no diff or command says
/// what it did, and either nothing else shows or it's a tool ACP has no kind
/// for (an MCP tool's), whose content is only its result. A show call's
/// title says its input.
bool showsInput(Item it) =>
    it.input.isNotEmpty &&
    !isShow(it) &&
    it.diffs.isEmpty &&
    !isCommand(it) &&
    (it.text.trim().isEmpty || it.toolKind == 'other' || it.toolKind.isEmpty);

/// Whether a call's raw output shows: the agent's content showed nothing.
bool showsRawOutput(Item it) =>
    it.rawOutput.isNotEmpty &&
    it.text.trim().isEmpty &&
    it.diffs.isEmpty &&
    !isCommand(it);

/// Whether a call has anything to show when opened.
bool hasToolBody(Item it) =>
    it.text.trim().isNotEmpty ||
    it.diffs.isNotEmpty ||
    isCommand(it) ||
    showsInput(it) ||
    showsRawOutput(it);

/// A labelled part of a tool call's body ("Input", "Output").
class ToolSection extends StatelessWidget {
  const new(this.label, this.child, {super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text(label, style: theme.ui(theme.t.textMuted, size: 11.5)),
        child,
      ],
    );
  }
}

/// Raw text from the agent (a call's input or output), in code type on a
/// raised box, folded to [folded] lines with "Show all" when longer.
class RawText extends StatefulWidget {
  const new(this.text, {super.key, this.folded = 4});

  final String text;
  final int folded;

  @override
  State<RawText> createState() => _RawTextState();
}

class _RawTextState extends State<RawText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = theme.code(t.text, size: 12).copyWith(height: 1.35);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: widget.folded,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: box.maxWidth);
          final folds = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: style,
                maxLines: _open || !folds ? null : widget.folded,
                overflow: _open || !folds ? null : TextOverflow.fade,
              ),
              if (folds)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: LinkText(
                    _open ? 'Show less' : 'Show all',
                    size: 12,
                    onTap: () => setState(() => _open = !_open),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A tool row's Preview: opens [path]'s preview, marked while it's the
/// one open. None without [Previews] above to open it.
class PreviewButton extends StatelessWidget {
  const new(this.path, {super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final previews = Previews.of(context);
    final open = previews?.open;
    if (open == null) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget pill({required bool on}) => Pressable(
      onTap: () => open(path),
      tooltip: [
        'Preview ${baseName(path)}',
        if (previews?.tabs ?? false) '⌘-click: in a tab',
      ].join('\n'),
      builder: (context, look) => Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: on
              ? t.accentSoft
              : look.hover
              ? t.hover
              : null,
          border: Border.all(color: on ? t.accent : t.fieldBorder),
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        foregroundDecoration: focusRing(t, look),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(Icons.visibility_outlined, size: 12, color: t.textSecondary),
            Text('Preview', style: theme.ui(t.text, size: 11.5)),
          ],
        ),
      ),
    );
    final current = previews?.current;
    return current == null
        ? pill(on: false)
        : ValueListenableBuilder(
            valueListenable: current,
            builder: (context, v, _) => pill(on: v == path),
          );
  }
}
