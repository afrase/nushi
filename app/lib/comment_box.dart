import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A box to write a comment in and post it (Jira's and GitHub's, a
/// conversation's, a reply's or a review's): ⌘⏎ or its button posts it,
/// Esc cancels when it can; the button waits for some text. A post that
/// fails keeps the text and says why under it.
class CommentBox extends StatefulWidget {
  const new({
    required this.onPost,
    super.key,
    this.hint = 'Add a comment (Markdown)',
    this.label = 'Comment',
    this.autofocus = false,
    this.onCancel,
    this.note = '',
    this.primary = false,
  });

  final String hint;
  final String label;

  /// Small print at the buttons' left ("Markdown · posts to GitHub as
  /// octo").
  final String note;

  /// Its button is the accent's (a conversation's box).
  final bool primary;
  final bool autofocus;

  /// Posts the text; it throws when it was refused (the box keeps it).
  final Future<void> Function(String markdown) onPost;
  final VoidCallback? onCancel;

  @override
  State<CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends State<CommentBox> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final md = _text.text.trim();
    if (md.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPost(md);
      _text.clear();
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ⌘⏎ and Esc, before the field reads ⌘⏎ as a line break.
  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isMetaPressed) {
      unawaited(_post());
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.onCancel case final cancel?) {
        cancel();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          skipTraversal: true,
          onKeyEvent: _key,
          child: TextField(
            controller: _text,
            autofocus: widget.autofocus,
            enabled: !_busy,
            minLines: 2,
            maxLines: 8,
            style: theme.ui(t.text),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: widget.hint, isDense: true),
          ),
        ),
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(e, style: theme.ui(t.crashed, size: 12)),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.note.isNotEmpty)
              Expanded(
                child: Text(
                  widget.note,
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ),
            if (widget.onCancel case final cancel?)
              Button(label: 'Cancel', onPressed: cancel),
            const SizedBox(width: 6),
            Button(
              label: _busy ? 'Posting…' : widget.label,
              hint: '⌘⏎',
              kind: widget.primary ? ButtonKind.primary : ButtonKind.secondary,
              onPressed: _busy || _text.text.trim().isEmpty ? null : _post,
            ),
          ],
        ),
      ],
    );
  }
}
