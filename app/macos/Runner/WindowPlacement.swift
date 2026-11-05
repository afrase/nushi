import Cocoa

/// Keeps the window where the user put it, across launches, zooms and
/// displays that come and go (ADR 0093). Nushi saves the place itself
/// (`NushiWindowPlacement`) instead of under an autosave name: setting
/// one made AppKit put the window on the main screen first and keep that
/// frame as the one a zoom goes back to, so a double click in the header
/// later tweened the window from its own display to the main one.
/// The maths is Placement's.
final class WindowPlacement {
  private static let key = "NushiWindowPlacement"
  /// What AppKit saved under the old autosave name, read once to migrate.
  private static let legacyKey = "NSWindow Frame Nushi"

  private weak var window: NSWindow?
  /// The window's place as last saved: its home while its display is gone.
  private var saved: Placement.Saved?
  /// The frame a zoom goes back to.
  private var user: CGRect?
  /// Set while Nushi itself moves the window into place (not saved as a move).
  private var restoring = false
  /// The window's own display is gone and macOS moved it: only the user's
  /// own move is saved until it's back.
  private var lost = false
  /// Since the last save, a move the user made (a drag, a live resize, a zoom).
  private var userMoved = false
  /// A drag of the user's is under way, watched until its button is up:
  /// the window server may send didMove only after that.
  private var dragWatch: Timer?
  /// When the last drag's button came up.
  private var dragEndedAt: TimeInterval = -.infinity
  private var zoomUntil: TimeInterval = 0
  private var screensChangedAt: TimeInterval = -.infinity
  /// Until when a full-screen transition may still be moving the window
  /// (its end clears it; a transition that fails sends no end).
  private var transitionUntil: TimeInterval = 0
  private var pendingSave: DispatchWorkItem?
  private var pendingScreens: DispatchWorkItem?
  private var observers: [NSObjectProtocol] = []

