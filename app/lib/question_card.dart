import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// One question of a form: a field with options, or a text field, and the
/// free-text "Other" field that may follow it (Claude names it `<id>_custom`).
typedef _Question = ({Field field, Field? other});

/// The agent's question form, one question at a time as in Claude Code.
/// Several questions get a tab each (a check once answered) and a last
/// Submit tab that reviews the answers; ←/→ or Tab move between them.
/// Picking an option (a click or its digit) answers a one-choice question
/// and moves on; a many-choice one toggles with a click, its digit or Space,
/// and Enter moves on. ↑/↓ move through the options. A single question has
/// no tabs, and picking an option sends it at once.
class QuestionCard extends StatefulWidget {
  const QuestionCard(this.item, {super.key, required this.onAnswer});

  final Item item;

  /// Sends the answers, or null to decline.
  final Future<void> Function(List<FieldAnswer>? answer) onAnswer;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _picked = <String, List<String>>{}; // option ids by field id
  final _text = <String, TextEditingController>{}; // by field id
  final _focus = FocusNode();
  late final List<_Question> _qs = _questions(widget.item.fields);
  int _tab = 0; // the question shown; _qs.length is Submit
  int _at = 0; // the option ↑/↓ are on

  static List<_Question> _questions(List<Field> fields) {
    final out = <_Question>[];
    for (final f in fields) {
      final last = out.lastOrNull;
      if (f.options.isEmpty &&
          last != null &&
          f.id == '${last.field.id}_custom') {
        out.last = (field: last.field, other: f);
      } else {
        out.add((field: f, other: null));
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    for (final f in widget.item.fields) {
      if (f.options.isEmpty) {
        _text[f.id] = TextEditingController()
          ..addListener(() => setState(() {}));
      }
    }
    // The agent is waiting on this: take the keyboard from the composer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.item.status == 'pending') _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  bool get _many => _qs.length > 1;

  List<FieldAnswer> get _answer => [
    for (final f in widget.item.fields)
      if (_picked[f.id]?.isNotEmpty ?? false)
        FieldAnswer(fieldId: f.id, values: _picked[f.id])
      else if (_text[f.id]?.text.trim().isNotEmpty ?? false)
        FieldAnswer(fieldId: f.id, values: [_text[f.id]!.text.trim()]),
  ];

  /// The answer to [q] in words, or ''.
  String _said(_Question q) => [
    for (final id in _picked[q.field.id] ?? const <String>[])
      q.field.options.firstWhere((o) => o.id == id).name,
    for (final f in [q.field, ?q.other])
      if (_text[f.id]?.text.trim() case final s? when s.isNotEmpty) s,
  ].join(', ');

  void _go(int tab) => setState(() {
    _tab = tab.clamp(0, _many ? _qs.length : 0);
    _at = 0;
  });

  void _pick(int option) {
    final f = _qs[_tab].field;
    final id = f.options[option].id;
    final many = f.type == FieldType.FIELD_TYPE_CHOICES;
    setState(() {
      _at = option;
      final values = _picked[f.id] ??= [];
      if (many) {
        values.contains(id) ? values.remove(id) : values.add(id);
      } else {
        values
          ..clear()
          ..add(id);
      }
    });
    if (many) return;
    _many ? _go(_tab + 1) : _send(_answer);
  }

  Future<void> _send(List<FieldAnswer>? answer) =>
      tryOrShow(context, () => widget.onAnswer(answer));

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final onQuestion = _tab < _qs.length;
    final options = onQuestion ? _qs[_tab].field.options : <Option>[];
    final digit = int.tryParse(e.character ?? '') ?? 0;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (digit >= 1 && digit <= options.length && digit <= 9) {
      _pick(digit - 1);
    } else if (_many &&
        (k == LogicalKeyboardKey.arrowRight ||
            k == LogicalKeyboardKey.tab && !shift)) {
      _go(_tab + 1);
    } else if (_many &&
        (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.tab)) {
      _go(_tab - 1);
    } else if (options.isNotEmpty &&
        (k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowUp)) {
      setState(
        () => _at =
            (_at + (k == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            options.length,
      );
    } else if (options.isNotEmpty && k == LogicalKeyboardKey.space) {
      _pick(_at);
    } else if (k == LogicalKeyboardKey.enter) {
      final f = onQuestion ? _qs[_tab].field : null;
      if (f != null &&
          f.type != FieldType.FIELD_TYPE_CHOICES &&
          options.isNotEmpty &&
          _said(_qs[_tab]).isEmpty) {
        _pick(_at);
      } else if (_many && onQuestion) {
        _go(_tab + 1);
      } else if (_answer.isNotEmpty) {
        _send(_answer);
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final item = widget.item;
    if (item.status != 'pending') return _Answered(item);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: box(t.accent.withValues(alpha: 0.6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(Icons.help_outline, size: 15, color: t.accent),
                Expanded(
                  child: Text(
                    item.text.isEmpty ? 'Claude asks' : item.text,
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                ),
                Button(
                  label: 'Skip',
                  kind: ButtonKind.ghost,
                  height: 22,
                  onPressed: () => _send(null),
                ),
              ],
            ),
            if (_many)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final (i, q) in [..._qs, null].indexed)
                    Tap(
                      onTap: () {
                        _go(i);
                        _focus.requestFocus();
                      },
                      selected: i == _tab,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          if (q != null && _said(q).isNotEmpty)
                            Icon(Icons.check, size: 13, color: t.done),
                          Text(
                            q == null ? 'Submit' : q.field.title,
                            style: theme.ui(
                              i == _tab ? t.text : t.textSecondary,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (_tab < _qs.length)
              ..._question(theme, _qs[_tab])
            else
              ..._review(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _question(NushiTheme theme, _Question q) {
    final t = theme.t;
    final f = q.field;
    final picked = _picked[f.id] ?? const [];
    final many = f.type == FieldType.FIELD_TYPE_CHOICES;
    Widget field(Field f, String hint) => TextField(
      controller: _text[f.id],
      style: theme.ui(t.text),
      onSubmitted: (_) {
        _many
            ? _go(_tab + 1)
            : _answer.isNotEmpty
            ? _send(_answer)
            : null;
        _focus.requestFocus();
      },
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: t.base,
      ),
    );
    return [
      Text(
        f.description.isEmpty ? f.title : f.description,
        style: theme.ui(t.text),
      ),
      for (final (n, o) in f.options.indexed)
        Tap(
          onTap: () {
            _pick(n);
            _focus.requestFocus();
          },
          selected: n == _at,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            spacing: 8,
            children: [
              SizedBox(
                width: 12,
                child: n < 9 ? keyHint(context, '${n + 1}') : null,
              ),
              Icon(
                switch ((many, picked.contains(o.id))) {
                  (false, false) => Icons.radio_button_unchecked,
                  (false, true) => Icons.radio_button_checked,
                  (true, false) => Icons.check_box_outline_blank,
                  (true, true) => Icons.check_box,
                },
                size: 16,
                color: picked.contains(o.id) ? t.accent : t.textSecondary,
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: o.name,
                    style: theme.ui(t.text),
                    children: [
                      if (o.description.isNotEmpty)
                        TextSpan(
                          text: '  ${o.description}',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      if (f.options.isEmpty) field(f, f.title),
      if (q.other case final other?) field(other, '${other.title}…'),
      if (!_many && (many || f.options.isEmpty))
        Button(
          label: 'Submit',
          hint: '⏎',
          kind: ButtonKind.primary,
          onPressed: _answer.isEmpty ? null : () => _send(_answer),
        ),
    ];
  }

  List<Widget> _review(NushiTheme theme) {
    final t = theme.t;
    return [
      for (final q in _qs)
        Text.rich(
          TextSpan(
            text: '${q.field.title}   ',
            style: theme.ui(t.textMuted, size: 12.5),
            children: [
              if (_said(q) case final s when s.isNotEmpty)
                TextSpan(text: s, style: theme.ui(t.text, size: 12.5))
              else
                TextSpan(
                  text: 'Not answered',
                  style: theme.ui(t.needs, size: 12.5),
                ),
            ],
          ),
        ),
      Button(
        label: 'Submit',
        hint: '⏎',
        kind: ButtonKind.primary,
        onPressed: _answer.isEmpty ? null : () => _send(_answer),
      ),
    ];
  }
}

/// A question that is no longer waiting: what was answered.
class _Answered extends StatelessWidget {
  const _Answered(this.item);

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 12);
    final answered = item.fields.where((f) => f.values.isNotEmpty);
    return WaitingCard(
      waiting: false,
      children: [
        CardTitle(item.text, waiting: false),
        if (item.status != 'answered')
          Text(
            item.status == 'declined' ? 'Skipped' : 'Cancelled',
            style: muted,
          )
        else
          for (final f in answered)
            Text.rich(
              TextSpan(
                text: '${f.options.isEmpty ? f.title : f.description}  ',
                style: muted,
                children: [
                  TextSpan(
                    text: f.values
                        .map(
                          (v) =>
                              f.options
                                  .where((o) => o.id == v)
                                  .firstOrNull
                                  ?.name ??
                              v,
                        )
                        .join(', '),
                    style: theme.ui(theme.t.text, size: 12),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
