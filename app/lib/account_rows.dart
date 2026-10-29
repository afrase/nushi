import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

// Settings › Jira's sites and Settings › GitHub's hosts: each one's row,
// and the form that adds a token.

/// What a site's or host's row says while this build of Nushi needs the
/// user's OK to read its token from the keychain.
const needsOkStatus =
    'This build of Nushi needs your OK to read the token: macOS asks for '
    'your password.';

/// A Jira site's or a GitHub host's row: its [title], then [lines] (each
/// its words and their color); Allow… while the keychain needs the
/// user's OK ([needsOk]), and Remove when it can go ([onRemove]).
class AccountRow extends StatelessWidget {
  const new({
    required this.title,
    required this.lines,
    required this.onAllow,
    super.key,
    this.needsOk = false,
    this.onRemove,
  });

  final String title;
  final List<(String, Color)> lines;
  final bool needsOk;
  final VoidCallback onAllow;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.ui(t.text, weight: FontWeight.w600)),
                for (final (words, color) in lines)
                  Text(words, style: theme.ui(color, size: 12)),
              ],
            ),
          ),
          if (needsOk)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Button(label: 'Allow…', onPressed: onAllow),
            ),
          if (onRemove case final remove?)
            Button(
              label: 'Remove',
              kind: ButtonKind.destructive,
              onPressed: remove,
            ),
        ],
      ),
    );
  }
}

/// A field of a [TokenForm]: its [label], [hint] and first [text]; a
/// [secret] one is hidden, and cleared once added.
class TokenField {
  const new(
    this.label,
    this.hint, {
    this.text = '',
    this.secret = false,
    this.autofocus = false,
  });

  final String label;
  final String hint;
  final String text;
  final bool secret;
  final bool autofocus;
}

/// The form that adds a token: [title] and [note], its [fields], a link
/// to where tokens are made ([tokensPage]), Cancel when it can be
/// ([onCancel]) and Add. Add (or Return in a field) asks [check] what's
/// wrong with the fields' text, trimmed, then [onAdd] with it; what
/// [onAdd] throws shows under the fields.
class TokenForm extends StatefulWidget {
  const new({
    required this.title,
    required this.fields,
    required this.tokensPage,
    required this.onAdd,
    super.key,
    this.note = '',
    this.check,
    this.onCancel,
  });

  final String title;
  final String note;
  final List<TokenField> fields;
  final Uri tokensPage;
  final String? Function(List<String> text)? check;
  final Future<void> Function(List<String> text) onAdd;
  final VoidCallback? onCancel;

  @override
  State<TokenForm> createState() => _TokenFormState();
}

class _TokenFormState extends State<TokenForm> {
  late final List<TextEditingController> _text = [
    for (final f in widget.fields) TextEditingController(text: f.text),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _text) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final text = [for (final c in _text) c.text.trim()];
    if (widget.check?.call(text) case final wrong?) {
      setState(() => _error = wrong);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAdd(text);
      if (mounted) {
        for (final (i, f) in widget.fields.indexed) {
          if (f.secret) _text[i].clear();
        }
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final mono = theme.code(t.text, size: 12);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: box(t.borderSubtle, fill: t.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.ui(t.text, weight: FontWeight.w600)),
          if (widget.note.isNotEmpty)
            Text(widget.note, style: theme.ui(t.textMuted, size: 12)),
          for (final (i, f) in widget.fields.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(f.label, style: theme.ui(t.textSecondary)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text[i],
                      obscureText: f.secret,
                      autofocus: f.autofocus,
                      enabled: !_busy,
                      style: mono,
                      decoration: InputDecoration(
                        hintText: f.hint,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                ],
              ),
            ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e, style: theme.ui(t.crashed, size: 12)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              LinkText(
                'Make a token',
                size: 12,
                onTap: () => unawaited(launchUrl(widget.tokensPage)),
              ),
              const Spacer(),
              if (widget.onCancel case final cancel?)
                Button(label: 'Cancel', onPressed: _busy ? null : cancel),
              const SizedBox(width: 6),
              Button(
                label: _busy ? 'Checking…' : 'Add',
                kind: ButtonKind.primary,
                onPressed: _busy ? null : _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
