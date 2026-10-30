import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What's written in each comment box and not posted yet, by what it
/// answers ([CommentBox.draft]), while the app runs (ADR 0027): the box
/// goes with its view (a look at a chat, or at Settings), the text waits
/// for it. Posted, emptied or cancelled, it goes.
final _drafts = <String, String>{};

/// Says a draft changed, for the other boxes of its key (a thread's reply
/// in To do and in Files): they show the same text.
final ValueNotifier<int> _changed = ValueNotifier(0);

/// The text written in [key]'s box and not posted; '' when none.
String commentDraft(String key) => _drafts[key] ?? '';

/// Keeps [text] as [key]'s draft; an empty one goes.
void keepCommentDraft(String key, String text) {
  final was = _drafts[key];
  if (text.trim().isEmpty) {
    _drafts.remove(key);
  } else {
    _drafts[key] = text;
  }
  if (_drafts[key] != was) _changed.value++;
}

/// No box's draft (tests: each starts with none).
@visibleForTesting
void forgetCommentDrafts() => _drafts.clear();

/// A box to write a comment in and post it (Jira's and GitHub's, a
/// conversation's, a reply's or a review's): ⌘⏎ or its button posts it,
/// Esc cancels when it can; the button waits for some text. A post that
/// fails keeps the text and says why under it. With a [draft] key, what's
/// written outlives the box until it's posted, emptied or cancelled.
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
    this.draft,
  });

  /// What the box answers, the key its text is kept under until posted
  /// ([commentDraft]); null, the text goes with the box.
  final String? draft;

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
  bool _keeping = false; // this box's own change

  @override
  void initState() {
    super.initState();
    _restore();
    _text.addListener(_keep);
    _changed.addListener(_follow);
  }

  @override
  void didUpdateWidget(CommentBox old) {
    super.didUpdateWidget(old);
    // Another pull request's or issue's box in this one's place.
    if (old.draft != widget.draft) _restore();
  }

  /// Shows what was written for the box's [CommentBox.draft], the cursor
  /// at its end.
  void _restore() {
    final key = widget.draft;
    if (key == null) return;
    final t = commentDraft(key);
    _text.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _keep() {
    final key = widget.draft;
    if (key == null) return;
    _keeping = true;
    try {
      keepCommentDraft(key, _text.text);
    } finally {
      _keeping = false;
    }
  }

  /// Another box of the same key wrote, posted or cancelled: the same here.
  void _follow() {
    final key = widget.draft;
    if (_keeping || key == null) return;
    final t = commentDraft(key);
    if (t == _text.text || (t.isEmpty && _text.text.trim().isEmpty)) return;
    _restore();
  }

  void _cancel() {
    if (widget.draft case final key?) keepCommentDraft(key, '');
    widget.onCancel?.call();
  }

  @override
  void dispose() {
    _changed.removeListener(_follow);
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
    // The box may be gone by the time it's posted (its view left).
    final key = widget.draft;
    try {
      await widget.onPost(md);
      if (key != null) keepCommentDraft(key, '');
      if (mounted) _text.clear();
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
      if (widget.onCancel != null) {
        _cancel();
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
            if (widget.onCancel != null)
              Button(label: 'Cancel', onPressed: _cancel),
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
