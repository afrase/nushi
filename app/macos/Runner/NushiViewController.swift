import Cocoa
import FlutterMacOS

/// The window's FlutterViewController, through which every call that tells
/// the engine of the mouse goes (ADR 0080, amended 2026-11-19): AppKit's
/// events, whichever view took them (the drop target over Flutter's view,
/// the text input's), and the releases made up here. [mouse] keeps what the
/// engine was told, call for call, so the guard knows exactly which buttons
/// it holds, and tells it the release of any that isn't held:
///
/// - before a press goes on: the engine still holding that button, or one
///   not held, would take the press for a move of the old one;
/// - as the pointer moves with no button held (a move, not a drag, means
///   none was held as it moved);
/// - from a watch that looks every twentieth of a second while the engine
///   holds a button, for a release that never came and no event after it
///   (the window server drags the window, the window isn't key, the app is
///   behind another): stale at two looks in a row with no event between,
///   as one could be a release still queued.
///
/// A made-up release goes where the engine last heard the pointer, so it
/// moves nothing; the real one, if it comes after, is dropped. And a
/// trackpad gesture's end the engine never had is handed to it
/// ([gestureEnding]).
final class NushiViewController: FlutterViewController {
  /// What the engine was told of the mouse.
  private(set) var mouse = EngineMouse()

  /// Whether the engine holds the left button: a press of it went to
  /// Flutter and its release hasn't.
  var holdsLeft: Bool { mouse.buttons & 1 != 0 }

  /// Told of each release made up here (or gesture end handed on): what
  /// it was for (a button, a gesture's kind) and which check found it.
  var onRepair: ((_ what: String, _ check: String) -> Void)?

  /// Why a watch's look found a button stale, for the log: what kept the
  /// release from the app, as far as the window can tell.
  var lookWhy: () -> String = { "watch" }

  /// Where the engine last heard the pointer, in the window.
  private var lastAt: NSPoint?

  /// Looks at the buttons while the engine holds one.
  private var watch: Timer?

  init() { super.init(nibName: nil, bundle: nil) }

  required init(coder: NSCoder) { super.init(coder: coder) }

  override func mouseDown(with event: NSEvent) { press(0, event) { super.mouseDown(with: $0) } }
  override func rightMouseDown(with event: NSEvent) { press(1, event) { super.rightMouseDown(with: $0) } }
  override func otherMouseDown(with event: NSEvent) {
    press(event.buttonNumber, event) { super.otherMouseDown(with: $0) }
  }

  override func mouseUp(with event: NSEvent) { release(0, event) { super.mouseUp(with: $0) } }
  override func rightMouseUp(with event: NSEvent) { release(1, event) { super.rightMouseUp(with: $0) } }
  override func otherMouseUp(with event: NSEvent) {
    release(event.buttonNumber, event) { super.otherMouseUp(with: $0) }
  }

  override func mouseDragged(with event: NSEvent) { move(event) { super.mouseDragged(with: $0) } }
  override func rightMouseDragged(with event: NSEvent) { move(event) { super.rightMouseDragged(with: $0) } }
  override func otherMouseDragged(with event: NSEvent) { move(event) { super.otherMouseDragged(with: $0) } }

  /// A move with no button held: none was held as the pointer moved, so
  /// any the engine holds lost its release (a release still to come would
  /// have come before this move).
  override func mouseMoved(with event: NSEvent) {
    for n in mouse.stale(held: Self.held()) { letGo(n, check: "move") }
    move(event) { super.mouseMoved(with: $0) }
  }

  override func scrollWheel(with event: NSEvent) { gesture(.scroll, event) { super.scrollWheel(with: $0) } }
  override func magnify(with event: NSEvent) { gesture(.magnify, event) { super.magnify(with: $0) } }
  override func rotate(with event: NSEvent) { gesture(.rotate, event) { super.rotate(with: $0) } }

  override func mouseEntered(with event: NSEvent) {
    if mouse.entered() != .none { lastAt = event.locationInWindow }
    super.mouseEntered(with: event)
  }

  override func mouseExited(with event: NSEvent) {
    if mouse.exited() != .none { lastAt = event.locationInWindow }
    super.mouseExited(with: event)
  }

  /// A real press of [n] seen anywhere in the window, before it goes on
  /// (to the engine or elsewhere): any button the engine holds that this
  /// press shows was let go is let go first.
  func pressing(_ n: Int) {
    for stale in mouse.real(pressed: n, held: Self.held()) { letGo(stale, check: "press", owing: stale != n) }
  }

