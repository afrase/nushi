import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart' show openLinkOrSay;
import 'package:nushi/widgets.dart';

// Settings › Jira's sites and Settings › GitHub's hosts: each one's row,
// and the form that adds a token.

/// What a site's or host's row says while this build of Nushi needs the
/// user's OK to read its token from the keychain (on Linux, while the
/// keyring is locked).
String get needsOkStatus =>
    'This build of Nushi needs your OK to read the token: '
    '${conventions.system} asks for your password.';

/// Says that a removed site's or host's token is still in the keychain as
/// [kept], the item's name there (RemoveJiraSite's and RemoveGitHubToken's
/// token_kept, API 144), for the user to delete it: the keychain refused
/// (a locked or missing keyring, a denied prompt). A warning that stays
/// 30 s or until dismissed; nothing when [kept] is empty (deleted, or an
/// older daemon).
void sayTokenKept(Toasts? toasts, String kept) {
  if (kept.isEmpty) return;
  showFailure(
    toasts,
    'Removed. Its token is still in your ${conventions.keyring} as '
    '“$kept”: delete it there.',
    key: const ValueKey('token-kept'),
    icon: Icons.warning_amber_rounded,
    duration: const Duration(seconds: 30),
  );
}

/// A Jira site's or a GitHub host's row, both alike: the integration's
/// [icon] in a small tile, its [title] and [lines] (each its words and
/// their color: who, or what's wrong), then its [state] in a pill
/// ("Signed in", "Connected"), Allow… while the keychain needs the user's
/// OK ([needsOk]), and a ⋯ of [more]: the details that are jargon in the
/// main view (a token's kind and scopes), and Remove.
class AccountRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.lines,
    required this.onAllow,
    super.key,
    this.state,
    this.needsOk = false,
    this.more = const [],
  });

  final IconData icon;
  final String title;
  final List<(String, Color)> lines;
  final (String, NoteTone)? state;
  final bool needsOk;
  final VoidCallback onAllow;
  final List<MenuEntry> more;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.lifted,
              borderRadius: BorderRadius.circular(NushiTheme.control),
            ),
            child: Icon(icon, size: 16, color: t.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.ui(t.text)),
                for (final (words, color) in lines)
                  Text(words, style: theme.ui(color, size: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (needsOk)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Button(label: 'Allow…', onPressed: onAllow),
            ),
          if (state case (final words, final tone))
            NotePill(words, key: ValueKey('account-state-$title'), tone: tone),
          if (more.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: MenuIcon(
                Icons.more_horiz,
                key: ValueKey('account-more-$title'),
                tooltip: 'More',
                entries: more,
              ),
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
      padding: const EdgeInsets.all(13),
      decoration: cardBox(t),
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
                onTap: () =>
                    unawaited(openLinkOrSay(context, widget.tokensPage)),
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
