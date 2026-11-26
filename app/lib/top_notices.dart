import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/panes.dart';
import 'package:nushi/toast.dart';

/// The bars of the window (ADR 0128, amended 2026-11-17), for the view
/// in the main pane to put in a row of their own under its header
/// ([BarsRow]): one element wherever they're put, so a bar keeps its state
/// and its slide as the view changes. A chat's `Beside` lays them out
/// itself.
class TopBars extends InheritedWidget {
  const new({required this.bars, required super.child, super.key});

  /// None in a chat, which lays them out itself.
  final Widget? bars;

  @override
  bool updateShouldNotify(TopBars old) => bars != old.bars;
}

/// Under a view's header (Jira's, GitHub's, an empty window's), the bars
/// ([TopBars]) across it, pushing the view down as one slides in and giving
/// the room back as it goes; under them, where the toasts show
/// ([ToastAnchor]), centred, never less than [ToastHost.margin] inside it.
/// Nothing outside a [TopBars].
class BarsRow extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = context.dependOnInheritedWidgetOfExactType<TopBars>()?.bars;
    if (bars == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bars,
        // No height: a toast lies over what's under it for its seconds,
        // [ToastHost.margin] under the bars.
        LayoutBuilder(
          builder: (context, box) => Center(
            child: Transform.translate(
              offset: const Offset(0, ToastHost.margin),
              child: SizedBox(
                width: min(
                  ToastHost.width,
                  max(0, box.maxWidth - 2 * ToastHost.margin),
                ),
                height: 0,
                child: const ToastAnchor(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What floats over a view that isn't a chat (ADR 0128): the [card] (the
/// newer release's) in its bottom right corner. The bars and the toasts
/// are under its header ([BarsRow]); a chat places all three itself
/// (`Beside`'s notices), the card above the bars at its foot ([CardLift]). It
/// covers the main area and takes no pointer but the card's.
class TopNotices extends StatelessWidget {
  const new({required this.card, super.key});

  final Widget card;

  /// The card's room from the main area's right and bottom edges (the
  /// window's, less its pad): the details panel's side margin.
  static const cardInset = 16.0;

  /// [card], [bars] and the toasts' anchor (with [toasts]) as the children
  /// of a layout whose delegate has [NoticesPlace], which places the card
  /// and the anchor; the bars are the layout's own to place.
  static List<Widget> slots({
    required Widget card,
    Widget? bars,
    bool toasts = true,
  }) => [
    LayoutId(
      key: const ValueKey(NoticeSlot.card),
      id: NoticeSlot.card,
      child: card,
    ),
    if (bars != null)
      LayoutId(
        key: const ValueKey(NoticeSlot.bars),
        id: NoticeSlot.bars,
        child: bars,
      ),
    if (toasts)
      LayoutId(
        key: const ValueKey(NoticeSlot.toasts),
        id: NoticeSlot.toasts,
        child: const ToastAnchor(),
      ),
  ];

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _Place(),
    children: slots(card: card, toasts: false),
  );
}

/// The ids of [TopNotices.slots].
enum NoticeSlot { card, bars, toasts }

/// Places [TopNotices.slots] but the bars (ADR 0128): the toasts' anchor
/// at `top` (under the header and the bars' row), centred over the column
/// from `left` to `right` (the chat's transcript, or the whole width), or
/// over the whole width where a toast doesn't fit the column; the card in
/// the bottom right corner of the whole of it, the main area, whatever is
/// open there (amended 2026-11-19): [TopNotices.cardInset] in from its
/// right and bottom edges, the same in every view. A toast and the card
/// stay 8 points inside the width, a toast narrowed to fit; the card never
/// above `top`.
mixin NoticesPlace on MultiChildLayoutDelegate {
  /// Lays the notices out in [size]; see [NoticesPlace].
  void placeNotices({
    required Size size,
    required double top,
    required double left,
    required double right,
  }) {
    const margin = ToastHost.margin;
    const inset = TopNotices.cardInset;
    final width = size.width;
    final room = max(0.0, width - 2 * margin);
    final card = layoutChild(NoticeSlot.card, BoxConstraints(maxWidth: room));
    final cardLeft = max(margin, width - inset - card.width);
    final cardTop = max(top, size.height - inset - card.height);
    positionChild(NoticeSlot.card, Offset(cardLeft, cardTop));
    if (!hasChild(NoticeSlot.toasts)) return;

    // A toast is at most the main area less its margins: over the column
    // where it fits, else over the whole area, and never out of it.
    final across = min(ToastHost.width, room);
    layoutChild(NoticeSlot.toasts, BoxConstraints.tight(Size(across, 0)));
    final fits = right - left >= across + 2 * margin;
    final least = margin + across / 2;
    final centre = (fits ? (left + right) / 2 : width / 2)
        .clamp(least, max(least, width - least))
        .toDouble();
    positionChild(NoticeSlot.toasts, Offset(centre - across / 2, top));
  }
}

class _Place extends MultiChildLayoutDelegate with NoticesPlace {
  @override
  void performLayout(Size size) => placeNotices(
    size: size,
    top: PaneHeader.height + ToastHost.margin,
    left: 0,
    right: size.width,
  );

  @override
  bool shouldRelayout(_Place old) => false;
}

/// The bars with controls at the foot of what a chat's area shows (the
/// transcript's turn status and composer, the Pull request tab's cards
/// waiting, Changes' commit box, a side chat's composer, a subagent's
/// box), as laid out: the update card, in the window's corner, rises above
/// any of them it would otherwise cover ([CardLift], ADR 0128).
class CardFloor extends ChangeNotifier {
  final _bars = <_Bar>{};
  double? _cut;

  /// Where the panes start, in the card's layout's space, while they lie
  /// over the view (a narrow window): a bar of the view's is hidden from
  /// there on, so the card doesn't rise for it. Null while they're beside
  /// it.
  double? get cut => _cut;
  set cut(double? at) {
    if (at == _cut) return;
    _cut = at;
    notifyListeners();
  }

  void _add(_Bar bar) {
    _bars.add(bar);
    notifyListeners();
  }

  void _remove(_Bar bar) {
    if (_bars.remove(bar)) notifyListeners();
  }

  void _moved() => notifyListeners();
}

/// Where a chat area's view and panes find its [CardFloor]; [pane] says
/// which of the two [child] is.
class CardFloors extends InheritedWidget {
  const new({
    required this.floor,
    required super.child,
    this.pane = false,
    super.key,
  });

  /// The bars the card stands above.
  final CardFloor floor;

  /// Whether it's a side pane's: never under another pane.
  final bool pane;

  static CardFloors? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardFloors>();

  @override
  bool updateShouldNotify(CardFloors old) =>
      floor != old.floor || pane != old.pane;
}

/// [child], a bar at the foot of a chat's view or pane with controls on
/// it, which the update card never covers: it's in the [CardFloor] around
/// it, if any.
class UnderCard extends SingleChildRenderObjectWidget {
  const new({super.child, super.key, this.clear = 0});

  /// How much of each end of [child]'s width is bare (a chat's foot is
  /// as wide as its view, its composer and the lines over it only its
  /// column's): the card may stand across from that much of it.
  final double clear;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final at = CardFloors._of(context);
    return _Bar(at?.floor, pane: at?.pane ?? false, clear: clear);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final at = CardFloors._of(context);
    (renderObject as _Bar).follow(
      at?.floor,
      pane: at?.pane ?? false,
      clear: clear,
    );
  }
}

class _Bar extends RenderProxyBox {
  new(this._floor, {required this.pane, required this.clear});

  CardFloor? _floor;
  bool pane;
  double clear;

  void follow(CardFloor? floor, {required bool pane, required double clear}) {
    this.pane = pane;
    if (clear != this.clear) {
      this.clear = clear;
      _floor?._moved();
    }
    if (floor == _floor) return;
    if (attached) _floor?._remove(this);
    _floor = floor;
    if (attached) _floor?._add(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _floor?._add(this);
  }

  @override
  void detach() {
    _floor?._remove(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    // Read as the card paints, after this layout.
    _floor?._moved();
  }
}

/// Where [box] rests, in the window: its parents' offsets as laid out, not
/// the transforms they paint with (a pane sliding in, the view gliding, the
/// card's own lift), so the card goes at once where it will stay rather
/// than a frame behind each step. Null while it's offstage (under a pane
/// expanded over all). `ClearOfPanes` places Jump to latest by it too.
Rect? restingRect(RenderBox box) {
  var at = Offset.zero;
  RenderObject node = box;
  for (var up = node.parent; up != null; up = node.parent) {
    if (up is RenderOffstage && up.offstage) return null;
    // A box in a box: at its offset, or at the parent's own (a proxy's
    // child has no offset of its own).
    if (up is! RenderBox || node is! RenderBox) break;
    if (node.parentData case final BoxParentData data) at += data.offset;
    node = up;
  }
  // Past what places it by offsets (a sliver), where it's drawn.
  if (node is! RenderBox) return box.localToGlobal(Offset.zero) & box.size;
  return at + node.localToGlobal(Offset.zero) & box.size;
}

/// [child] drawn and hit higher than it's laid out: the update card in the
/// window's corner, above the bars of its [floor] that it would otherwise
/// cover (a composer, which grows as it's typed in; the cards waiting; the
/// commit box). They're read as it paints, after their layout: the card is
/// never a frame behind them, and nothing is laid out again.
class CardLift extends SingleChildRenderObjectWidget {
  const new({this.floor, super.child, super.key});

  /// The bars it stands above; none while null.
  final CardFloor? floor;

  @override
  RenderObject createRenderObject(BuildContext context) => _Lifted(floor);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _Lifted).follow(floor);
}

class _Lifted extends RenderProxyBox {
  new(this._floor);

  CardFloor? _floor;

  void follow(CardFloor? floor) {
    if (floor == _floor) return;
    if (attached) _floor?.removeListener(_moved);
    _floor = floor;
    if (attached) _floor?.addListener(_moved);
    _moved();
  }

  /// How far it rises: until it's [TopNotices.cardInset] above each bar
  /// of its floor that it's across from (but for the bar's bare ends,
  /// [UnderCard.clear]), not wholly above and not hidden
  /// (offstage, or a view's bar under the panes lying over it).
  double get _lift {
    final floor = _floor;
    if (floor == null || !attached || !hasSize) return 0;
    final card = restingRect(this);
    if (card == null) return 0;
    final cut = switch ((floor.cut, parent)) {
      (final at?, final RenderBox box) => (restingRect(box)?.left ?? 0) + at,
      _ => null,
    };
    var lift = 0.0;
    for (final bar in floor._bars) {
      if (!bar.attached || !bar.hasSize) continue;
      final whole = restingRect(bar);
      if (whole == null) continue;
      // Its bare ends aside: the card may stand across from them.
      final r = Rect.fromLTRB(
        whole.left + bar.clear,
        whole.top,
        max(whole.left + bar.clear, whole.right - bar.clear),
        whole.bottom,
      );
      final right = cut != null && !bar.pane ? min(r.right, cut) : r.right;
      final across = min(right, card.right) - max(r.left, card.left);
      if (across <= 0.5 || r.bottom <= card.top) continue;
      lift = max(lift, card.bottom + TopNotices.cardInset - r.top);
    }
    return lift;
  }

  void _moved() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _floor?.addListener(_moved);
  }

  @override
  void detach() {
    _floor?.removeListener(_moved);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      super.paint(context, offset.translate(0, -_lift));

  // No check of its own box: drawn higher, the card is out of it, and a
  // lifted card's box is out of its parent's (one is in another).
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final card = child;
    if (card == null) return false;
    final hit = result.addWithPaintOffset(
      offset: Offset(0, -_lift),
      position: position,
      hitTest: (result, p) => card.hitTest(result, position: p),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) =>
      transform.translateByDouble(0, -_lift, 0, 1);
}
