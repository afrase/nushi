import Cocoa
import FlutterMacOS
import ServiceManagement
import WebKit
import webview_flutter_wkwebview

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
    // And AppKit's title bar keeps off the content under it: the headers
    // are the title bar (lib/window_drag.dart).
    TitleBarCover.cover(flutterViewController.view)
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

    // Opens an address in the default browser (a preview's Open in browser and
    // its links): the app that opens https, for a file too, so a file a page
    // links is never run by the app its type has. How long ago the user last
    // pressed or typed in a web view (lib/web_page.dart): Flutter never sees
    // those, WebKit takes them. And a file preview's web view made cookieless
    // (PreviewCookies).
    FlutterMethodChannel(name: "nushi/browser", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { [weak self, weak flutterViewController] call, result in
        if call.method == "sincePress" {
          // A press lets one navigation leave the page, never a second:
          // asking takes it. A browser tab asks for a pointer's only
          // ("pointer"): people type into a page's forms, and a
          // Space or Return there would let the page's script out.
          let at = self?.webPressedAt
          let byKey = self?.webPressByKey ?? false
          self?.webPressedAt = nil
          if byKey, call.arguments as? String == "pointer" { return result(nil) }
          return result(at.map { ProcessInfo.processInfo.systemUptime - $0 })
        }
        if call.method == "noCookies" {
          guard let id = (call.arguments as? NSNumber)?.int64Value, let registry = flutterViewController else {
            return result(FlutterError(code: "refused", message: "No web view", details: nil))
          }
          return PreviewCookies.block(id, registry: registry, result)
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

    // A header's press moves the window here, as its dragged event comes
    // (HeaderDrag, ADR 0080). A press whose release Flutter never gets
    // leaves it dragging: what moves the window takes the release, and a
    // web view's own tracking can. The pointer then moves with no button
    // held, or the next press comes, which is the sign. It also notes when
    // a press, its release or a key goes to a web view, which is a user's
    // own act in a page (a preview's link opens in the browser only right
    // after one).
    pressMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .mouseMoved, .keyDown]
    ) { [weak self] event in
      guard let self, event.window === self else { return event }
      switch event.type {
      case .leftMouseDragged:
        if self.headerDrag.dragged(to: event.locationInWindow, held: NSEvent.pressedMouseButtons & 1 != 0) == .moveWindow {
          self.moveWindow(with: event)
        }
      case .leftMouseDown, .leftMouseUp:
        if event.type == .leftMouseDown {
          if self.headerDrag.down(at: event.timestamp, clicks: event.clickCount, at: event.locationInWindow) == .releaseFirst {
            self.releaseInFlutter()
          }
        } else {
          switch self.headerDrag.up() {
          case .drop: return nil
          case .dragReleased: self.lastUp = nil // a drag's: no click
          default: self.lastUp = (event.clickCount, event.timestamp)
          }
        }
        if Self.inWebView(self.contentView?.hitTest(event.locationInWindow)) {
          self.webPressedAt = event.timestamp
          self.webPressByKey = false
        }
      case .keyDown:
        // Only the keys that activate a focused link or button: Return,
        // the keypad's Enter, Space, and only as pressed, not as a held
        // key repeats (Space held to scroll would let out one navigation a
        // repeat). Typing in a page lets nothing open.
        if !event.isARepeat, [36, 76, 49].contains(event.keyCode), Self.inWebView(self.firstResponder as? NSView) {
          self.webPressedAt = event.timestamp
          self.webPressByKey = true
        }
      default:
        self.letGoInFlutter()
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
  /// The window's presses; a header's moves the window (lib/window_drag.dart).
  private var headerDrag = HeaderDrag()
  /// Looks at the button while the window server drags the window, which
  /// may send no event when it's let go.
  private var releaseWatch: Timer?

  /// Moves the window with a header's press, from the monitor as it handles
  /// [event], the press's dragged event, before any later one is taken
  /// (the release among them): the window server then has the drag while
  /// the button is held. Flutter gets the press's release once the button
  /// is up: the real one, or one from the window if none came.
  private func moveWindow(with event: NSEvent) {
    placement.dragBegan()
    lastUp = nil
    performDrag(with: event)
    releaseWatch?.invalidate()
    let watch = Timer(timeInterval: 0.02, repeats: true) { [weak self] timer in
      guard let self, self.headerDrag.dragging else { return timer.invalidate() }
      self.letGoInFlutter()
    }
    RunLoop.main.add(watch, forMode: .common)
    releaseWatch = watch
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
  /// When a press, its release or a key last went to a web view (an
  /// event's timestamp: seconds since the system started).
  private var webPressedAt: TimeInterval?

  /// Whether that was a key (Return, Enter, Space), not the pointer.
  private var webPressByKey = false

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

  /// Tells Flutter of a release it missed, if the button is up and it did.
  private func letGoInFlutter() {
    if headerDrag.letGo(held: NSEvent.pressedMouseButtons & 1 != 0) { releaseInFlutter() }
  }

  /// Tells Flutter its press was let go, here and now.
  private func releaseInFlutter() {
    let up = NSEvent.mouseEvent(
      with: .leftMouseUp, location: mouseLocationOutsideOfEventStream, modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 0)
    if let up { contentViewController?.mouseUp(with: up) }
  }
}

/// A file's preview sends and keeps no cookies (docs/security.md): WebKit
/// takes a `file:` page's frames and requests as first party, so in the one
/// store browser tabs share with previews they'd carry the tabs' logins. A
/// content rule list strips cookies both ways, for that web view only.
enum PreviewCookies {
  private static var list: WKContentRuleList?
  private static let rules = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block-cookies"}}]"#

  /// Adds the rule list to the plugin's web view [id] (`webViewIdentifier`,
  /// lib/web_page.dart), then answers: nil once it holds, an error when it
  /// can't, and the preview then loads nothing.
  static func block(_ id: Int64, registry: FlutterPluginRegistry, _ result: @escaping FlutterResult) {
    guard let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry) else {
      return result(FlutterError(code: "refused", message: "No such web view", details: nil))
    }
    if let list {
      web.configuration.userContentController.add(list)
      return result(nil)
    }
    WKContentRuleListStore.default().compileContentRuleList(
      forIdentifier: "nushi.preview-no-cookies", encodedContentRuleList: rules
    ) { compiled, error in
      DispatchQueue.main.async {
        guard let compiled else {
          return result(FlutterError(code: "failed", message: error?.localizedDescription ?? "No rule list", details: nil))
        }
        list = compiled
        web.configuration.userContentController.add(compiled)
        result(nil)
      }
    }
  }
}
