part of 'question_card.dart';

/// What a question card does with a pick and the keys: picking and
/// unpicking, ↑/↓, digits, Esc and Return, on the card and in its box.
extension _QuestionKeys on _QuestionCardState {
  /// Picks option [n] of the question shown, sending nothing: a one-choice
  /// question's pick moves to it, or with [toggle] goes if it was there (a
  /// click on the pick); a many-choice question's toggles.
  void _pick(int n, {bool toggle = false}) {
    final q = _shown!;
    final id = q.field.options[n].id;
    _redraw(() {
      _at = n;
      final values = _picked[q.field.id] ??= [];
      if (_QuestionCardState._choices(q) || toggle && values.contains(id)) {
        values.contains(id) ? values.remove(id) : values.add(id);
      } else {
        values
          ..clear()
          ..add(id);
      }
    });
  }

  /// Unpicks the question shown (each pick, of a many-choice one), so the
  /// box's text is the answer itself; false when nothing was picked.
  bool _unpick() {
    final q = _shown;
    if (q == null || !_form.picked(q)) return false;
    _redraw(() => _picked[q.field.id]!.clear());
    return true;
  }

  /// Moves a one-choice question's pick a step [down] or up, round at
  /// either end; with nothing picked, to the first or the last.
  void _step({required bool down}) {
    final q = _shown!;
    final options = q.field.options;
    final at = _form.picked(q)
        ? options.indexWhere((o) => o.id == _form.picks(q).first)
        : -1;
    _pick(
      at < 0
          ? (down ? 0 : options.length - 1)
          : (at + (down ? 1 : -1)) % options.length,
    );
  }

  /// Return, or Send: on to the next question (the review after the
  /// last), or with one question, or on the review, the answers sent.
  void _submit() {
    if (_many && _shown != null) {
      _go(_tab + 1);
    } else if (_form.answer.isNotEmpty) {
      unawaited(_send(_form.answer));
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    // Keys typed into a box on the card (an "Other" answer) are its own.
    if (e is KeyUpEvent || !_focus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final q = _shown;
    final options = q?.field.options ?? const <Option>[];
    final many = q != null && _QuestionCardState._choices(q);
    // Typed: with ⌘, Control or Option held a digit is the chat keys'
    // (⌘1 a chat), not a pick.
    final digit = int.tryParse(typedCharacter(e) ?? '') ?? 0;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    // ⌃Tab and ⌃⇧Tab go on to the chat's tabs (`chat_keys.dart`).
    final tab =
        k == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isControlPressed;
    final up = k == LogicalKeyboardKey.arrowUp;
    final down = k == LogicalKeyboardKey.arrowDown;
    if (digit >= 1 && digit <= options.length && digit <= 9) {
      _pick(digit - 1);
      // The fast path: a one-choice pick with nothing written goes at once.
      if (!many && !_form.written(q!)) _submit();
    } else if (_many && (k == LogicalKeyboardKey.arrowRight || tab && !shift)) {
      _go(_tab + 1);
    } else if (_many && (k == LogicalKeyboardKey.arrowLeft || tab)) {
      _go(_tab - 1);
    } else if (options.isNotEmpty && !many && (up || down)) {
      _step(down: down);
    } else if (options.isNotEmpty && (up || down)) {
      // A many-choice question's options and its box are one list, the
      // box between the last option and the first.
      if (_boxField != null && _at == (down ? options.length - 1 : 0)) {
        _toBox();
      } else {
        _redraw(() => _at = (_at + (down ? 1 : -1)) % options.length);
      }
    } else if (options.isNotEmpty && k == LogicalKeyboardKey.space) {
      _pick(_at);
    } else if (k == LogicalKeyboardKey.escape && _unpick()) {
      // Unpicked; with nothing picked Esc is the chat's.
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      _submit();
    } else if (typedCharacter(e) case final c? when _boxField != null) {
      _toBox(c); // a digit no option has too
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The box's own keys, before its text's: Esc unpicks, or with nothing
  /// picked gives the keys back to the card, the text kept; ↑/↓ where the
  /// caret can't go that way move a one-choice question's pick, the keys
  /// staying in the box, or go to a many-choice question's last or first
  /// option.
  KeyEventResult _onBoxKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final q = _shown;
    final options = q?.field.options ?? const <Option>[];
    final up = k == LogicalKeyboardKey.arrowUp;
    final down = k == LogicalKeyboardKey.arrowDown;
    if (k == LogicalKeyboardKey.escape) {
      if (!_unpick()) _focus.requestFocus();
    } else if (options.isNotEmpty && (up || down) && !_caretMoves(down: down)) {
      if (_QuestionCardState._choices(q!)) {
        _redraw(() => _at = up ? options.length - 1 : 0);
        _focus.requestFocus();
      } else {
        _step(down: down);
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Whether the box's caret has a line to go to [down] (or up): a box of
  /// one line never has, so ↑/↓ there are the card's.
  bool _caretMoves({required bool down}) {
    final c = _text[_boxField!.id]!;
    final at = c.selection;
    if (!at.isValid) return false;
    return down
        ? c.text.substring(at.end).contains('\n')
        : c.text.substring(0, at.start).contains('\n');
  }
}
