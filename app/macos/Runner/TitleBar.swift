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

/// Where the window's buttons (the traffic lights) sit (ADR 0111): level
/// with the middle of the headers, which stand in for the title bar, and in
/// from the window's edge as far as the sidebar's rows are. AppKit puts
/// them in the middle of a title bar 32 high, which was 20 points above
/// the header's middle and a point inside the main pane's corner with the
/// sidebar hidden. The same place whether the sidebar shows or not: the
/// sidebar's top strip and a header with the sidebar hidden both leave
/// them room (lib/sidebar.dart, lib/sidebar_button.dart).
///
/// AppKit has no setting for it, so the title bar's container is made tall
/// enough that its middle is the header's, and the buttons are put in that
/// middle, as other apps with a taller bar of their own do. AppKit lays
/// the bar out again when the window is resized, becomes or stops being
/// key or main, leaves full screen or first shows, so [keep] puts them
/// back each time.
/// In full screen the buttons are AppKit's own, in the bar that drops down
/// with the menu bar, and nothing is placed.
enum WindowButtons {
  /// A header's middle from the window's top: the window's margin (8)
  /// and half a header's height (56), `NushiTheme.windowPad` and
  /// `PaneHeader.height`.
  static let middle: CGFloat = 36
  /// The first button's leading edge from the window's: where the
  /// sidebar's rows' words start.
  static let leading: CGFloat = 20

  /// The title bar's container in a window [windowHeight] high, [width]
  /// wide: at the window's top, its middle the header's.
  static func barFrame(windowHeight: CGFloat, width: CGFloat) -> NSRect {
    NSRect(x: 0, y: windowHeight - 2 * middle, width: width, height: 2 * middle)
  }

  /// Where the button that AppKit put at [frame] goes in a bar
  /// [barHeight] high: [leading] in, less where the first one was
  /// ([first], so the buttons keep AppKit's spacing), and in the bar's
  /// middle.
  static func origin(of frame: NSRect, first: NSRect, barHeight: CGFloat) -> NSPoint {
    NSPoint(x: leading + frame.minX - first.minX, y: ((barHeight - frame.height) / 2).rounded())
  }

  private static let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

  /// Puts [window]'s buttons in their place, unless it's in full screen,
  /// lays its bar out from the right, or has none.
  static func place(in window: NSWindow) {
    guard !window.styleMask.contains(.fullScreen),
      window.windowTitlebarLayoutDirection == .leftToRight,
      let close = window.standardWindowButton(.closeButton),
      let container = close.superview?.superview
    else { return }
    let bar = barFrame(windowHeight: window.frame.height, width: container.frame.width)
    if container.frame != bar { container.frame = bar }
    let buttons = kinds.compactMap { window.standardWindowButton($0) }
    // AppKit's own spacing, read before any is moved: the first one's
    // place is what the others are measured from.
    let first = close.frame
    let places = buttons.map { origin(of: $0.frame, first: first, barHeight: bar.height) }
    for (button, place) in zip(buttons, places) where button.frame.origin != place {
      button.setFrameOrigin(place)
    }
  }

  /// Keeps [window]'s buttons in their place for as long as it lives:
  /// placed now, and again whenever AppKit may have laid its title bar out.
  /// A resize does, in the same pass (so they never show at AppKit's place
  /// while the window is dragged larger), as does becoming key or main and
  /// leaving full screen; and AppKit lays the bar out at times that post
  /// nothing of their own (as the window first shows, when it isn't the
  /// key one), so each of the window's updates, one per pass of the event
  /// loop, looks too: a look that finds them in place changes nothing.
  static func keep(in window: NSWindow) {
    place(in: window)
    let center = NotificationCenter.default
    for name in [
      NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
      NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
      NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification,
      NSWindow.didExitFullScreenNotification, NSWindow.didUpdateNotification,
    ] {
      center.addObserver(forName: name, object: window, queue: nil) { [weak window] _ in
        if let window { place(in: window) }
      }
    }
  }
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
