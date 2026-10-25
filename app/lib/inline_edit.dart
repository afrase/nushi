import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/theme/theme.dart';

/// Tells a second click soon after the first, without holding the first
/// back as a double-tap recognizer would.
class DoubleClick {
  DateTime _last = DateTime(0);

  /// Notes a click; true when it is the second of two.
  bool call() {
    final now = DateTime.now();
    final second = now.difference(_last) < kDoubleTapTimeout;
    _last = now;
    return second;
  }
}

/// Edits [text] in place, all of it selected: Enter or leaving the box
/// gives [onDone] the text, trimmed; Escape gives it null.
class InlineEdit extends StatefulWidget {
  const new({
    required this.text,
    required this.onDone,
    super.key,
    this.style,
    this.decoration = const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    ),
  });

  final String text;
  final ValueChanged<String?> onDone;
  final TextStyle? style;
  final InputDecoration decoration;

  @override
  State<InlineEdit> createState() => _InlineEditState();
}

class _InlineEditState extends State<InlineEdit> {
  late final _text = TextEditingController(
    text: widget.text,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.text.length);
  final _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish(save: true);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _finish({required bool save}) {
    if (_done) return;
    _done = true;
    widget.onDone(save ? _text.text.trim() : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _finish(save: false),
      },
      child: TextField(
        controller: _text,
        focusNode: _focus,
        autofocus: true,
        style: widget.style ?? theme.ui(theme.t.text),
        onSubmitted: (_) => _finish(save: true),
        onTapOutside: (_) => _finish(save: true),
        decoration: widget.decoration,
      ),
    );
  }
}
