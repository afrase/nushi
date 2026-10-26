import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/findings.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A code review's findings in the transcript: a header ("Review: 5
/// findings · medium"), then a row for each, most severe first as the
/// agent gave them: its file and line (the last two segments; whole on
/// hover), its short summary (else its summary) and its category. A row
/// opens to its summary and how it fails; ↑↓ move between rows and ⏎
/// opens one. A file inside the chat's folder opens in its Changes; one
/// outside shows, but doesn't open. [json] is the text the findings were
/// read from, if they came as text: "Show JSON" shows it instead.
///
/// It's the agent's text: shown as text, with `code` spans in the code
/// font, never as markup or links.
class FindingsCard extends StatefulWidget {
  const new(this.findings, this.chat, {super.key, this.json});

  final Findings findings;
  final ChatState chat;
  final String? json;

  @override
  State<FindingsCard> createState() => _FindingsCardState();
}

class _FindingsCardState extends State<FindingsCard> {
  final _focus = FocusNode();
  bool _focused = false;
  int _at = 0; // the row the keys move
  final _open = <String>{}; // the rows open, by finding id
  bool _json = false; // the text it was read from shows instead

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggle(String id) =>
      setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  KeyEventResult _key(List<String> ids, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent || ids.isEmpty || _json) {
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _at = min(_at + 1, ids.length - 1));
      case LogicalKeyboardKey.arrowUp:
        setState(() => _at = max(_at - 1, 0));
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _toggle(ids[min(_at, ids.length - 1)]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final items = widget.findings.items;
    final ids = findingIds(items);
    final n = items.length;
    final level = widget.findings.level;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.fact_check_outlined, size: 15, color: t.findingsAccent),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: switch (n) {
                      0 => 'Review: no findings',
                      1 => 'Review: 1 finding',
                      _ => 'Review: $n findings',
                    },
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                  if (level.isNotEmpty)
                    TextSpan(
                      text: ' · $level',
                      style: theme.ui(t.textMuted, size: 12.5),
                    ),
                ],
              ),
            ),
          ),
          if (widget.json != null)
            Button(
              label: _json ? 'Hide JSON' : 'Show JSON',
              onPressed: () => setState(() => _json = !_json),
            ),
        ],
      ),
    );
    final rule = BorderSide(color: t.findingsBorder);
    return Focus(
      focusNode: _focus,
      onFocusChange: (on) => setState(() => _focused = on),
      onKeyEvent: (_, e) => _key(ids, e),
      child: framed(
        border: t.findingsBorder,
        fill: t.findingsTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (_json)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                decoration: BoxDecoration(border: Border(top: rule)),
                child: AgentMarkdown(widget.json!),
              )
            else
              for (final (i, f) in items.indexed)
                DecoratedBox(
                  key: ValueKey(ids[i]),
                  decoration: BoxDecoration(border: Border(top: rule)),
                  child: _row(i, f, ids[i]),
                ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i, Finding f, String id) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final open = _open.contains(id);
    final path = findingPath(widget.chat.folder, f.file);
    final line = f.line > 0 ? ':${f.line}' : '';
    final style = theme.code(
      path == null ? t.textMuted : t.findingsAccent,
      size: 12,
    );
    final where = Tap(
      onTap: path == null ? null : () => _show(path, f.line),
      tooltip: path == null
          ? '${f.file}$line: outside the chat’s folder'
          : '${f.file}$line',
      // The line stays when a long path is cut.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              shortPath(f.file),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text(line, style: style),
        ],
      ),
    );
    final body = theme.ui(t.agentText);
    final short = f.shortSummary.isNotEmpty ? f.shortSummary : f.summary;
    return Tap(
      onTap: () {
        _at = i;
        _toggle(id);
        _focus.requestFocus();
      },
      selected: _focused && i == _at,
      radius: 0,
      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Chevron(open: open),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: where,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _withCode(short, body)),
                  maxLines: open ? null : 2,
                  overflow: open ? null : TextOverflow.ellipsis,
                ),
              ),
              for (final c in [f.category, f.outcome.replaceAll('_', ' ')])
                if (c.isNotEmpty) _chip(c),
            ],
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  if (f.shortSummary.isNotEmpty)
                    Text.rich(TextSpan(children: _withCode(f.summary, body))),
                  if (f.failureScenario.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'How it fails: ',
                            style: theme.ui(
                              t.textSecondary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          ..._withCode(f.failureScenario, body),
                        ],
                      ),
                    ),
                  if (f.verdict.isNotEmpty)
                    Text(
                      f.verdict == 'CONFIRMED'
                          ? 'Confirmed by a check'
                          : 'Plausible: a check couldn’t confirm it',
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Shows [path] at [line] in the chat's Changes, where the folder's
  /// text is: Commits shows what a commit made, so Uncommitted then.
  void _show(String path, int line) {
    final chat = widget.chat;
    if (chat.scope == Scope.commits.name) chat.scope = Scope.uncommitted.name;
    chat.showFile(path, line: line);
  }

  Widget _chip(String text) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: box(t.findingsBorder, radius: NushiTheme.control),
      child: Text(text, style: theme.ui(t.textSecondary, size: 11.5)),
    );
  }

  /// [text] with its `code` spans in the code font: the only markup a
  /// finding's text gets.
  List<InlineSpan> _withCode(String text, TextStyle body) {
    final theme = NushiTheme.of(context);
    final code = theme
        .code(theme.t.agentText, size: 12)
        .copyWith(backgroundColor: theme.t.inlineCode);
    final parts = text.split('`');
    return [
      for (final (i, p) in parts.indexed)
        if (p.isNotEmpty)
          TextSpan(
            // An odd part is between backticks, unless it's the last
            // (a backtick never closed).
            text: i.isOdd && i < parts.length - 1 ? p : (i.isOdd ? '`$p' : p),
            style: i.isOdd && i < parts.length - 1 ? code : body,
          ),
    ];
  }
}

/// Findings a message repeats as JSON that a card above already shows:
/// one line saying so, the JSON behind "Show JSON".
class FindingsAgain extends StatefulWidget {
  const new(this.json, {super.key});

  final String json;

  @override
  State<FindingsAgain> createState() => _FindingsAgainState();
}

class _FindingsAgainState extends State<FindingsAgain> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'The findings above, again as JSON',
              style: theme.ui(t.textMuted, size: 12),
            ),
            const SizedBox(width: 6),
            Button(
              label: _open ? 'Hide JSON' : 'Show JSON',
              onPressed: () => setState(() => _open = !_open),
            ),
          ],
        ),
        if (_open) AgentMarkdown(widget.json),
      ],
    );
  }
}
