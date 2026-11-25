import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/cards.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/question_answered.dart';
import 'package:nushi/question_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/type_to_box.dart';
import 'package:nushi/widgets.dart';

/// The agent's question form, one question at a time as in Claude Code.
/// Several questions get a tab each (a check once answered) and a last
/// Submit tab that reviews the answers; ←/→ or Tab move between them.
/// Picking an option (a click or its digit) answers a one-choice question
/// and moves on; a many-choice one toggles with a click, its digit or Space,
/// and Enter moves on. ↑/↓ move through the options and the box under
/// them as one list, and a character typed on the card (not a digit that
/// picks) goes into the box; Esc there gives the keys back to the card,
/// the text kept. A single question has no tabs, and picking an option
/// sends it at once.
class QuestionCard extends StatefulWidget {
  const new(
    this.item, {
    required this.agent,
    required this.onAnswer,
    required this.draft,
    super.key,
  });

  final Item item;
  final String agent; // its name

  /// The answers so far, kept by the chat (ChatState.answers) so they
  /// outlive the card.
  final QuestionDraft draft;

  /// Sends the answers, or null to decline.
  final Future<void> Function(List<FieldAnswer>? answer) onAnswer;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late final QuestionDraft _draft = widget.draft;
  Map<String, List<String>> get _picked => _draft.picked; // by field id
  Map<String, TextEditingController> get _text => _draft.text;
  final _focus = FocusNode();
  late final List<AskedQuestion> _qs = askedQuestions(widget.item.fields);
  int get _tab => _draft.tab; // the question shown; _qs.length is Submit
  set _tab(int v) => _draft.tab = v;
  int _at = 0; // the option ↑/↓ are on

  /// The focus of the box under the question shown (see [_boxField]).
  late final FocusNode _box = FocusNode(onKeyEvent: _onBoxKey)
    ..addListener(_typed);

  /// The box ↑/↓ reach after the options and typing goes into: the
  /// question's "Other" field, or the field itself when it has no options;
  /// null on the review, or for a question without one.
  Field? get _boxField {
    if (_tab >= _qs.length) return null;
    final q = _qs[_tab];
    return q.other ?? (q.field.options.isEmpty ? q.field : null);
  }

