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

