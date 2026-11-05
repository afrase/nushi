import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/inline_edit.dart';

const _channel = MethodChannel('nushi/window');

/// A header at the window's top, which has no title bar to hold (the
/// content runs under the traffic lights), doing what a title bar did
/// (ADR 0080): a Stack of [background] (its fill and hairline), the drag
/// area, then [children] (its row, the button that shows the sidebar).
/// A drag anywhere but on a control moves the window, from its title and
/// its marks too; a double click zooms it only in the bar's empty space,
/// not on or beside what's in it. A control (what shows a pointer of its
/// own: the hand, the text's I-beam) keeps its clicks and its drags.
class WindowDrag extends StatefulWidget {
  const new({required this.background, required this.children, super.key});

  /// What's drawn under all of it.
  final Widget background;

  /// What's in the bar.
  final List<Widget> children;

  /// How far beside what's in the bar a click still counts as on it: half
  /// the bar's gap between controls, so a gap in a group of them is theirs.
  static const near = 6.0;

  @override
  State<WindowDrag> createState() => _WindowDragState();
}

class _WindowDragState extends State<WindowDrag> {
  DoubleClick _click = DoubleClick();
  final GlobalKey _content = GlobalKey();

  void _send(String method) => _channel.invokeMethod<void>(method).ignore();

  /// A click: on or beside the bar's content it's no click of the bar's,
  /// and the next one starts a double click afresh.
  void _clicked(Offset global) {
    final content = _content.currentContext?.findRenderObject();
    if (content is _RenderContent &&
        content.near(content.globalToLocal(global))) {
      _click = DoubleClick();
    } else if (_click()) {
      _send('zoom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = Stack(fit: StackFit.expand, children: widget.children);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.background,
        if (kIsWeb)
          layers // the phone's headers: no window to move
        else ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _send('drag'),
            onTapUp: (d) => _clicked(d.globalPosition),
          ),
          _Content(key: _content, child: layers),
        ],
      ],
    );
  }
}

/// The bar's content over its drag area: a press on a control stops there;
/// on anything else what's under it gets the press too (a tooltip, the
/// title's double click), and so does the drag area below.
class _Content extends SingleChildRenderObjectWidget {
  const new({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContent();
}

class _RenderContent extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final before = result.path.length;
    if (!super.hitTest(result, position: position)) return false;
    return result.path.skip(before).any((e) => _control(e.target));
  }

  /// Whether [position] is on or beside something in the bar: under it, or
  /// within [WindowDrag.near] across, the bar's height through (its row is
  /// centred in it, so a click just above a word is the word's).
  bool near(Offset position) {
    final middle = size.height / 2;
    return [
      position,
      Offset(position.dx, middle),
      Offset(position.dx - WindowDrag.near, middle),
      Offset(position.dx + WindowDrag.near, middle),
    ].any((p) => size.contains(p) && _on(p));
  }

  /// Whether something in the bar is under [p]. A text is only where its
  /// words are: one in an `Expanded` is as wide as the room it was given,
  /// and the rest of that room is the bar's empty space.
  bool _on(Offset p) {
    final result = BoxHitTestResult();
    if (!child!.hitTest(result, position: p)) return false;
    final text = result.path
        .map((e) => e.target)
        .whereType<RenderParagraph>()
        .firstOrNull;
    if (text == null || text.didExceedMaxLines) return true;
    final x = text.globalToLocal(p, ancestor: this).dx;
    final all = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.toPlainText().length,
    );
    return text
        .getBoxesForSelection(all)
        .any((b) => x >= b.left && x <= b.right);
  }

  /// A control shows its own pointer over it; a tooltip's region or a
  /// disabled button's leaves it to what's below.
  static bool _control(HitTestTarget target) =>
      target is RenderMouseRegion &&
      target.cursor != MouseCursor.defer &&
      target.cursor != SystemMouseCursors.basic;
}