  /// A trackpad gesture's end seen in the window, before it goes on: if it
  /// goes to another view (a web view the content moved under the pointer
  /// takes the gesture's later events), the engine never has it, and its
  /// gesture goes on for good: a drag it fed stays alive, and every later
  /// gesture is sent as more of it. So once the event has been handled,
  /// an end the engine didn't get is given to it. The first block to run
  /// takes every end seen, each by its own kind: a scroll's and a
  /// magnify's ending in the same pass are both repaired, not only the
  /// kind that queued the block.
  func gestureEnding(_ event: NSEvent) {
    guard Self.kind(event) != nil, [.ended, .cancelled].contains(Self.phase(event)) else { return }
    endsSeen.append(event)
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let seen = self.endsSeen
      self.endsSeen = []
      for end in seen {
        if let kind = Self.kind(end), self.mouse.owesEnd(kind) {
          self.gesture(kind, end, check: "gesture end", self.engineGesture)
        }
      }
    }
  }

  /// Gesture ends seen in the window and not yet had by the engine.
  private var endsSeen: [NSEvent] = []

  /// Whether the engine already had a made-up release for [n]: the real one
  /// is no click.
  func owes(_ n: Int) -> Bool { mouse.owes(n) }

  /// Looks now, at a moment events may still be queued (a notification's):
  /// only starts the watch, which looks twice.
  func lookSoon() { keepWatching() }

  private func press(_ n: Int, _ event: NSEvent, _ forward: (NSEvent) -> Void) {
    pressing(n)
    _ = mouse.pressed(n)
    lastAt = event.locationInWindow
    forward(event)
    keepWatching()
  }

  private func release(_ n: Int, _ event: NSEvent, _ forward: (NSEvent) -> Void) {
    guard mouse.real(released: n) else { return }
    _ = mouse.released(n)
    lastAt = event.locationInWindow
    forward(event)
  }

  private func move(_ event: NSEvent, _ forward: (NSEvent) -> Void) {
    _ = mouse.moved()
    lastAt = event.locationInWindow
    forward(event)
  }

  private func gesture(_ kind: EngineMouse.Gesture, _ event: NSEvent, check: String? = nil, _ forward: (NSEvent) -> Void) {
    endsSeen.removeAll { $0 === event }
    _ = mouse.gesture(kind, Self.phase(event), momentum: !event.momentumPhase.isEmpty)
    forward(event)
    if let check { onRepair?("\(kind)", check) }
  }

  /// Hands the engine a gesture's event.
  private func engineGesture(_ event: NSEvent) {
    switch event.type {
    case .scrollWheel: super.scrollWheel(with: event)
    case .magnify: super.magnify(with: event)
    case .rotate: super.rotate(with: event)
    default: break
    }
  }

  private static func kind(_ event: NSEvent) -> EngineMouse.Gesture? {
    switch event.type {
    case .scrollWheel: .scroll
    case .magnify: .magnify
    case .rotate: .rotate
    default: nil
    }
  }

  /// An event's phase as the engine reads it (its own, not the momentum's).
  private static func phase(_ event: NSEvent) -> EngineMouse.GesturePhase {
    let p = event.phase
    if p.contains(.mayBegin) { return .mayBegin }
    if p.contains(.began) { return .began }
    if p.contains(.changed) { return .changed }
    if p.contains(.stationary) { return .stationary }
    if p.contains(.ended) { return .ended }
    if p.contains(.cancelled) { return .cancelled }
    return .none
  }

  /// The buttons held now, as the engine numbers them.
  private static func held() -> UInt64 { UInt64(NSEvent.pressedMouseButtons) }

  /// Tells the engine [n] was let go, where it last heard the pointer.
  private func letGo(_ n: Int, check: String, owing: Bool = true) {
    guard let window = view.window else { return }
    let at = lastAt ?? window.mouseLocationOutsideOfEventStream
    let type: NSEvent.EventType = n == 0 ? .leftMouseUp : n == 1 ? .rightMouseUp : .otherMouseUp
    guard
      var up = NSEvent.mouseEvent(
        with: type, location: at, modifierFlags: NSEvent.modifierFlags,
        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 0)
    else { return }
    if n > 1 {
      // AppKit makes no other button's event by number: its CGEvent can.
      guard let cg = up.cgEvent?.copy() else { return }
      cg.setIntegerValueField(.mouseEventButtonNumber, value: Int64(n))
      guard let other = NSEvent(cgEvent: cg), other.buttonNumber == n else { return }
      up = other
    }
    _ = mouse.letGo(n, owing: owing)
    switch n {
    case 0: super.mouseUp(with: up)
    case 1: super.rightMouseUp(with: up)
    default: super.otherMouseUp(with: up)
    }
    onRepair?(buttonName(n), check)
  }

  private func keepWatching() {
    guard watch == nil, mouse.buttons != 0 else { return }
    let watch = Timer(timeInterval: 0.05, repeats: true) { [weak self] timer in
      guard let self, self.mouse.buttons != 0 else {
        timer.invalidate()
        self?.watch = nil
        return
      }
      let stale = self.mouse.look(held: Self.held())
      if !stale.isEmpty {
        let why = self.lookWhy()
        for n in stale { self.letGo(n, check: why) }
      }
    }
    // In every mode: a window drag and a menu's tracking run in their own.
    RunLoop.main.add(watch, forMode: .common)
    self.watch = watch
  }
}
