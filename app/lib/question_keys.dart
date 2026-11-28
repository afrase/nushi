part of 'question_card.dart';

/// What a question card does with a pick and the keys: picking, ↑/↓,
/// digits, Space, Esc and Return, on the card and in its box.
extension _QuestionKeys on _QuestionCardState {
  void _pick(int option) {
    final f = _qs[_tab].field;
    final id = f.options[option].id;
    final many = f.type == FieldType.FIELD_TYPE_CHOICES;
    _redraw(() {
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
    _many ? _go(_tab + 1) : _send(_form.answer);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    // Keys typed into a box on the card (an "Other" answer) are its own.
    if (e is KeyUpEvent || !_focus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final onQuestion = _tab < _qs.length;
    final options = onQuestion ? _qs[_tab].field.options : <Option>[];
    // Typed: with ⌘, Control or Option held a digit is the chat keys'
    // (⌘1 a chat), not a pick.
    final digit = int.tryParse(typedCharacter(e) ?? '') ?? 0;
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
        _redraw(() => _at = (_at + (down ? 1 : -1)) % options.length);
      }
    } else if (options.isNotEmpty && k == LogicalKeyboardKey.space) {
      _pick(_at);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      final f = onQuestion ? _qs[_tab].field : null;
      if (f != null &&
          f.type != FieldType.FIELD_TYPE_CHOICES &&
          options.isNotEmpty &&
          _form.said(_qs[_tab]).isEmpty) {
        _pick(_at);
      } else if (_many && onQuestion) {
        _go(_tab + 1);
      } else if (_form.answer.isNotEmpty) {
        unawaited(_send(_form.answer));
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
      _redraw(
        () => _at = k == LogicalKeyboardKey.arrowUp ? options.length - 1 : 0,
      );
      _focus.requestFocus();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}
