import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/key_choice.dart';
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
  // Right Alt, where a Linux layout makes it AltGr (ISO_Level3_Shift).
  LogicalKeyboardKey.altGraph,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
  LogicalKeyboardKey.fnLock,
};

/// A binding's key in Settings › Keyboard shortcuts, as a key's cap that
/// is the control that changes it: [label] (its key, '' for none) on a
/// [KeyCapButton]; a click (or Enter or Space)
/// makes it listen, "Press keys…", and the next key held with its
/// modifiers goes to [onKey]. Esc stops it. While it listens it takes
/// every key, so Settings' Esc, the app's keys and the menu bar's
/// (`shortcutRecording`) never see one; it stops when it loses the focus
/// or a click lands elsewhere. [onStart] says it began; its state's
/// `listen` starts it from elsewhere (a click on its row). [chosen]: a
/// key the user chose, on the accent's soft fill.
class ShortcutField extends StatefulWidget {
  const new({
    required this.label,
    required this.focusNode,
    required this.onKey,
    super.key,
    this.onStart,
    this.chosen = false,
    this.keyboard,
  });

  final String label;
  final FocusNode focusNode;
  final ValueChanged<SingleActivator> onKey;
  final VoidCallback? onStart;
  final bool chosen;

  /// Whether the keyboard moved last, not the pointer: focused, the cap
  /// wears its ring only then (as a browser's `:focus-visible`), so a
  /// key just taken with a click doesn't look as if it still listened.
  /// Always, without one.
  final ValueListenable<bool>? keyboard;

  @override
  State<ShortcutField> createState() => ShortcutFieldState();
}

/// A [ShortcutField]'s state: [listen] makes it listen.
class ShortcutFieldState extends State<ShortcutField> {
  bool _recording = false;
  bool _focused = false;

  /// The key just taken, while it's still held. Its repeats and its
  /// lifting come after the field stopped listening (and the focus may
  /// have gone to Cancel), when the app's keys and the menu bar's are
  /// back: unhandled, a repeat would run what the key belongs to (Quit,
  /// or the Settings key shutting Settings).
  PhysicalKeyboardKey? _taken;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    widget.keyboard?.addListener(_onMoved);
  }

  void _onMoved() {
    if (mounted && _focused) setState(() {});
  }

  @override
  void didUpdateWidget(ShortcutField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
    if (oldWidget.keyboard != widget.keyboard) {
      oldWidget.keyboard?.removeListener(_onMoved);
      widget.keyboard?.addListener(_onMoved);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    widget.keyboard?.removeListener(_onMoved);
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

  /// Takes the focus and listens for a key, as a click on it does.
  void listen() {
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
  /// the focus is now: before any key handler in the focus tree, so
  /// neither the app's Shortcuts nor Settings' see them, and handled, so
  /// the menu bar doesn't either.
  KeyEventResult _holdBack(KeyEvent e) {
    if (e.physicalKey != _taken) return KeyEventResult.ignored;
    // Pressed again, its lifting was missed (the window lost the keys).
    if (e is KeyDownEvent) {
      _release();
      return KeyEventResult.ignored;
    }
    if (e is KeyUpEvent) _release();
    return KeyEventResult.handled;
  }

  void _release() {
    if (_taken == null) return;
    _taken = null;
    FocusManager.instance.removeEarlyKeyEventHandler(_holdBack);
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
    FocusManager.instance.addEarlyKeyEventHandler(_holdBack);
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
    final none = widget.label.isEmpty;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TapRegion(
        onTapOutside: (_) => _stop(),
        child: KeyCapButton(
          widget.label,
          focusNode: widget.focusNode,
          onTap: listen,
          tooltip: _recording ? '' : 'Click, then press the keys',
          look: _recording
              ? KeyCapLook.listening
              : none
              ? KeyCapLook.none
              : widget.chosen
              ? KeyCapLook.chosen
              : KeyCapLook.key,
          // Listening, it's unmistakable: the accent's soft fill, its ring
          // and words; focused from the keyboard, the ring alone.
          ring: _recording || (_focused && (widget.keyboard?.value ?? true)),
        ),
      ),
    );
  }
}

/// Whether the keyboard moved last (Tab, Enter, Space, an arrow), not the
/// pointer (a click): a [ShortcutField]'s focus shows its ring only then.
/// Typing a key to record doesn't count. Listens from when it's made until
/// it's disposed.
class KeyboardMovedLast extends ValueNotifier<bool> {
  new() : super(true) {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// The keys that move the keyboard's focus or press what has it.
  static final Set<LogicalKeyboardKey> _moves = {
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) value = false;
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && _moves.contains(e.logicalKey)) value = true;
    return false;
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }
}
