import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/selection_lines.dart';

/// How wide the scrollbar's strip is, at the transcript's right edge.
const _scrollbarEdge = 16.0;

/// The transcript's one selection across its entries ([child]), and what
/// it offers: a toolbar above selected text to ask a side chat about it
/// ([onSide]) or to reply to it ([onReply]), and the reply box; selected
/// by touch, the selection's own menu has those beside Copy. ⌘C copies it
/// with its lines; R opens the reply box, as Reply does. Pacing holds
/// while a pointer is down or text is selected. It spans the
/// transcript's box, where the toolbar is placed.
class TranscriptSelection extends StatefulWidget {
  const new({
    required this.width,
    required this.onReply,
    required this.onSide,
    required this.onPress,
    required this.child,
    super.key,
  });

  /// The transcript's width: a press at its right edge is on the scrollbar.
  final double width;

  /// Takes a reply to the selection; null hides the action.
  final void Function(Reply reply)? onReply;

  /// Opens a side chat about the selection; null hides the action.
  final void Function(String selection)? onSide;

  /// A pointer went down on the transcript (true), or up (false).
  final ValueChanged<bool> onPress;

  final Widget child;

  @override
  State<TranscriptSelection> createState() => _TranscriptSelectionState();
}

class _TranscriptSelectionState extends State<TranscriptSelection> {
  final _area = GlobalKey<SelectionAreaState>();
  // A click outside (the composer) takes the focus and clears the
  // selection without reporting it: the toolbar goes with it. An open reply
  // box stays, its quote kept.
  late final FocusNode _areaFocus =
      FocusNode(debugLabel: 'transcript', onKeyEvent: _key)..addListener(() {
        if (!_areaFocus.hasFocus && _at != null && _replyTo == null) {
          _closeToolbar();
        }
      });
  String _selected = '';
  bool _down = false; // a pointer is down on the transcript
  // Pacing holds while a pointer is down or text is selected.
  final _hold = ValueNotifier<bool>(false);
  bool _touch = false; // the last pointer down was a finger (or a pen)
  Rect? _at; // the selection's top and bottom middle, where the toolbar shows
  String? _replyTo; // the selection a reply is being written to
  _Anchor _anchor = _Anchor(); // where the reply box opened

  @override
  void dispose() {
    _hold.dispose();
    _areaFocus.dispose();
    super.dispose();
  }

  /// A code block's sideways scroll tells nobody where its text went: what
  /// shows of a selection there would sit where it was.
  bool _sideways(ScrollUpdateNotification n) {
    if (n.depth > 0 &&
        n.metrics.axis == Axis.horizontal &&
        _selected.isNotEmpty &&
        _replyTo == null) {
      _clearSelection();
      if (_at != null) setState(() => _at = null);
    }
    return false;
  }

  // The selection is reported a frame after the pointer goes up: offer the
  // toolbar once both have happened.
  // On touch the selection's own menu offers the actions instead (_menu).
  void _offer() {
    if (_touch || _down || _at != null || _selected.trim().isEmpty) return;
    if (_anchors() case final at?) setState(() => _at = at);
  }

  /// The selection's top and bottom middle, in the transcript's box.
  Rect? _anchors() {
    final a = _area.currentState?.selectableRegion.contextMenuAnchors;
    final box = context.findRenderObject() as RenderBox?;
    if (a == null || box == null) return null;
    return Rect.fromPoints(
      box.globalToLocal(a.primaryAnchor),
      box.globalToLocal(a.secondaryAnchor ?? a.primaryAnchor),
    );
  }

  void _openReply() => setState(() {
    _at ??= _anchors();
    _replyTo = _selectedText();
    _anchor = _Anchor();
  });

