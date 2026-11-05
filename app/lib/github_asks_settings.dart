import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › GitHub's What reply cards ask: for each kind of card Send to
/// agent makes, the words under its quote, the user's to change (one may
/// want the agent to commit what it fixed). Each field starts at what a
/// card asks now; empty, or Reset, asks the default. The data line
/// ([asData]) follows whatever is written, and isn't shown as editable.
class CardAsksGroup extends StatefulWidget {
  const new({super.key});

  @override
  State<CardAsksGroup> createState() => _CardAsksGroupState();
}

class _CardAsksGroupState extends State<CardAsksGroup> {
  late final Map<CardAsk, TextEditingController> _fields = {
    for (final k in CardAsk.values) k: TextEditingController(text: k.text),
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Keeps [k]'s words as [v]: nothing kept when they're empty or the
  /// default, so a default changed in a later Nushi reaches this card.
  void _set(CardAsk k, String v) {
    final s = v.trim();
    final asks = {...cardAsks.value};
    if (s.isEmpty || s == k.standard) {
      asks.remove(k.name);
    } else {
      asks[k.name] = v;
    }
    cardAsks.value = asks;
  }

  void _reset(CardAsk k) {
    _fields[k]!.text = k.standard;
    _set(k, k.standard);
  }

  @override
  Widget build(BuildContext context) => SettingsGroup(
    title: 'What reply cards ask',
    about:
        'What Send to agent, Fix checks and Address ask the agent to do '
        'with a card from GitHub.',
    footer: const Text(
      "A card's quote comes first, then these words, then always: "
      '$asData Empty, a card asks the default.',
    ),
    children: [
      for (final k in CardAsk.values)
        _AskField(
          ask: k,
          controller: _fields[k]!,
          onChanged: (v) => _set(k, v),
          onReset: () => _reset(k),
        ),
    ],
  );
}

/// One kind's words: its name and Reset over a field of a few lines.
class _AskField extends StatelessWidget {
  const new({
    required this.ask,
    required this.controller,
    required this.onChanged,
    required this.onReset,
  });

  final CardAsk ask;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            children: [
              Expanded(child: Text(ask.label, style: theme.ui(t.text))),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => LinkText(
                  'Reset',
                  size: 12,
                  tooltip: 'Back to: ${ask.standard}',
                  onTap: controller.text.trim() == ask.standard
                      ? null
                      : onReset,
                ),
              ),
            ],
          ),
          TextField(
            key: ValueKey('card-ask-${ask.name}'),
            controller: controller,
            minLines: 2,
            maxLines: 6,
            style: theme.ui(t.text),
            inputFormatters: [
              FilteringTextInputFormatter.deny(CardAsk.notPlain),
              LengthLimitingTextInputFormatter(CardAsk.maxLength),
            ],
            decoration: InputDecoration(hintText: ask.standard, isDense: true),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