  /// Puts the keys in the box, [typed] after its text and the caret at its
  /// end, as type to write does for the chat's box (`type_to_box.dart`).
  void _toBox([String typed = '']) {
    final c = _text[_boxField!.id]!;
    final text = '${c.text}$typed';
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _box.requestFocus();
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
    // The text outlives the card: the chat keeps it.
    for (final c in _text.values) {
      c.removeListener(_typed);
    }
    _focus.dispose();
    _box
      ..removeListener(_typed)
      ..dispose();
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
  String _said(AskedQuestion q) => [
    _answered(q).answer,
    _answered(q).note,
  ].where((s) => s.isNotEmpty).join(', ');

  /// The answer to [q] in words and the note on its pick, each or ''.
  /// The box's text is a note where the agent reads it so (Field.note)
  /// and an option is picked; otherwise it's one more answer.
  ({String answer, String note}) _answered(AskedQuestion q) {
    String typed(Field f) => _text[f.id]?.text.trim() ?? '';
    final picks = [
      for (final id in _picked[q.field.id] ?? const <String>[])
        q.field.options.firstWhere((o) => o.id == id).name,
    ];
    final note = _notes(q) ? typed(q.other!) : '';
    return (
      answer: [
        ...picks,
        for (final f in [q.field, if (note.isEmpty) ?q.other])
          if (typed(f) case final s when s.isNotEmpty) s,
      ].join(', '),
      note: note,
    );
  }

  /// Whether [q]'s box holds a note on its pick: the agent reads it so
  /// and an option is picked.
  bool _notes(AskedQuestion q) =>
      (q.other?.note ?? false) && (_picked[q.field.id]?.isNotEmpty ?? false);

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
    // ⌃Tab and ⌃⇧Tab go on to the chat's tabs (`chat_keys.dart`).
    final tab =
        k == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isControlPressed;
    if (digit >= 1 && digit <= options.length && digit <= 9) {
      _pick(digit - 1);
    } else if (_many && (k == LogicalKeyboardKey.arrowRight || tab && !shift)) {
      _go(_tab + 1);
    } else if (_many && (k == LogicalKeyboardKey.arrowLeft || tab)) {
      _go(_tab - 1);
    } else if (options.isNotEmpty &&
        (k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowUp)) {
      final down = k == LogicalKeyboardKey.arrowDown;
      // The box is the list's last entry, between the last option and
      // the first.
      if (_boxField != null && _at == (down ? options.length - 1 : 0)) {
        _toBox();
      } else {
        setState(() => _at = (_at + (down ? 1 : -1)) % options.length);
      }
    } else if (options.isNotEmpty && k == LogicalKeyboardKey.space) {
      _pick(_at);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
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
    } else if (typedCharacter(e) case final c? when _boxField != null) {
      _toBox(c); // a digit no option has too
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The box's own keys, before its text's: ↑ to the last option, ↓ to the
  /// first, and Esc back to the card, the text kept.
  KeyEventResult _onBoxKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final options = _tab < _qs.length ? _qs[_tab].field.options : <Option>[];
    if (k == LogicalKeyboardKey.escape) {
      _focus.requestFocus();
    } else if (options.isNotEmpty &&
        (k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown)) {
      setState(
        () => _at = k == LogicalKeyboardKey.arrowUp ? options.length - 1 : 0,
      );
      _focus.requestFocus();
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
    // Answered, it settles into its answered lines (SettleCard), which
    // open to every option it offered when it kept them.
    if (item.status != 'pending') {
      if (AnsweredQuestion.opens(item)) {
        return SettleCard(
          state: false,
          decoration: cardBox(t),
          padding: AnsweredQuestion.padding,
          child: AnsweredQuestion(item),
        );
      }
      return SettleCard(
        state: false,
        decoration: cardBox(t),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: answeredLines(context, item),
        ),
      );
    }
    return SettleCard(
      state: true,
      decoration: cardBox(t),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(Icons.help_outline, size: 15, color: t.accentInk),
                Expanded(
                  child: Text(
                    item.text.isEmpty ? '${widget.agent} asks' : item.text,
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                ),
                const NeedsYou(),
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

  List<Widget> _question(NushiTheme theme, AskedQuestion q) {
    final t = theme.t;
    final f = q.field;
    final picked = _picked[f.id] ?? const [];
    final many = f.type == FieldType.FIELD_TYPE_CHOICES;
    Widget field(Field f, String hint, {bool note = false}) => TextField(
      controller: _text[f.id],
      focusNode: f == _boxField ? _box : null,
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
        // A note being written stays labelled once its placeholder goes.
        prefixText: note && _text[f.id]!.text.isNotEmpty ? 'Note: ' : null,
        prefixStyle: theme.ui(t.textMuted),
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
          at: n == _at && !_box.hasFocus,
          onTap: () {
            _pick(n);
            _focus.requestFocus();
          },
        ),
      if (f.options.isEmpty) field(f, f.title),
      if (q.other case final other?)
        field(
          other,
          _notes(q) ? 'Add a note…' : '${other.title}…',
          note: _notes(q),
        ),
      if (!_many && (many || f.options.isEmpty))
        RunButton(
          label: 'Submit',
          hint: enterLabel,
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
            style: theme.ui(t.textMuted, size: 12),
            children: [
              if (_answered(q) case (:final answer, :final note)
                  when answer.isNotEmpty || note.isNotEmpty) ...[
                TextSpan(text: answer, style: theme.ui(t.text, size: 12)),
                if (note.isNotEmpty) ...[
                  const TextSpan(text: '  '),
                  ...noteSpans(theme, note, size: 12),
                ],
              ] else
                TextSpan(
                  text: 'Not answered',
                  style: theme.ui(t.needs, size: 12),
                ),
            ],
          ),
        ),
      RunButton(
        label: 'Submit',
        hint: enterLabel,
        kind: ButtonKind.primary,
        runner: _sending,
        run: _answer.isEmpty ? null : () => widget.onAnswer(_answer),
      ),
    ];
  }
}
