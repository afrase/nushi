import CoreGraphics
import Foundation

/// Where Nushi's window goes (ADR 0093): which screen a saved frame belongs
/// to, a frame fitted to a screen, and the zoom toggle. Plain maths on
/// rects in AppKit's screen coordinates, with no window or AppKit, so
/// `make test-window` builds and runs it with swiftc alone.
enum Placement {
  /// A connected screen: its display's UUID, its frame and the part a
  /// window may use (without the menu bar and the Dock).
  struct Screen: Equatable {
    var id: String
    var frame: CGRect
    var visible: CGRect
  }

  /// The window's place as saved under `NushiWindowPlacement`: its frame,
  /// the display it was on and that screen's frame then (so a display moved
  /// in the arrangement takes the window with it), and the frame a zoom
  /// would go back to.
  struct Saved: Equatable {
    var frame: CGRect
    var display: String
    var screen: CGRect
    var user: CGRect?

    init(frame: CGRect, display: String, screen: CGRect, user: CGRect?) {
      self.frame = frame
      self.display = display
      self.screen = screen
      self.user = user
    }

    /// The saved dictionary, or nil when its frame is missing or not a rect.
    init?(_ dict: [String: Any]) {
      guard let frame = Placement.rect(dict["frame"] as? String) else { return nil }
      self.frame = frame
      display = dict["display"] as? String ?? ""
      screen = Placement.rect(dict["screen"] as? String) ?? .zero
      user = Placement.rect(dict["user"] as? String)
    }

    /// What goes in the user defaults: rects as "x y w h".
    var dict: [String: Any] {
      var d: [String: Any] = ["frame": Placement.text(frame), "display": display, "screen": Placement.text(screen)]
      if let user { d["user"] = Placement.text(user) }
      return d
    }
  }

  /// A rect from "x y w h" (anything after the fourth number is ignored),
  /// or nil when it isn't one with a width and a height.
  static func rect(_ text: String?) -> CGRect? {
    guard let n = text?.split(separator: " ").prefix(4).compactMap({ Double($0) }), n.count == 4,
      n[2] > 0, n[3] > 0 else { return nil }
    return CGRect(x: n[0], y: n[1], width: n[2], height: n[3])
  }

  /// A rect as "x y w h".
  static func text(_ r: CGRect) -> String {
    [r.minX, r.minY, r.width, r.height].map { String(Double($0)) }.joined(separator: " ")
  }

  /// The frame AppKit saved under the old autosave name ("NSWindow Frame
  /// Nushi": the frame, the screen's, then a tile state), read once to
  /// move to `NushiWindowPlacement`.
  static func legacy(_ text: String?) -> CGRect? { rect(text) }

  /// [f] no bigger than [room] and moved inside it, as little as it takes.
  static func fit(_ f: CGRect, in room: CGRect) -> CGRect {
    let w = min(f.width, room.width), h = min(f.height, room.height)
    return CGRect(x: min(max(f.minX, room.minX), room.maxX - w),
                  y: min(max(f.minY, room.minY), room.maxY - h), width: w, height: h)
  }

  /// Where a saved place goes on the connected screens: on its own display
  /// when that is connected, moved as far as the display moved since, or
  /// else on the screen most of the frame lies on; fitted to that screen's
  /// visible part. Nil when the frame lies on none. The user frame moves
  /// with the window.
  static func place(_ s: Saved, on screens: [Screen]) -> (screen: Screen, frame: CGRect, user: CGRect?)? {
    if let own = screens.first(where: { $0.id == s.display && !s.display.isEmpty }) {
      let dx = s.screen.isEmpty ? 0 : own.frame.minX - s.screen.minX
      let dy = s.screen.isEmpty ? 0 : own.frame.minY - s.screen.minY
      return (own, fit(s.frame.offsetBy(dx: dx, dy: dy), in: own.visible), s.user?.offsetBy(dx: dx, dy: dy))
    }
    func overlap(_ screen: Screen) -> CGFloat {
      let shared = screen.visible.intersection(s.frame)
      return shared.isNull ? 0 : shared.width * shared.height
    }
    guard let best = screens.max(by: { overlap($0) < overlap($1) }), overlap(best) > 0 else { return nil }
    return (best, fit(s.frame, in: best.visible), s.user)
  }

  /// Whether two frames are the same to within [tol] points on every edge.
  static func same(_ a: CGRect, _ b: CGRect, tol: CGFloat = 10) -> Bool {
    abs(a.minX - b.minX) <= tol && abs(a.minY - b.minY) <= tol
      && abs(a.maxX - b.maxX) <= tol && abs(a.maxY - b.maxY) <= tol
  }

  /// The zoom toggle on the window's own screen ([visible] is its visible
  /// part): a window that fills it goes back to the user's frame, when that
  /// lies on this screen and isn't itself a filled one, or else to a frame
  /// 10% in from each side; any other window fills it, and its frame
  /// becomes the user's. The target never leaves this screen, unlike
  /// AppKit's own zoom, which goes back to a frame it kept from wherever
  /// the window was put first.
  static func zoom(frame: CGRect, visible: CGRect, user: CGRect?) -> (target: CGRect, user: CGRect?) {
    guard same(frame, visible) else { return (visible, frame) }
    if let user, visible.contains(CGPoint(x: user.midX, y: user.midY)), !same(user, visible) {
      return (fit(user, in: visible), user)
    }
    return (visible.insetBy(dx: visible.width * 0.1, dy: visible.height * 0.1), user)
  }

  /// Where the window goes back to when its own display ([home]'s) is
  /// connected again after the system moved it off: home's place, unless
  /// the window is on that display already ([current]). Nil when home's
  /// display is still missing.
  static func returnFrame(home: Saved, screens: [Screen], current: String?) -> CGRect? {
    guard !home.display.isEmpty, current != home.display, screens.contains(where: { $0.id == home.display })
    else { return nil }
    return place(home, on: screens)?.frame
  }
}
