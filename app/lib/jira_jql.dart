import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

/// What the word being typed in JQL is: a field, an operator after one, a
/// value of [field], or a keyword after a value.
enum JqlSlot { field, operator, value, keyword }

const _ops = {
  '=',
  '!=',
  '~',
  '!~',
  '>',
  '>=',
  '<',
  '<=',
  'in',
  'is',
  'was',
  'not',
};
const _joins = {'and', 'or', 'not', '('};

/// The word at the end of [before] (the JQL before the caret): what it
/// is, the field it belongs to, what's typed of it, and where it starts.
({JqlSlot slot, String field, String prefix, int start}) jqlWord(
  String before,
) {
  final all = [
    for (final m in RegExp(
      r'"(?:[^"\\]|\\.)*"?|!=|>=|<=|!~|[=~<>(),]|[^\s=~<>!(),"]+',
    ).allMatches(before))
      (text: m.group(0)!, start: m.start),
  ];
  final typing =
      all.isNotEmpty &&
      all.last.start + all.last.text.length == before.length &&
      !const {
        '(',
        ')',
        ',',
        '=',
        '!=',
        '~',
        '!~',
        '>',
        '>=',
        '<',
        '<=',
      }.contains(all.last.text);
  final prefix = typing ? all.last.text : '';
  final start = typing ? all.last.start : before.length;
  final done = [
    for (final t in typing ? all.sublist(0, all.length - 1) : all)
      t.text.toLowerCase(),
  ];
  final words = [
    for (final t in typing ? all.sublist(0, all.length - 1) : all) t.text,
  ];
  ({JqlSlot slot, String field, String prefix, int start}) of(
    JqlSlot slot, [
    String field = '',
  ]) => (slot: slot, field: field, prefix: prefix, start: start);
  // The field before the operator that ends at i ("not in": two words).
  String fieldBefore(int i) {
    var j = i;
    while (j >= 0 && _ops.contains(done[j])) {
      j--;
    }
    return j >= 0 ? words[j] : '';
  }

  final last = done.isEmpty ? '' : done.last;
  final open = done.lastIndexOf('(');
  final inList =
      open > 0 &&
      !done.sublist(open).contains(')') &&
      _ops.contains(done[open - 1]);
  if (inList && (last == '(' || last == ',')) {
    return of(JqlSlot.value, fieldBefore(open - 1));
  }
  if (last == 'order') return of(JqlSlot.keyword);
  if (done.isEmpty ||
      _joins.contains(last) && last != 'not' ||
      last == 'by' ||
      last == ',') {
    return of(JqlSlot.field);
  }
  if (_ops.contains(last)) {
    return of(JqlSlot.value, fieldBefore(done.length - 1));
  }
  final prev = done.length > 1 ? done[done.length - 2] : '';
  if (done.length == 1 ||
      _joins.contains(prev) ||
      prev == 'by' ||
      prev == ',') {
    return of(JqlSlot.operator, words.last);
  }
  return of(JqlSlot.keyword);
}

/// A JQL field that autocompletes from the site's own fields, functions
/// and values (asked of Jira as you type a value). Enter runs it, unless a
/// suggestion is picked (↑↓); Tab takes the picked or first one.
class JqlField extends StatefulWidget {
  const new({
    required this.client,
    required this.site,
    required this.controller,
    required this.onRun,
    super.key,
    this.focusNode,
  });

  final NushiServiceClient client;
  final String site;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final void Function(String jql) onRun;

  @override
  State<JqlField> createState() => _JqlFieldState();
}

