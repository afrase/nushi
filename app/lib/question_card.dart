import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The agent's question form: each field with its options (a radio for one,
/// checkboxes for several) or a text box, under one Submit. Digits 1–9 pick
/// an option of the active question, Enter submits once something is
/// answered, and Skip declines.
class QuestionCard extends StatefulWidget {
  const QuestionCard(this.item, {super.key, required this.onAnswer});

  final Item item;

  /// Sends the answer by field id, or null to decline.
  final Future<void> Function(List<FieldAnswer>? answer) onAnswer;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _picked = <String, List<String>>{};
  final _text = <String, TextEditingController>{};
  final _focus = FocusNode();
  int _active = 0; // the field the digit keys pick in

  List<Field> get _fields => widget.item.fields;

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      if (f.options.isEmpty) _text[f.id] = TextEditingController();
    }
    _active = _fields.indexWhere((f) => f.options.isNotEmpty).clamp(0, 99);
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

  List<FieldAnswer> get _answer => [
    for (final f in _fields)
      if (_picked[f.id]?.isNotEmpty ?? false)
        FieldAnswer(fieldId: f.id, values: _picked[f.id])
      else if (_text[f.id]?.text.trim().isNotEmpty ?? false)
        FieldAnswer(fieldId: f.id, values: [_text[f.id]!.text.trim()]),
  ];

  void _pick(int field, String option) {
    final f = _fields[field];
    setState(() {
      _active = field;
      final values = _picked[f.id] ?? [];
      if (values.contains(option)) {
        values.remove(option);
      } else if (f.type == FieldType.FIELD_TYPE_CHOICES) {
        values.add(option);
      } else {
        values
          ..clear()
          ..add(option);
      }
      _picked[f.id] = values;
    });
  }

  Future<void> _send(List<FieldAnswer>? answer) =>
      tryOrShow(context, () => widget.onAnswer(answer));

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final digit = int.tryParse(e.character ?? '');
    final options = _fields.isEmpty ? <Option>[] : _fields[_active].options;
    if (digit != null && digit >= 1 && digit <= options.length) {
      _pick(_active, options[digit - 1].id);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter && _answer.isNotEmpty) {
      _send(_answer);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final item = widget.item;
    if (item.status != 'pending') return _Answered(item);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: WaitingCard(
        waiting: true,
        children: [
          CardTitle(item.text.isEmpty ? 'The agent asks' : item.text),
          for (final (i, f) in _fields.indexed) ..._field(theme, i, f),
          Row(
            spacing: 6,
            children: [
              Button(
                label: 'Submit',
                hint: '⏎',
                kind: ButtonKind.primary,
                onPressed: _answer.isEmpty ? null : () => _send(_answer),
              ),
              Button(label: 'Skip', onPressed: () => _send(null)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _field(NushiTheme theme, int i, Field f) {
    final t = theme.t;
    final active = i == _active && f.options.isNotEmpty;
    if (f.options.isEmpty) {
      return [
        TextField(
          controller: _text[f.id],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _answer.isEmpty ? null : _send(_answer),
          style: theme.ui(t.text),
          decoration: InputDecoration(
            labelText: f.title,
            hintText: f.description,
            filled: true,
            fillColor: t.base,
          ),
        ),
      ];
    }
    final picked = _picked[f.id] ?? const [];
    final many = f.type == FieldType.FIELD_TYPE_CHOICES;
    return [
      const SizedBox(height: 4),
      Row(
        spacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: box(
              active ? t.needs : t.borderStrong,
              radius: NushiTheme.control,
            ),
            child: Text(f.title, style: theme.ui(t.textSecondary, size: 11.5)),
          ),
          Expanded(child: Text(f.description, style: theme.ui(t.text))),
        ],
      ),
      for (final (n, o) in f.options.indexed)
        Tap(
          onTap: () => _pick(i, o.id),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                switch ((many, picked.contains(o.id))) {
                  (false, false) => Icons.radio_button_unchecked,
                  (false, true) => Icons.radio_button_checked,
                  (true, false) => Icons.check_box_outline_blank,
                  (true, true) => Icons.check_box,
                },
                size: 16,
                color: t.textSecondary,
              ),
              SizedBox(
                width: 14,
                child: keyHint(context, active && n < 9 ? '${n + 1}' : ''),
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
