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

/// A header's press (lib/window_drag.dart) as the window's press monitor
/// sees it, from the press to Flutter's release: when it moves the window
/// and how Flutter hears it let go (ADR 0080). Plain state with no AppKit
/// calls, so `make test-window` runs it.
///
/// The window moves only from the monitor, as it handles the press's own
/// dragged event, in the order the events came: the header only arms the
/// press, over a channel that comes late. A drag started later, from that
/// call, could reach the window server after the release, and the window
/// then followed the pointer with no button held. And `performDrag` returns
/// at once while the window server runs the drag, which takes the release
/// (it may never reach the app): Flutter gets its release when the button
/// is seen up, not before, and once.
struct HeaderDrag {
  /// How far a press moves before Flutter's pan takes it, in points: its
  /// kPrecisePointerPanSlop, a mouse's. The header's pan starts there, so
  /// a press that moves less is a click and never moves the window.
  static let panSlop: CGFloat = 2
  /// How far a press moves before it's no click, in points: Flutter's
  /// kTouchSlop, which a header counts its clicks within.
  static let clickSlop: CGFloat = 18

  /// What the monitor does with an event.
  enum Step: Equatable {
    /// The event goes on as it is.
    case pass
    /// The window moves with this event (`performDrag`), which then goes on
    /// to Flutter: its pan sees the move it starts with.
    case moveWindow
    /// Flutter is told its last press was let go, then the press goes on.
    case releaseFirst
    /// The release of a press that moved the window: Flutter's one release,
    /// but no click of a title bar's.
    case dragReleased
    /// The release of a press Flutter already had its release for: dropped.
    case drop
  }

  /// When the last press went down (NSEvent.timestamp), where in the
  /// window, and macOS's click count of it.
  private var downAt: TimeInterval = -.infinity
  private var downPoint = CGPoint.zero
  private var clicks = 0
  /// Flutter may hold a press it has had no release for.
  private(set) var pressed = false
  /// The header armed the press: it moves the window once it moves enough.
  private var armed = false
  /// The window server is dragging the window with the press, and Flutter
  /// is owed its release.
  private(set) var dragging = false
  /// Flutter had the dragged press's release from the window: the real one,
  /// if it comes, is dropped.
  private var releaseSent = false

  /// A press went down. Flutter still holding the last one (its release
  /// went to the window server, or a web view's tracking took it) would
  /// take this one for a move of it, so it's let go first.
  mutating func down(at time: TimeInterval, clicks: Int, at point: CGPoint) -> Step {
    let owed = pressed
    (downAt, self.clicks, downPoint) = (time, clicks, point)
    (pressed, armed, dragging, releaseSent) = (true, false, false, false)
    return owed ? .releaseFirst : .pass
  }

  /// The header says the press that went down at [began] (the engine's
  /// time of its down, NSEvent.timestamp rounded down to a microsecond)
  /// may move the window. The call is late: a press already let go, or an
  /// earlier one than the press now held, arms nothing.
  mutating func arm(began: TimeInterval) {
    guard pressed, !dragging, began + 0.001 >= downAt else { return }
    armed = true
  }

  /// The press moved to [point] with the left button [held] now (not as
  /// of the event: a release still queued shows here). An armed press
  /// moves the window once it's past the pan's slop, and a double click's
  /// second press (or third) only once it's past a click's: a window drag
  /// takes its release, so the header would miss the double click, but a
  /// press that far is no click, and a click then a drag at once moves the
  /// window as a title bar's does.
  mutating func dragged(to point: CGPoint, held: Bool) -> Step {
    guard armed, held, !dragging else { return .pass }
    let slop = clicks < 2 ? Self.panSlop : Self.clickSlop
    guard hypot(point.x - downPoint.x, point.y - downPoint.y) > slop else { return .pass }
    (armed, dragging) = (false, true)
    return .moveWindow
  }

  /// The press's release reached the app.
  mutating func up() -> Step {
    defer { (pressed, armed, dragging, releaseSent) = (false, false, false, false) }
    if releaseSent { return .drop }
    return dragging ? .dragReleased : .pass
  }

  /// Whether to tell Flutter now that its press was let go, with the left
  /// button [held] or not now: a pointer that moves, or a look while the
  /// window is dragged, with no button held after a press whose release
  /// never came. Once for a press.
  mutating func letGo(held: Bool) -> Bool {
    guard pressed, !held else { return false }
    if dragging { releaseSent = true }
    (pressed, armed, dragging) = (false, false, false)
    return true
  }
}
