import Cocoa
import FlutterMacOS
import ServiceManagement
import WebKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // No title bar: the content runs to the top, under the traffic lights.
    // Before the saved frame goes back: this keeps the content's size, so
    // after it the window would lose the title bar's height each launch.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    placement.restore()
    keepFullScreen()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The installed monospaced font families, for the terminal's font setting.
    // Worked out once, off the main thread: making an NSFont of every family
    // to ask it took about a second on a Mac with many fonts, and the window
    // froze for it each time Settings › Terminal opened.
    FlutterMethodChannel(name: "nushi/fonts", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        guard call.method == "monospaced" else { return result(FlutterMethodNotImplemented) }
        Self.monospaced { families in result(families) }
      }

    // What a title bar did (lib/window_drag.dart).
    FlutterMethodChannel(name: "nushi/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "drag":
          // The channel is late: only a press still held moves the window,
          // or it would follow a pointer already let go.
          if let self, let event = self.currentEvent, event.type == .leftMouseDragged || event.type == .leftMouseDown,
            NSEvent.pressedMouseButtons & 1 != 0 {
            self.placement.dragBegan()
            self.performDrag(with: event)
            self.letGoInFlutter()
          }
          result(nil)
        case "zoom":
          self?.titleBarDoubleClick()
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }

    // Opens an address in the default browser (a preview's Open in browser and
    // its links): the app that opens https, for a file too, so a file a page
    // links is never run by the app its type has. And how long ago the user
    // last pressed or typed in a web view (lib/web_page.dart): Flutter never
    // sees those, WebKit takes them.
    FlutterMethodChannel(name: "nushi/browser", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        if call.method == "sincePress" {
          // A press lets one navigation leave the page, never a second:
          // asking takes it.
          let at = self?.webPressedAt
          self?.webPressedAt = nil
          return result(at.map { ProcessInfo.processInfo.systemUptime - $0 })
        }
        guard call.method == "open" else { return result(FlutterMethodNotImplemented) }
        guard let text = call.arguments as? String, let url = URL(string: text),
          ["http", "https", "file"].contains(url.scheme?.lowercased() ?? ""),
          let browser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
        else { return result(FlutterError(code: "refused", message: "Not an address to open", details: nil)) }
        NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: NSWorkspace.OpenConfiguration()) { _, error in
          DispatchQueue.main.async {
            result(error.map { FlutterError(code: "failed", message: $0.localizedDescription, details: nil) })
          }
        }
      }

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

    // A press whose release Flutter never gets leaves it dragging: what
    // moves the window takes the release, and a web view's own tracking can.
    // The pointer then moves with no button held, which is the sign.
    // It also notes when a press, its release or a key goes to a web view,
    // which is a user's own act in a page (a preview's link opens in the
    // browser only right after one).
    pressMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .mouseMoved, .keyDown]) { [weak self] event in
      guard let self, event.window === self else { return event }
      switch event.type {
      case .leftMouseDown, .leftMouseUp:
        self.pressed = event.type == .leftMouseDown
        if event.type == .leftMouseUp { self.lastUp = (event.clickCount, event.timestamp) }
        if Self.inWebView(self.contentView?.hitTest(event.locationInWindow)) { self.webPressedAt = event.timestamp }
      case .keyDown:
        // Only the keys that activate a focused link or button: Return,
        // the keypad's Enter, Space, and only as pressed, not as a held
        // key repeats (Space held to scroll would let out one navigation a
        // repeat). Typing in a page lets nothing open.
        if !event.isARepeat, [36, 76, 49].contains(event.keyCode), Self.inWebView(self.firstResponder as? NSView) {
          self.webPressedAt = event.timestamp
        }
      default:
        if NSEvent.pressedMouseButtons & 1 == 0 { self.letGoInFlutter() }
      }
      return event
    }

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
  private var pressed = false
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
  /// When a press, its release or a key last went to a web view (an
  /// event's timestamp: seconds since the system started).
  private var webPressedAt: TimeInterval?

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

  /// Tells Flutter of a release it missed, if it did.
  private func letGoInFlutter() {
    guard pressed else { return }
    pressed = false
    let up = NSEvent.mouseEvent(
      with: .leftMouseUp, location: mouseLocationOutsideOfEventStream, modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 0)
    if let up { contentViewController?.mouseUp(with: up) }
  }
}
