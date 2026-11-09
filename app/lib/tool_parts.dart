/// A tool row's parts: its title, its body's input and output, and its
/// Preview button.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/browser_address.dart' show isWebPage;
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart' show openInBrowserOrSay;
import 'package:nushi/web_views.dart' show webEmbedded;
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
String? showPath(Item it) => isShow(it) ? _argument(it, 'path') : null;

/// The page a show call names (ADR 0100), as [showPath] its file: `url`.
/// The daemon refused any but a page on this Mac's loopback.
String? showUrl(Item it) => isShow(it) ? _argument(it, 'url') : null;

/// A string argument of a call to one of Nushi's tools, from its input
/// (inside `arguments` on Codex), its unprintable characters marked; null
/// when it hasn't come, was cut short, or is empty.
String? _argument(Item it, String key) {
  if (it.input.isEmpty) return null;
  try {
    final input = jsonDecode(it.input);
    final args = input is Map ? input['arguments'] ?? input : null;
    final value = args is Map ? args[key] : null;
    return value is String && value.isNotEmpty ? plainPath(value) : null;
  } on FormatException {
    return null;
  }
}

/// What the rows and cards of Nushi's dev server tools (ADR 0100) say,
/// by tool: done, doing, and asked to do or failed. Each but the list's is
/// followed by the entry's name.
const serverVerbs = {
  'preview_list': ('Listed servers', 'Listing servers', 'List servers'),
  'preview_start': ('Started', 'Starting', 'Start'),
  'preview_stop': ('Stopped', 'Stopping', 'Stop'),
  'preview_logs': (
    'Read the logs of',
    'Reading the logs of',
    'Read the logs of',
  ),
};

/// Which of Nushi's dev server tools [it] calls, or asks to ('preview_start'),
/// titled as Claude's agents (`mcp__nushi__preview_start`) and Codex's
/// adapter (`mcp.nushi.preview_start`) title them; null for any other.
String? serverTool(Item it) {
  final title = it.title;
  final tool = title.startsWith('mcp__nushi__')
      ? title.substring(12)
      : title.startsWith('mcp.nushi.')
      ? title.substring(10)
      : null;
  return serverVerbs.containsKey(tool) ? tool : null;
}

/// What a call to a dev server tool did, does or failed to do, by its
/// status ([serverVerbs]); null for another call.
String? serverVerb(Item it) => switch (serverVerbs[serverTool(it)]) {
  null => null,
  (final did, final doing, final tried) => switch (it.status) {
    'failed' => tried,
    'pending' || 'in_progress' => doing,
    _ => did,
  },
};

/// A dev server tool's result to show as written, never as Markdown (a
/// server's lines would run together, `__init__` turn bold): its text, or
/// what's inside the fence claude-acp-go puts around a failure's.
String serverOutput(String text) {
  final whole = _wholeFence.firstMatch(text.trim());
  return whole == null ? text : whole[2]!;
}

final _wholeFence = RegExp(r'^(`{3,})[^`\n]*\n([\s\S]*?)\n\1$');

/// The entry a call to a dev server tool names: its `name`.
String? serverName(Item it) =>
    serverTool(it) == null ? null : _argument(it, 'name');

final _unprintable = RegExp(
  '[\x00-\x1f\x7f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]',
);

/// [path], an agent's, with what could make it read as something else
/// (new lines, bidi controls) marked. It only names the file: the daemon
/// checks whatever the app asks for.
String plainPath(String path) => path.replaceAll(_unprintable, '�');

/// A tool call's title: the agent's, but an MCP call titled with its raw
/// name reads "server · tool", and "· inner" when its input names the tool
/// it runs (a gateway's `tool`, `tool_name` or `name`).
String toolTitle(Item it) {
  if (isShow(it)) return 'Showing a file';
  if (serverVerb(it) case final verb?) {
    // A name yet to come (or the list's, which names none).
    return serverTool(it) == 'preview_list' ? verb : '$verb a server';
  }
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
    it.toolKind == 'execute' &&
    it.title.isNotEmpty &&
    !isShow(it) &&
    serverTool(it) == null;

/// Whether a call's input shows: it has one and no diff or command says
/// what it did, and either nothing else shows or it's a tool ACP has no kind
/// for (an MCP tool's), whose content is only its result. A show call's
/// title says its input, as a dev server tool's does.
bool showsInput(Item it) =>
    it.input.isNotEmpty &&
    !isShow(it) &&
    serverTool(it) == null &&
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
/// raised box, folded to [folded] lines ([FoldedText]).
class RawText extends StatelessWidget {
  const new(this.text, {super.key, this.folded = 4});

  final String text;
  final int folded;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Marks(
        child: FoldedText(
          text,
          style: theme.code(t.text, size: 12).copyWith(height: 1.35),
          folded: folded,
          padding: const EdgeInsets.only(top: 2),
        ),
      ),
    );
  }
}

/// [text] folded to [folded] lines, with "Show all" under it when it's
/// longer, and "Show less" once it's open; [padding] is the link's.
class FoldedText extends StatefulWidget {
  const new(
    this.text, {
    required this.style,
    required this.folded,
    required this.padding,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int folded;
  final EdgeInsets padding;

  @override
  State<FoldedText> createState() => _FoldedTextState();
}

class _FoldedTextState extends State<FoldedText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
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
            style: widget.style,
            maxLines: _open || !folds ? null : widget.folded,
            overflow: _open || !folds ? null : TextOverflow.fade,
          ),
          if (folds)
            Padding(
              padding: widget.padding,
              child: LinkText(
                _open ? 'Show less' : 'Show all',
                size: 12,
                onTap: () => setState(() => _open = !_open),
              ),
            ),
        ],
      );
    },
  );
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
    Widget pill({required bool on}) => _Pill(
      label: 'Preview',
      icon: Icons.visibility_outlined,
      tooltip: 'Preview ${baseName(path)}',
      onTap: () => open(path),
      on: on,
    );
    final current = previews?.current;
    final name = previews?.name ?? (p) => p;
    return current == null
        ? pill(on: false)
        : ValueListenableBuilder(
            valueListenable: current,
            builder: (context, v, _) =>
                pill(on: v is PreviewFile && name(v.path) == name(path)),
          );
  }
}

/// A show call's Open (ADR 0100): opens [url], a page on this Mac, in a
/// browser tab beside the chat, or without the app's own web views (Linux,
/// ADR 0104) in the default browser, as the user's click asks. None without
/// [Previews.browse] (the phone, whose loopback isn't the Mac's), nor for
/// what a tab wouldn't show (`isWebPage`: a file, a user name), whichever
/// opens it: [url] is the agent's own argument, not the daemon's checked
/// address.
class OpenPageButton extends StatelessWidget {
  const new(this.url, {super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final browse = Previews.of(context)?.browse;
    final at = Uri.tryParse(url);
    if (browse == null || at == null || !isWebPage(at)) {
      return const SizedBox.shrink();
    }
    return _Pill(
      label: 'Open',
      icon: Icons.open_in_browser,
      tooltip: 'Open $url',
      onTap: () =>
          webEmbedded ? browse(at) : openInBrowserOrSay(context, at).ignore(),
    );
  }
}

/// A tool row's small button: [icon] and [label] in a box, filled while
/// [on].
class _Pill extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.on = false,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Pressable(
      onTap: onTap,
      tooltip: tooltip,
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
            Icon(icon, size: 12, color: t.textSecondary),
            Text(label, style: theme.ui(t.text, size: 11.5)),
          ],
        ),
      ),
    );
  }
}
