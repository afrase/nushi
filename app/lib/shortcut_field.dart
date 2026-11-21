import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/key_choice.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The keys that only modify another: pressed alone, the field waits.
final _modifiers = <LogicalKeyboardKey>{
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.superKey,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
  LogicalKeyboardKey.fnLock,
};

/// A binding's key in Settings › Keyboard shortcuts, and the recorder
/// that changes it: [label] (its key, '' for none) in a field [width]
/// wide that never changes size; a click (or Enter or Space) makes it
/// listen, "Press keys…", and the next key held with its modifiers goes
/// to [onKey]. Esc stops it. While it listens it takes every key, so
/// Settings' Esc, the app's keys and the menu bar's (`shortcutRecording`)
/// never see one; it stops when it loses the focus or a click lands
/// elsewhere. [onStart] says it began.
class ShortcutField extends StatefulWidget {
  const new({
    required this.label,
    required this.focusNode,
    required this.onKey,
    super.key,
    this.onStart,
    this.width = 168,
  });

  final String label;
  final FocusNode focusNode;
  final ValueChanged<SingleActivator> onKey;
  final VoidCallback? onStart;
  final double width;

  /// Its height: a regular control's.
  static const height = 30.0;

  @override
  State<ShortcutField> createState() => _ShortcutFieldState();
}

class _ShortcutFieldState extends State<ShortcutField> {
  bool _recording = false;
  bool _focused = false;

  /// The key just taken, while it's still held. Its repeats and its
  /// lifting come after the field stopped listening (and the focus may
  /// have gone to Cancel), when the menu bar has its keys back: unhandled,
  /// the Mac's would run the item the key now belongs to.
  PhysicalKeyboardKey? _taken;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(ShortcutField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _release();
    // Settings shut mid-record: the menu bar gets its keys back (main.dart
    // waits for the frame to end before it rebuilds).
    if (_recording) shortcutRecording.value = false;
    super.dispose();
  }

  void _onFocus() {
    final focused = widget.focusNode.hasFocus;
    if (!focused && _recording) {
      _stop();
    } else if (focused != _focused && mounted) {
      setState(() => _focused = focused);
    }
  }

  void _start() {
    widget.focusNode.requestFocus();
    if (_recording) return;
    widget.onStart?.call();
    setState(() => _recording = true);
    shortcutRecording.value = true;
  }

  void _stop() {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _focused = widget.focusNode.hasFocus;
    });
    shortcutRecording.value = false;
  }

  /// Takes the repeats and the lifting of the key just taken, wherever
  /// the focus is now.
  bool _holdBack(KeyEvent e) {
    if (e.physicalKey != _taken) return false;
    // Pressed again, its lifting was missed (the window lost the keys).
    if (e is KeyDownEvent) {
      _release();
      return false;
    }
    if (e is KeyUpEvent) _release();
    return true;
  }

  void _release() {
    if (_taken == null) return;
    _taken = null;
    HardwareKeyboard.instance.removeHandler(_holdBack);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!_recording) return KeyEventResult.ignored;
    // A repeat and a key's lifting are taken and do nothing: Enter's,
    // which started it, must not end it.
    if (e is! KeyDownEvent) return KeyEventResult.handled;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _stop();
      return KeyEventResult.handled;
    }
    if (_modifiers.contains(key)) return KeyEventResult.handled;
    final held = HardwareKeyboard.instance;
    final shift = held.isShiftPressed;
    _release();
    _taken = e.physicalKey;
    HardwareKeyboard.instance.addHandler(_holdBack);
    _stop();
    widget.onKey(
      SingleActivator(
        recordedKey(key, e.physicalKey, shift: shift),
        control: held.isControlPressed,
        shift: shift,
        alt: held.isAltPressed,
        meta: held.isMetaPressed,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final corners = BorderRadius.circular(NushiTheme.control);
    final words = _recording
        ? Text(
            'Press keys…',
            maxLines: 1,
            style: theme.ui(t.accentInk, size: 12, weight: FontWeight.w600),
          )
        : widget.label.isEmpty
        ? Text('None', maxLines: 1, style: theme.ui(t.textMuted, size: 12))
        : keyText(widget.label, theme.code(t.text, size: 12));
    // Listening, it's unmistakable: the accent's soft fill, its ring and
    // words; focused, the ring alone; else a field's fill and border.
    final ring = _recording || _focused;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TapRegion(
        onTapOutside: (_) => _stop(),
        child: Tap(
          focusNode: widget.focusNode,
          onTap: _start,
          tooltip: _recording ? '' : 'Click, then press the keys',
          fill: _recording ? t.accentSoft : t.fieldFill,
          child: Container(
            width: widget.width,
            height: ShortcutField.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: ring ? t.focus : t.fieldBorder,
                width: ring ? 2 : 1,
              ),
              borderRadius: corners,
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: words),
          ),
        ),
      ),
    );
  }
}
