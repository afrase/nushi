import AppKit

/// Keeps AppKit's title bar off the content under it (ADR 0080). With a
/// transparent title bar over full-size content, AppKit still takes the top
/// strip (the title bar's height, 32 points) for its title bar wherever no
/// view says otherwise: the theme frame's double-click recognizer zooms on
/// a double click there, and the window server drags the window from it.
/// FlutterView says nothing, so a double click on any button or tab drawn
/// in the strip zoomed the window (and a zoomed window shrank). The headers
/// do the title bar's work themselves (lib/window_drag.dart), so the strip
/// is all content.
///
/// The cover tells AppKit so: a view over the content that answers the
/// question NSButton answers (`_opaqueRectForWindowMoveWhenInTitlebar`,
/// AppKit's own, as Chromium's tab strip does) with all of itself, and
/// takes no event and draws nothing. AppKit only, so `make test-window`
/// builds it without Flutter and checks AppKit still asks.
final class TitleBarCover: NSView {
  /// Covers [content], at its size as it changes.
  static func cover(_ content: NSView) {
    let cover = TitleBarCover(frame: content.bounds)
    cover.autoresizingMask = [.width, .height]
    content.addSubview(cover)
  }

  /// Where a press or a double click in the title bar's strip is the
  /// content's, not the title bar's: all of it.
  @objc func _opaqueRectForWindowMoveWhenInTitlebar() -> NSRect { bounds }

  /// Never a press's: what's under it gets every event.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func isAccessibilityElement() -> Bool { false }
}

/// When a header's "drag" (lib/window_drag.dart) moves the window.
enum HeaderDrag {
  /// How far a press moves before it's no click, in points: Flutter's
  /// kTouchSlop, which a header counts its clicks within.
  static let clickSlop: CGFloat = 18

  /// Whether the drag of a pan whose press went down at [began] (nil: not
  /// said) moves the window, with [event] the window's current event, the
  /// left button [held] or not, and the window's last press down at
  /// [downAt], macOS's [clicks] of it, the pointer [moved] that far from
  /// where it went down. The channel is late: only a press still held
  /// moves the window, or it would follow a pointer already let go, and
  /// only the press the pan began on (a millisecond spares the engine's
  /// rounding down), or a pan of a press let go would move the window with
  /// the next one held (on a sidebar row, say). And a double click's second
  /// press only once it's gone past a click's slop: a window drag takes its
  /// release, so the header would miss the double click (a press that moved
  /// a point or two between its clicks is a pan in Flutter, and Flutter
  /// counts its release still), but a press that far is no click, and a
  /// click then a drag at once moves the window as a title bar's does.
  static func moves(
    event: NSEvent.EventType, held: Bool, began: TimeInterval?, downAt: TimeInterval, clicks: Int,
    moved: CGFloat
  ) -> Bool {
    (event == .leftMouseDragged || event == .leftMouseDown) && held
      && (began.map { $0 + 0.001 >= downAt } ?? true) && (clicks < 2 || moved > clickSlop)
  }
}