  init(window: NSWindow) { self.window = window }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
    dragWatch?.invalidate()
  }

  /// Puts the window back where it was saved, before it's ordered in (and
  /// before full screen goes back on: that keeps the frame from before).
  /// No autosave name and no window restoration: AppKit then never places
  /// the window itself, never applies a saved tile and never keeps a zoom
  /// frame of its own.
  func restore() {
    guard let window else { return }
    window.isRestorable = false
    let defaults = UserDefaults.standard
    saved = defaults.dictionary(forKey: Self.key).flatMap(Placement.Saved.init)
      ?? Placement.legacy(defaults.string(forKey: Self.legacyKey)).map {
        Placement.Saved(frame: $0, display: "", screen: .zero, user: nil)
      }
    user = saved?.user
    let screens = Self.screens()
    if let home = saved, !home.display.isEmpty, !screens.contains(where: { $0.id == home.display }) { lost = true }
    restoring = true
    if let saved, let placed = Placement.place(saved, on: screens) {
      window.setFrame(placed.frame, display: false)
      user = placed.user
      if !lost { write(window.frame, on: placed.screen) }
    } else {
      window.center()
    }
    restoring = false
    observe()
  }

  /// The window's zoom (performZoom, the menu's Zoom, the green button's
  /// Option-click, a double click in the header): on the screen the window
  /// is on, back to the user's frame there. Nothing in full screen.
  func zoom() {
    guard let window, !window.styleMask.contains(.fullScreen), let screen = window.screen else { return }
    let z = Placement.zoom(frame: window.frame, visible: screen.visibleFrame, user: user)
    user = z.user
    zoomUntil = ProcessInfo.processInfo.systemUptime + window.animationResizeTime(z.target) + 0.3
    userMoved = true
    window.setFrame(z.target, display: true, animate: true)
    scheduleSave()
  }

  /// The user pressed to drag the window (a header's drag, before
  /// performDrag): its moves are the user's, however late they come.
  func dragBegan() {
    guard !restoring, dragWatch == nil else { return }
    let watch = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
      guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
      timer.invalidate()
      self?.dragWatch = nil
      self?.dragEndedAt = ProcessInfo.processInfo.systemUptime
    }
    RunLoop.main.add(watch, forMode: .common)
    dragWatch = watch
  }

  private func observe() {
    let center = NotificationCenter.default
    func on(_ name: Notification.Name, _ object: Any?, _ act: @escaping (WindowPlacement) -> Void) {
      observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
        if let self { act(self) }
      })
    }
    // Posted as a title-bar drag starts, with the button still held.
    on(NSWindow.willMoveNotification, window) {
      if NSEvent.pressedMouseButtons & 1 != 0 { $0.dragBegan() }
    }
    for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification] {
      on(name, window) { $0.noteMoved() }
    }
    for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification] {
      on(name, window) { $0.transitionUntil = ProcessInfo.processInfo.systemUptime + 3 }
    }
    for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
      on(name, window) {
        $0.transitionUntil = 0
        $0.scheduleSave()
      }
    }
    on(NSWindow.willCloseNotification, window) { $0.saveNow() }
    on(NSApplication.willTerminateNotification, nil) { $0.saveNow() }
    on(NSApplication.didChangeScreenParametersNotification, nil) { $0.screensChanging() }
  }

  /// A move or a resize: the user's during a drag of theirs or up to a
  /// second after its button came up (a drag's didMove may come only
  /// then), with the left button held (a live resize) or in our zoom. A
  /// press that moved nothing leaves no drag behind. The save waits for
  /// the moves to stop.
  private func noteMoved() {
    guard !restoring else { return }
    let now = ProcessInfo.processInfo.systemUptime
    if dragWatch != nil || now - dragEndedAt < 1 || NSEvent.pressedMouseButtons & 1 != 0 || now < zoomUntil {
      userMoved = true
    }
    scheduleSave()
  }

  private func scheduleSave() {
    pendingSave?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.save() }
    pendingSave = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
  }

  private func saveNow() {
    pendingSave?.cancel()
    save()
  }

  /// Saves where the window is, but not in full screen or the Dock, and,
  /// while its own display is gone or the displays have just changed, only
  /// a move of the user's: macOS's own move off a display that went is not
  /// where the user wants it. A user's move while lost is the new home.
  private func save() {
    pendingSave = nil
    guard let window, !window.styleMask.contains(.fullScreen), !window.isMiniaturized,
      ProcessInfo.processInfo.systemUptime >= transitionUntil, let screen = window.screen else { return }
    let homeGone = saved.map { home in
      !home.display.isEmpty && !Self.screens().contains(where: { $0.id == home.display })
    } ?? false
    let settling = ProcessInfo.processInfo.systemUptime - screensChangedAt < 0.8
    if lost || homeGone || settling {
      guard userMoved else { return }
      lost = false
    }
    userMoved = false
    write(window.frame, on: Self.screen(screen))
  }

  private func write(_ frame: CGRect, on screen: Placement.Screen) {
    let record = Placement.Saved(frame: frame, display: screen.id, screen: screen.frame, user: user)
    saved = record
    UserDefaults.standard.set(record.dict, forKey: Self.key)
  }

  /// The displays changed: a reconnect comes in steps, so this waits for
  /// them to stop. A display that only sleeps stays connected, and nothing
  /// happens. Home's display missing is seen at once, not after the wait:
  /// one that drops and comes back within it (a dock or a KVM that
  /// flaps) has still had the window moved off it.
  private func screensChanging() {
    screensChangedAt = ProcessInfo.processInfo.systemUptime
    if let home = saved, !home.display.isEmpty, !Self.screens().contains(where: { $0.id == home.display }) {
      lost = true
    }
    pendingScreens?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.screensChanged() }
    pendingScreens = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
  }

  /// Home's display gone: lost, until it's back or the user moves the
  /// window. Back, with the window still where macOS put it: home again.
  private func screensChanged() {
    pendingScreens = nil
    guard let window, let home = saved, !home.display.isEmpty else { return }
    let screens = Self.screens()
    guard screens.contains(where: { $0.id == home.display }) else {
      lost = true
      return
    }
    guard lost, !window.styleMask.contains(.fullScreen) else { return }
    lost = false
    guard let back = Placement.returnFrame(home: home, screens: screens, current: window.screen.map(Self.id))
    else { return }
    // A zoom then goes back to the user's frame where the display is now.
    user = back.user
    restoring = true
    window.setFrame(back.frame, display: true)
    restoring = false
    if let screen = window.screen { write(window.frame, on: Self.screen(screen)) }
  }

  private static func screens() -> [Placement.Screen] {
    NSScreen.screens.map(screen)
  }

  private static func screen(_ s: NSScreen) -> Placement.Screen {
    Placement.Screen(id: id(s), frame: s.frame, visible: s.visibleFrame)
  }

  /// A display's UUID, which outlasts a reconnect (its CGDirectDisplayID
  /// may not).
  private static func id(_ screen: NSScreen) -> String {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
      return screen.localizedName
    }
    let display = CGDirectDisplayID(number.uint32Value)
    guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue(),
      let text = CFUUIDCreateString(nil, uuid) else { return String(display) }
    return text as String
  }
}
