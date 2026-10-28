import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/question_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// One question of a form: a field with options, or a text field, and the
/// free-text "Other" field the daemon pairs with it, if any.
typedef _Question = ({Field field, Field? other});

/// The agent's question form, one question at a time as in Claude Code.
/// Several questions get a tab each (a check once answered) and a last
/// Submit tab that reviews the answers; ←/→ or Tab move between them.
/// Picking an option (a click or its digit) answers a one-choice question
/// and moves on; a many-choice one toggles with a click, its digit or Space,
/// and Enter moves on. ↑/↓ move through the options. A single question has
/// no tabs, and picking an option sends it at once.
class QuestionCard extends StatefulWidget {
  const new(
    this.item, {
    required this.agent,
    required this.onAnswer,
    this.draft,
    super.key,
  });

  final Item item;
  final String agent; // its name

  /// The answers so far, kept by the chat (ChatState.answers) so they
  /// outlive the card; its own when null.
  final QuestionDraft? draft;

  /// Sends the answers, or null to decline.
  final Future<void> Function(List<FieldAnswer>? answer) onAnswer;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late final QuestionDraft _draft = widget.draft ?? QuestionDraft();
  Map<String, List<String>> get _picked => _draft.picked; // by field id
  Map<String, TextEditingController> get _text => _draft.text;
  final _focus = FocusNode();
  late final List<_Question> _qs = _questions(widget.item.fields);
  int get _tab => _draft.tab; // the question shown; _qs.length is Submit
  set _tab(int v) => _draft.tab = v;
  int _at = 0; // the option ↑/↓ are on

  static List<_Question> _questions(List<Field> fields) {
    final out = <_Question>[];
    for (final f in fields) {
      if (f.otherFor.isNotEmpty && out.lastOrNull?.field.id == f.otherFor) {
        out.last = (field: out.last.field, other: f);
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
        (_text[f.id] ??= TextEditingController()).addListener(_typed);
      }
    }
    // The agent is waiting on this: take the keyboard, when nothing else
    // has a use for it (see _free).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.item.status == 'pending' && _free()) {
        _focus.requestFocus();
      }
    });
  }

  void _typed() => setState(() {});

  @override
  void dispose() {
    // The text outlives the card when the chat keeps it.
    for (final c in _text.values) {
      widget.draft == null ? c.dispose() : c.removeListener(_typed);
    }
    _focus.dispose();
    _sending.dispose();
    super.dispose();
  }

  /// Whether the card may take the keyboard: nothing has it, or an empty
  /// box on the same screen (the composer, waiting), or an earlier card.
  /// Never from text being written, a dialog, or anything else that takes
  /// keys (a terminal: Enter or a digit meant for it would answer).
  bool _free() {
    final focus = FocusManager.instance.primaryFocus;
    final at = focus?.context;
    if (focus == null || at == null || focus is FocusScopeNode) return true;
    if (ModalRoute.of(at) != ModalRoute.of(context)) return false;
    if (at.findAncestorStateOfType<_QuestionCardState>() != null) return true;
    final box = at.findAncestorWidgetOfExactType<EditableText>();
    return box != null && box.controller.text.isEmpty;
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

  /// Sends once at a time: a double click, or Enter twice, answers once.
  final Runner _sending = Runner();

  Future<void> _send(List<FieldAnswer>? answer) =>
      _sending.run(context, () => widget.onAnswer(answer));

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    // Keys typed into a box on the card (an "Other" answer) are its own.
    if (e is KeyUpEvent || !_focus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
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
        unawaited(_send(_answer));
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final item = widget.item;
    if (item.status != 'pending') return AnsweredQuestion(item);
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
                    item.text.isEmpty ? '${widget.agent} asks' : item.text,
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                ),
                RunButton(
                  label: 'Skip',
                  runner: _sending,
                  run: () => widget.onAnswer(null),
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
        if (_many) {
          _go(_tab + 1);
        } else if (_answer.isNotEmpty) {
          unawaited(_send(_answer));
        }
        _focus.requestFocus();
      },
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: t.base,
      ),
    );
    final about = f.description.isEmpty ? f.title : f.description;
    return [
      if (about.isNotEmpty) Text(about, style: theme.ui(t.text)),
      for (final (n, o) in f.options.indexed)
        QuestionOption(
          o,
          digit: n < 9 ? '${n + 1}' : null,
          many: many,
          picked: picked.contains(o.id),
          at: n == _at,
          onTap: () {
            _pick(n);
            _focus.requestFocus();
          },
        ),
      if (f.options.isEmpty) field(f, f.title),
      if (q.other case final other?) field(other, '${other.title}…'),
      if (!_many && (many || f.options.isEmpty))
        RunButton(
          label: 'Submit',
          hint: '⏎',
          kind: ButtonKind.primary,
          runner: _sending,
          run: _answer.isEmpty ? null : () => widget.onAnswer(_answer),
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
      RunButton(
        label: 'Submit',
        hint: '⏎',
        kind: ButtonKind.primary,
        runner: _sending,
        run: _answer.isEmpty ? null : () => widget.onAnswer(_answer),
      ),
    ];
  }
}