class _JqlFieldState extends State<JqlField> {
  GetJiraJqlResponse? _jql;
  List<({String insert, String label})> _shown = const [];
  int _picked = -1;
  Timer? _ask;
  int _asked = 0; // the latest value request, so older answers drop
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.client
          .getJiraJql(GetJiraJqlRequest(site: widget.site))
          .then((r) => _jql = r, onError: (_) {}), // no autocompletion then
    );
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _ask?.cancel();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _show(List<({String insert, String label})> s) {
    if (!mounted) return;
    setState(() {
      _shown = s.take(8).toList();
      _picked = -1;
    });
  }

  void _changed() {
    final c = widget.controller;
    final caret = c.selection.isValid ? c.selection.baseOffset : c.text.length;
    final w = jqlWord(c.text.substring(0, caret.clamp(0, c.text.length)));
    final p = w.prefix.toLowerCase().replaceAll('"', '');
    bool starts(String s) => s.toLowerCase().replaceAll('"', '').startsWith(p);
    final jql = _jql;
    _ask?.cancel();
    switch (w.slot) {
      case JqlSlot.field:
        _show([
          for (final f in jql?.fields ?? <JiraJqlField>[])
            if (p.isNotEmpty && starts(f.name))
              (insert: f.name, label: f.display),
        ]);
      case JqlSlot.operator:
        final f = jql?.fields.where(
          (f) => f.name.toLowerCase() == w.field.toLowerCase(),
        );
        _show([
          for (final op
              in f == null || f.isEmpty
                  ? const ['=', '!=', '~', 'in', 'is']
                  : f.first.operators)
            if (starts(op)) (insert: op, label: op),
        ]);
      case JqlSlot.keyword:
        _show([
          for (final k in const ['AND', 'OR', 'ORDER BY', 'NOT', 'ASC', 'DESC'])
            if (p.isNotEmpty && starts(k)) (insert: k, label: k),
        ]);
      case JqlSlot.value:
        final functions = [
          for (final f in jql?.functions ?? <String>[])
            if (p.isNotEmpty && starts(f)) (insert: f, label: f),
        ];
        final n = ++_asked;
        _ask = Timer(const Duration(milliseconds: 200), () async {
          try {
            final r = await widget.client.suggestJiraJql(
              SuggestJiraJqlRequest(
                site: widget.site,
                fieldName: w.field,
                prefix: w.prefix.replaceAll('"', ''),
              ),
            );
            if (n == _asked) {
              _show([
                for (final v in r.values) (insert: v.id, label: v.name),
                ...functions,
              ]);
            }
          } on Object {
            if (n == _asked) _show(functions);
          }
        });
    }
  }

  /// Puts suggestion [i] in place of the word being typed.
  void _take(int i) {
    final c = widget.controller;
    final caret = c.selection.isValid ? c.selection.baseOffset : c.text.length;
    final w = jqlWord(c.text.substring(0, caret));
    final insert = '${_shown[i].insert} ';
    final text = c.text.replaceRange(w.start, caret, insert);
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: w.start + insert.length),
    );
    _show(const []);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (_shown.isNotEmpty &&
        (k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowUp)) {
      final step = k == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() => _picked = (_picked + step).clamp(-1, _shown.length - 1));
      return KeyEventResult.handled;
    }
    if (_shown.isNotEmpty && k == LogicalKeyboardKey.tab) {
      _take(_picked < 0 ? 0 : _picked);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter) {
      if (_picked >= 0) {
        _take(_picked);
      } else {
        _show(const []);
        widget.onRun(widget.controller.text.trim());
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && _shown.isNotEmpty) {
      _show(const []);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          onKeyEvent: _key,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            style: theme.code(t.text, size: 12),
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              hintText:
                  'project = ABC AND status != Done ORDER BY updated DESC',
            ),
          ),
        ),
        if (_shown.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: box(t.borderSubtle, fill: t.raised),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in _shown.indexed)
                  GestureDetector(
                    onTap: () => _take(i),
                    child: Container(
                      color: i == _picked ? t.selected : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Row(
                        children: [
                          Text(s.insert, style: theme.code(t.text, size: 12)),
                          if (s.label != s.insert &&
                              s.label != s.insert.replaceAll('"', '')) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.ui(t.textMuted, size: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
