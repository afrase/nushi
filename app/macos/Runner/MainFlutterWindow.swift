import Cocoa
import FlutterMacOS
import ServiceManagement
import WebKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = NushiViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // No title bar: the content runs to the top, under the traffic lights.
    // Before the saved frame goes back: this keeps the content's size, so
    // after it the window would lose the title bar's height each launch.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    // And AppKit's title bar keeps off the content under it: the headers
    // are the title bar (lib/window_drag.dart).
    TitleBarCover.cover(flutterViewController.view)
    // And its buttons sit level with the headers, not in the middle of a
    // title bar that isn't there (ADR 0111).
    WindowButtons.keep(in: self)
    placement.restore()
    keepFullScreen()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The installed font families, for the font settings: every one (the
    // app's font), and the monospaced ones (the terminal's and code's).
    // Those are worked out once, off the main thread: making an NSFont of
    // every family to ask it took about a second on a Mac with many fonts,
    // and the window froze for it each time Settings › Terminal opened.
    FlutterMethodChannel(name: "nushi/fonts", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "monospaced": Self.monospaced { families in result(families) }
        case "families": result(Self.families())
        default: result(FlutterMethodNotImplemented)
        }
      }

    // What a title bar did (lib/window_drag.dart).
    FlutterMethodChannel(name: "nushi/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "arm":
          // A press on a header's drag area, at its down's time in the
          // engine's microseconds of NSEvent.timestamp: it may move the
          // window, which the press monitor does (HeaderDrag).
          if let began = call.arguments as? NSNumber { self?.headerDrag.arm(began: began.doubleValue / 1_000_000) }
          result(nil)
        case "zoom":
          self?.titleBarDoubleClick()
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }

    // The web views' channel and the default browser's (Browser.swift).
    browser = Browser(flutterViewController)

    // Mermaid diagrams (lib/mermaid.dart): the page's path for the preview
    // pane's web view, and a block drawn as a PNG by one hidden web view.
    let diagrams = Diagrams()
    FlutterMethodChannel(name: "nushi/mermaid", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "page": result(Diagrams.page.path)
        case "draw":
          guard let args = call.arguments as? [String: Any], let source = args["source"] as? String else {
            return result(FlutterError(code: "refused", message: "No diagram", details: nil))
          }
          diagrams.draw(source: source, args: args, done: result)
        default: result(FlutterMethodNotImplemented)
        }
      }

    // Notifications and the Dock badge (lib/alerts.dart).
    let alerts = FlutterMethodChannel(name: "nushi/alerts", binaryMessenger: flutterViewController.engine.binaryMessenger)
    Alerts.shared.channel = alerts
    alerts.setMethodCallHandler { call, result in Alerts.shared.handle(call, result) }

    // Spell check for the composer (lib/spell_check.dart, ADR 0083).
    let spelling = Spelling()
    FlutterMethodChannel(name: "nushi/spelling", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in spelling.handle(call, result) }

    // Start at login (ADR 0036): the launch agent in the bundle, which opens
    // the daemon's helper app. Answers its status after each call.
    let agent = SMAppService.agent(plistName: "com.nushihq.Nushi.daemon.plist")
    FlutterMethodChannel(name: "nushi/login", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        do {
          switch call.method {
          case "status": break
          case "set": try call.arguments as? Bool == true ? agent.register() : agent.unregister()
          case "openSettings": SMAppService.openSystemSettingsLoginItems()
          default: return result(FlutterMethodNotImplemented)
          }
        } catch {
          return result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        }
        let status: String = switch agent.status {
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notRegistered: "notRegistered"
        default: "notFound"
        }
        result(status)
      }

    // A three-finger swipe right, when macOS's "Swipe between pages" is set
    // to three fingers, goes back (lib/back_swipe.dart): it comes as an
    // NSEvent swipe, which FlutterViewController drops, so it's taken here
    // first, with where it was in the view (Flutter's logical pixels).
    // AppKit's deltaX is positive for the swipe that goes back, as in
    // Safari and Chromium. Two fingers come as pan/zoom, to Flutter.
    let swipes = FlutterMethodChannel(name: "nushi/swipe", binaryMessenger: flutterViewController.engine.binaryMessenger)
    let flutterView = flutterViewController.view
    swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) { [weak self] event in
      guard event.window === self, event.deltaX > 0 else { return event }
      let p = flutterView.convert(event.locationInWindow, from: nil)
      swipes.invokeMethod("back", arguments: [p.x, flutterView.isFlipped ? p.y : flutterView.bounds.height - p.y])
      return nil
    }

    // A header's press moves the window here, as its dragged event comes
    // (HeaderDrag, ADR 0080). Every press in the window, wherever it goes,
    // first has the engine let go of any button it holds that this press
    // shows was let go (NushiViewController): a press that goes to a web
    // view, the traffic lights or the window's edge never reaches the
    // engine. A press the engine has keeps its drag and its release: they
    // are handed to it here, not left to AppKit to route (amended
    // 2026-11-19). It also notes when a press, its release or a key goes to a
    // web view, which is a user's own act in a page (a preview's link opens
    // in the browser only right after one).
    pressMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [
        .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel,
        .magnify, .rotate,
      ]
    ) { [weak self] event in
      guard let self, event.window === self else { return event }
      switch event.type {
      case .leftMouseDragged:
        if self.headerDrag.dragged(to: event.locationInWindow, held: NSEvent.pressedMouseButtons & 1 != 0) {
          self.moveWindow(with: event)
        } else if flutterViewController.holdsLeft {
          // Flutter's press: its drag is Flutter's too, whatever is under
          // the pointer now. Over a web view (a pane's edge dragged in
          // over its page) the drag and its release reached neither.
          flutterViewController.mouseDragged(with: event)
          return nil
        }
      case .rightMouseDown, .otherMouseDown:
        flutterViewController.pressing(event.buttonNumber)
      case .scrollWheel, .magnify, .rotate:
        flutterViewController.gestureEnding(event)
      case .leftMouseDown, .leftMouseUp:
        if event.type == .leftMouseDown {
          flutterViewController.pressing(0)
          self.headerDrag.down(at: event.timestamp, clicks: event.clickCount, at: event.locationInWindow)
        } else {
          // A release after one made up, or of a press that moved the
          // window, is no click.
          let click = !flutterViewController.owes(0) && self.headerDrag.up()
          self.lastUp = click ? (event.clickCount, event.timestamp) : nil
        }
        if event.type == .leftMouseUp, flutterViewController.holdsLeft {
          // The release of Flutter's press is Flutter's, as its drag is:
          // over a web view it's no act in the page.
          flutterViewController.mouseUp(with: event)
          return nil
        }
        if Self.inWebView(self.contentView?.hitTest(event.locationInWindow)) {
          self.browser?.pressed(at: event.timestamp, byKey: false)
        }
      case .keyDown:
        // Only the keys that activate a focused link or button: Return,
        // the keypad's Enter, Space, and only as pressed, not as a held
        // key repeats (Space held to scroll would let out one navigation a
        // repeat). Typing in a page lets nothing open.
        if !event.isARepeat, [36, 76, 49].contains(event.keyCode), Self.inWebView(self.firstResponder as? NSView) {
          self.browser?.pressed(at: event.timestamp, byKey: true)
        }
      default: break
      }
      return event
    }
    guardMouse(flutterViewController)

    super.awakeFromNib()
  }

  /// The window's place across launches and displays (ADR 0093).
  private lazy var placement = WindowPlacement(window: self)

  /// Every zoom is Nushi's, on the window's own screen (ADR 0093): AppKit's
  /// went back to a frame it kept from where it first put the window.
  override func zoom(_ sender: Any?) { placement.zoom() }

  /// The menu's Zoom: the same zoom.
  override func performZoom(_ sender: Any?) { zoom(sender) }

  /// Full screen across launches too, which the saved frame doesn't say
  /// (it keeps the frame from before full screen): a default of its own,
  /// and full screen again once the window is up, on the screen it went
  /// back to.
  private func keepFullScreen() {
    let key = "NushiWindowFullScreen"
    let center = NotificationCenter.default
    center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: self, queue: .main) { _ in
      UserDefaults.standard.set(true, forKey: key)
    }
    center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main) { _ in
      UserDefaults.standard.removeObject(forKey: key)
    }
    if UserDefaults.standard.bool(forKey: key) {
      DispatchQueue.main.async { [weak self] in self?.toggleFullScreen(nil) }
    }
  }

  /// The installed families' names, as the font panel has them, without
  /// the system's private ones (a dot first), which no one picks by name.
  private static func families() -> [String] {
    NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }
  }

  /// The installed monospaced families, once found.
  private static var monospacedFamilies: [String]?

  /// Finds the installed monospaced families, by the fixed-pitch trait of
  /// each family's first member (no font is made), on a background queue the
  /// first time; [done] runs on the main queue.
  private static func monospaced(_ done: @escaping ([String]) -> Void) {
    if let found = monospacedFamilies { return done(found) }
    DispatchQueue.global(qos: .userInitiated).async {
      let fonts = NSFontManager.shared
      let fixed = NSFontTraitMask.fixedPitchFontMask.rawValue
      let found = fonts.availableFontFamilies.filter { family in
        // The family's first member is the face a family name gets (Osaka's
        // is proportional though Osaka-Mono is fixed).
        guard !family.hasPrefix("."), let first = fonts.availableMembers(ofFontFamily: family)?.first,
          first.count > 3 else { return false }
        return ((first[3] as? NSNumber)?.uintValue ?? 0) & fixed != 0
      }
      DispatchQueue.main.async {
        monospacedFamilies = found
        done(found)
      }
    }
  }

  private var swipeMonitor: Any?
  private var pressMonitor: Any?
  /// The window's presses; a header's moves the window (lib/window_drag.dart).
  private var headerDrag = HeaderDrag()

  /// Moves the window with a header's press, from the monitor as it handles
  /// [event], the press's dragged event, before any later one is taken
  /// (the release among them): the window server then has the drag while
  /// the button is held. The engine gets the press's release once the
  /// button is up: the real one, or one NushiViewController makes up.
  private func moveWindow(with event: NSEvent) {
    placement.dragBegan()
    lastUp = nil
    performDrag(with: event)
    (contentViewController as? NushiViewController)?.lookSoon()
  }

  /// Logs each release the engine never had (ADR 0038: which button and
  /// which check found it, nothing more), and has the guard look when the
  /// window or the app changes hands: a release lost then has no event
  /// after it until the pointer next moves over the window.
  private func guardMouse(_ controller: NushiViewController) {
    let window = FlutterMethodChannel(name: "nushi/window", binaryMessenger: controller.engine.binaryMessenger)
    controller.onRepair = { what, check in
      NSLog("Nushi: the engine never had a %@ release or end (%@): told it", what, check)
      window.invokeMethod("repaired", arguments: ["what": what, "check": check])
    }
    controller.lookWhy = { [weak self] in
      guard let self else { return "watch" }
      if self.headerDrag.dragging { return "window drag" }
      if !NSApp.isActive { return "app inactive" }
      return self.isKeyWindow ? "watch" : "window not key"
    }
    let center = NotificationCenter.default
    for name in [
      NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification, NSWindow.didMoveNotification,
      NSWindow.didEndLiveResizeNotification,
    ] {
      center.addObserver(forName: name, object: self, queue: .main) { [weak controller] _ in controller?.lookSoon() }
    }
    for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
      center.addObserver(forName: name, object: nil, queue: .main) { [weak controller] _ in controller?.lookSoon() }
    }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak controller] _ in controller?.lookSoon() }
  }

  /// The last release's click count and timestamp, for the header's
  /// double click.
  private var lastUp: (count: Int, at: TimeInterval)?

  /// A double click in a header's empty space (lib/window_drag.dart), as a
  /// title bar's: what the system's setting says (Desktop & Dock's
  /// double-click a title bar), and only when macOS counted the release as
  /// the second click (its own interval and distance; a third is no
  /// second). Flutter counts two taps by when it handles them, so two
  /// clicks a stall bunched up zoomed the window unasked (ADR 0093). The
  /// channel comes late: the release may be up to half a second old.
  private func titleBarDoubleClick() {
    guard let up = lastUp, up.count == 2,
      ProcessInfo.processInfo.systemUptime - up.at < NSEvent.doubleClickInterval + 0.5 else { return }
    lastUp = nil
    switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
    case "Minimize": miniaturize(nil)
    case "None": break
    default: zoom(nil)
    }
  }

  /// The `nushi/browser` channel, which the press monitor tells of each
  /// press or key that goes to a web view.
  private var browser: Browser?

  /// Whether a view is a web view or inside one. AppKit gives a press to
  /// the view its hit test finds, so this is where WebKit took it.
  private static func inWebView(_ view: NSView?) -> Bool {
    var v = view
    while let view = v {
      if view is WKWebView { return true }
      v = view.superview
    }
    return false
  }
}
