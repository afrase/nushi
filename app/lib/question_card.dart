import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/cards.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/question_answered.dart';
import 'package:nushi/question_form.dart';
import 'package:nushi/question_parts.dart';
import 'package:nushi/question_pick_bar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/type_to_box.dart';
import 'package:nushi/widgets.dart';

part 'question_keys.dart';

/// The agent's question form, one question at a time as in Claude Code.
/// Several questions get a tab each (a check once answered) and a last
/// Submit tab that reviews the answers; ←/→ or Tab move between them.
/// A click picks and never sends: Return or Send does (on to the next
/// question, with several). A digit picks too, and with the box empty
/// sends a one-choice question's pick at once (or moves on). ↑/↓ move a
/// one-choice question's pick, from the box as well; a many-choice one's
/// go through its options and the box, Space toggling. A pick shows in a
/// bar under the box ([PickBar]), the box's text going with it; Esc or
/// its × unpicks, and the text is the answer itself. A character typed on
/// the card goes into the box (`docs/chats.md`).
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
  late final _form = QuestionForm(widget.item.fields, _draft);
  Map<String, List<String>> get _picked => _draft.picked; // by field id
  Map<String, TextEditingController> get _text => _draft.text;
  final _focus = FocusNode();
  List<AskedQuestion> get _qs => _form.questions;
  int get _tab => _draft.tab; // the question shown; _qs.length is Submit
  set _tab(int v) => _draft.tab = v;
  int _at = 0; // the option the keys are on: a many-choice question's

  /// The focus of the box under the question shown (see [_boxField]).
  late final FocusNode _box = FocusNode(onKeyEvent: _onBoxKey)
    ..addListener(_typed);

  /// What each box whose text takes the place of its question's pick
  /// (Field.replaces) listens with, so typing there unmarks the pick.
  final _unpickers = <TextEditingController, VoidCallback>{};

  /// The question shown, or null on the review.
  AskedQuestion? get _shown => _tab < _qs.length ? _qs[_tab] : null;

  /// The box ↑/↓ reach after a many-choice question's options and typing
  /// goes into: the question's "Other" field, or the field itself when it
  /// has no options; null on the review, or for a question without one.
  Field? get _boxField {
    final q = _shown;
    if (q == null) return null;
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
    for (final q in _qs) {
      if (q.other case final other? when _form.replaces(q)) {
        final c = _text[other.id]!;
        var last = c.text;
        void unpick() {
          // Text typed, not the caret moved nor text deleted (the greyed
          // text backspaced away, or cleared): the answer is the text now
          // (docs/facts/opencode.md).
          if (c.text == last) return;
          final deleted = QuestionForm.deleted(last, c.text);
          last = c.text;
          if (deleted || c.text.trim().isEmpty) return;
          if (_picked[q.field.id]?.isNotEmpty ?? false) {
            setState(() => _picked[q.field.id]!.clear());
          }
        }

        _unpickers[c] = unpick;
        c.addListener(unpick);
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

  /// [change] made, and the card drawn again (for `question_keys.dart`).
  void _redraw(VoidCallback change) => setState(change);

  @override
  void dispose() {
    // The text outlives the card: the chat keeps it.
    for (final c in _text.values) {
      c.removeListener(_typed);
    }
    _unpickers.forEach((c, unpick) => c.removeListener(unpick));
    _focus.dispose();
    _box
      ..removeListener(_typed)
      ..dispose();
    _sending.dispose();
    super.dispose();
  }

  /// Whether the card may take the keyboard: nothing has it, or an empty
  /// box on the same screen (the composer, waiting; an earlier card's), or
  /// an earlier card itself. Never from text being written (in an earlier
  /// card's box too), a dialog, or anything else that takes keys (a
  /// terminal: Enter or a digit meant for it would answer).
  bool _free() {
    final focus = FocusManager.instance.primaryFocus;
    final at = focus?.context;
    if (focus == null || at == null || focus is FocusScopeNode) return true;
    if (ModalRoute.of(at) != ModalRoute.of(context)) return false;
    final box = at.findAncestorWidgetOfExactType<EditableText>();
    if (box != null) return box.controller.text.isEmpty;
    return at.findAncestorStateOfType<_QuestionCardState>() != null;
  }

  bool get _many => _qs.length > 1;

  static bool _choices(AskedQuestion q) =>
      q.field.type == FieldType.FIELD_TYPE_CHOICES;

  void _go(int tab) => setState(() {
    _tab = tab.clamp(0, _many ? _qs.length : 0);
    _at = 0;
  });

  /// Sends once at a time: a double click, or Enter twice, answers once.
  final Runner _sending = Runner();

  Future<void> _send(List<FieldAnswer>? answer) =>
      _sending.run(context, () => widget.onAnswer(answer));

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
                          if (q != null && _form.said(q).isNotEmpty)
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
    final picked = _form.picks(q);
    final many = _choices(q);
    final answer = _form.answer;
    Widget field(Field f, String hint) => TextField(
      controller: _text[f.id],
      focusNode: f == _boxField ? _box : null,
      style: theme.ui(_form.dropped(f) ? t.textMuted : t.text),
      onSubmitted: (_) {
        _submit();
        _focus.requestFocus();
      },
      decoration: InputDecoration(
        hintText: hint,
        prefixText: _form.dropped(f) ? 'Not sent: ' : null,
        prefixStyle: theme.ui(t.textMuted),
        filled: true,
        fillColor: t.base,
      ),
    );
    final about = f.description.isEmpty ? f.title : f.description;
    // The pick quoted under the box, its text going along with it; with
    // one question the bar keeps its room unpicked, so Send never moves.
    final bar = _form.quotes(q)
        ? PickBar(
            label: PickBar.says([
              for (final id in picked)
                f.options.firstWhere((o) => o.id == id).name,
            ]),
            noted: _form.written(q),
            onClear: () {
              _unpick();
              _focus.requestFocus();
            },
          )
        : null;
    return [
      if (about.isNotEmpty) Text(about, style: theme.ui(t.text)),
      for (final (n, o) in f.options.indexed)
        QuestionOption(
          o,
          digit: n < 9 ? '${n + 1}' : null,
          many: many,
          picked: picked.contains(o.id),
          at: (many ? n == _at : picked.contains(o.id)) && !_box.hasFocus,
          dimmed: _form.dims(q),
          onTap: () {
            _pick(n, toggle: true);
            _focus.requestFocus();
          },
        ),
      if (f.options.isEmpty) field(f, f.title),
      if (q.other case final other?)
        field(other, switch ((_form.replaces(q), picked.length)) {
          (true, > 0) => 'Type your own answer in place of your pick…',
          (true, _) => 'Type your own answer…',
          (_, 1) => 'Add context for this pick…',
          (_, > 1) => 'Add context for these picks…',
          _ => '${other.title}…',
        }),
      if (!_many)
        PickFoot(
          bar: bar,
          shown: picked.isNotEmpty,
          send: RunButton(
            label: 'Send',
            hint: enterLabel,
            kind: ButtonKind.primary,
            runner: _sending,
            run: answer.isEmpty ? null : () => widget.onAnswer(answer),
          ),
        )
      else if (bar != null && picked.isNotEmpty)
        bar,
    ];
  }

  List<Widget> _review(NushiTheme theme) => [
    for (final q in _qs) reviewLine(theme, q.field.title, _form.answered(q)),
    RunButton(
      label: 'Submit',
      hint: enterLabel,
      kind: ButtonKind.primary,
      runner: _sending,
      run: _form.answer.isEmpty ? null : () => widget.onAnswer(_form.answer),
    ),
  ];
}