  /// The selection's menu: as the platform's on a mouse; on touch, one menu
  /// of Copy, Side chat and Reply where the platform draws its own, so
  /// nothing of Nushi's sits under it (iOS's Copy | Select All hid the
  /// toolbar on the phone).
  Widget _menu(
    SelectableRegionState region, {
    required VoidCallback? onSide,
    required VoidCallback? onReply,
  }) {
    if (!_touch || (onSide == null && onReply == null)) {
      return AdaptiveTextSelectionToolbar.selectableRegion(
        selectableRegionState: region,
      );
    }
    VoidCallback then(VoidCallback run) => () {
      region.hideToolbar();
      run();
    };
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: [
        ...region.contextMenuButtonItems.where(
          (b) => b.type == ContextMenuButtonType.copy,
        ),
        if (onSide != null)
          ContextMenuButtonItem(label: 'Side chat', onPressed: then(onSide)),
        if (onReply != null)
          ContextMenuButtonItem(label: 'Reply', onPressed: then(onReply)),
      ],
    );
  }

  void _closeToolbar() => setState(() => _at = _replyTo = null);

  /// A press of the mouse starts a new selection, so the last one goes
  /// first: its edges otherwise carry into the new one. Shift extends it,
  /// and one on the scrollbar, at the edge of [TranscriptSelection.width],
  /// starts none.
  void _startSelection(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.mouse &&
        e.buttons == kPrimaryButton &&
        e.localPosition.dx < widget.width - _scrollbarEdge &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _clearSelection();
    }
  }

  /// The selection's text with its lines (selectionLines).
  String _selectedText() {
    final box = _area.currentContext?.findRenderObject();
    final lines = box == null ? '' : selectionLines(box);
    return lines.isEmpty ? _selected : lines;
  }

  /// The selection's keys: R replies to it ([_reply]), ⌘C copies it
  /// ([_copy]).
  KeyEventResult _key(FocusNode node, KeyEvent e) =>
      _reply(e) ? KeyEventResult.handled : _copy(node, e);

  /// R, no modifier, with text selected and no reply box open: opens one
  /// on it, as the toolbar's Reply does.
  bool _reply(KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    if (e is KeyUpEvent ||
        e.logicalKey != LogicalKeyboardKey.keyR ||
        keys.isMetaPressed ||
        keys.isControlPressed ||
        keys.isAltPressed ||
        keys.isShiftPressed ||
        widget.onReply == null ||
        _replyTo != null ||
        _selected.trim().isEmpty) {
      return false;
    }
    if (e is KeyDownEvent) _openReply();
    return true;
  }

  /// ⌘C: the selection with its lines, not the run-together text the
  /// selection area itself copies.
  KeyEventResult _copy(FocusNode _, KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    if (e is KeyUpEvent ||
        e.logicalKey != LogicalKeyboardKey.keyC ||
        !(keys.isMetaPressed || keys.isControlPressed) ||
        _selected.isEmpty) {
      return KeyEventResult.ignored;
    }
    unawaited(Clipboard.setData(ClipboardData(text: _selectedText())));
    return KeyEventResult.handled;
  }

  void _clearSelection() =>
      _area.currentState?.selectableRegion.clearSelection();

  void _pointerGone() {
    _down = false;
    _hold.value = _selected.isNotEmpty;
    _offer();
    widget.onPress(false);
  }

  @override
  Widget build(BuildContext context) {
    final onReply = widget.onReply;
    final onSide = widget.onSide;
    final side = onSide == null
        ? null
        : () {
            final selected = _selectedText();
            _closeToolbar();
            onSide(selected);
          };
    final reply = onReply == null ? null : _openReply;
    return Stack(
      children: [
        // One selection across the transcript, messages included whole; when
        // a drag or double-click leaves text selected, the popover shows where
        // the pointer went up.
        NotificationListener<ScrollUpdateNotification>(
          onNotification: _sideways,
          child: Listener(
            onPointerDown: (e) {
              _startSelection(e);
              widget.onPress(true);
              setState(() {
                _down = _hold.value = true;
                _touch = e.kind != PointerDeviceKind.mouse;
                _at = _replyTo = null;
              });
            },
            onPointerUp: (_) => _pointerGone(),
            onPointerCancel: (_) => _pointerGone(),
            child: SelectionArea(
              key: _area,
              focusNode: _areaFocus,
              contextMenuBuilder: (context, region) =>
                  _menu(region, onSide: side, onReply: reply),
              onSelectionChanged: (c) {
                _selected = c?.plainText ?? '';
                _hold.value = _down || _selected.isNotEmpty;
                _offer();
              },
              child: PacingHold(notifier: _hold, child: widget.child),
            ),
          ),
        ),
        if (_at case final at? when onReply != null || onSide != null)
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _Above(at, _replyTo == null ? null : _anchor),
              child: switch (_replyTo) {
                // Its own layer: typing repaints only the box.
                final quote? => RepaintBoundary(
                  child: ReplyBox(
                    quote: quote,
                    onReply: onReply!,
                    onClose: _closeToolbar,
                  ),
                ),
                null => SelectionToolbar(onSide: side, onReply: reply),
              },
            ),
          ),
      ],
    );
  }
}

/// Where a reply box's bottom edge went when it opened: it stays there as
/// the box grows a line at a time, so the box grows upward, as Claude's.
class _Anchor {
  double? bottom;
}

/// Places its child centered just above [at] (a selection's top and bottom
/// middle), or below it when there is no room above, inside the box. With
/// an [anchor] (the reply box) the child keeps the bottom edge it first
/// had, kept inside too.
class _Above extends SingleChildLayoutDelegate {
  new(this.at, [this.anchor]);

  final Rect at;
  final _Anchor? anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: max(0, c.maxWidth - 16),
    maxHeight: max(0, c.maxHeight - 8),
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    double inside(double y) =>
        y.clamp(4, max(4, size.height - child.height - 4));
    final double y;
    if (anchor?.bottom case final bottom?) {
      y = inside(bottom - child.height);
    } else {
      final above = at.top - child.height - 6;
      y = inside(above < 4 ? at.bottom + 6 : above);
      anchor?.bottom = y + child.height;
    }
    return Offset(
      (at.center.dx - child.width / 2).clamp(
        8,
        max(8, size.width - child.width - 8),
      ),
      y,
    );
  }

  @override
  bool shouldRelayout(_Above old) => old.at != at || old.anchor != anchor;
}
