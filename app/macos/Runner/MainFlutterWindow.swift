import Cocoa
import FlutterMacOS
import ServiceManagement
import UserNotifications
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
    restoreFrame()
    keepFullScreen()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The installed monospaced font families, for the terminal's font setting.
    FlutterMethodChannel(name: "nushi/fonts", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        guard call.method == "monospaced" else { return result(FlutterMethodNotImplemented) }
        let fonts = NSFontManager.shared
        result(fonts.availableFontFamilies.filter { family in
          guard !family.hasPrefix("."), let name = fonts.availableMembers(ofFontFamily: family)?.first?[0] as? String
          else { return false }
          return NSFont(name: name, size: 12)?.isFixedPitch ?? false
        })
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
            self.performDrag(with: event)
            self.letGoInFlutter()
          }
          result(nil)
        case "zoom":
          self?.performZoom(nil)
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
        if Self.inWebView(self.contentView?.hitTest(event.locationInWindow)) { self.webPressedAt = event.timestamp }
      case .keyDown:
        // Only the keys that activate a focused link or button: Return,
        // the keypad's Enter, Space. Typing in a page lets nothing open.
        if [36, 76, 49].contains(event.keyCode), Self.inWebView(self.firstResponder as? NSView) {
          self.webPressedAt = event.timestamp
        }
      default:
        if NSEvent.pressedMouseButtons & 1 == 0 { self.letGoInFlutter() }
      }
      return event
    }

    super.awakeFromNib()
  }

  /// Keeps the window's size and place across launches, under the autosave
  /// name "Nushi". AppKit's own restore from that name (seen on macOS 27)
  /// puts the window on the main screen, fitted to it, even when the screen
  /// it was saved on is connected, and saves that over the frame; so the
  /// frame is read first and put back here, on the connected screen most of
  /// it lies on, fitted to that screen. On none, AppKit's placement stands.
  /// macOS's window restoration is off: when "Close windows when quitting"
  /// is off it puts its own copy of the frame back after this one.
  private func restoreFrame() {
    let key = "NSWindow Frame Nushi"
    let saved = UserDefaults.standard.string(forKey: key)?.split(separator: " ").prefix(4).compactMap { Double($0) }
    isRestorable = false
    setFrameAutosaveName("Nushi")
    guard let saved, saved.count == 4 else { return }
    var frame = NSRect(x: saved[0], y: saved[1], width: saved[2], height: saved[3])
    func overlap(_ screen: NSScreen) -> CGFloat {
      let shared = screen.visibleFrame.intersection(frame)
      return shared.isNull ? 0 : shared.width * shared.height
    }
    guard let screen = NSScreen.screens.max(by: { overlap($0) < overlap($1) }), overlap(screen) > 0 else { return }
    let room = screen.visibleFrame
    frame.size = NSSize(width: min(frame.width, room.width), height: min(frame.height, room.height))
    frame.origin = NSPoint(x: min(max(frame.minX, room.minX), room.maxX - frame.width),
                           y: min(max(frame.minY, room.minY), room.maxY - frame.height))
    setFrame(frame, display: false)
  }

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

  private var swipeMonitor: Any?
  private var pressMonitor: Any?
  private var pressed = false
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

/// The Mac's notifications (macOS shows them; nothing leaves the Mac) and
/// the Dock badge. Permission is asked on the first notification, not at
/// launch. A click on one tells the app which chat to open.
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
  static let shared = Alerts()
  var channel: FlutterMethodChannel?

  override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
  }

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "badge":
      let label = call.arguments as? String ?? ""
      NSApp.dockTile.badgeLabel = label.isEmpty ? nil : label
      result(nil)
    case "status":
      center.getNotificationSettings { settings in
        let status: String = switch settings.authorizationStatus {
        case .authorized, .provisional: "authorized"
        case .denied: "denied"
        default: "notDetermined"
        }
        DispatchQueue.main.async { result(status) }
      }
    case "post":
      guard let args = call.arguments as? [String: Any], let id = args["id"] as? String,
        let chat = args["chat"] as? String
      else { return result(FlutterError(code: "refused", message: "No notification", details: nil)) }
      let content = UNMutableNotificationContent()
      content.title = args["title"] as? String ?? "Nushi"
      content.body = args["body"] as? String ?? ""
      content.userInfo = ["chat": chat]
      content.threadIdentifier = chat
      if args["sound"] as? Bool == true { content.sound = .default }
      center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        guard granted else {
          return DispatchQueue.main.async { result(error.map { FlutterError(code: "denied", message: $0.localizedDescription, details: nil) } ?? "denied") }
        }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
          DispatchQueue.main.async {
            result(error.map { FlutterError(code: "failed", message: $0.localizedDescription, details: nil) } ?? "posted")
          }
        }
      }
    case "clear":
      let chat = call.arguments as? String ?? ""
      center.getDeliveredNotifications { delivered in
        let ids = delivered.filter { $0.request.content.userInfo["chat"] as? String == chat }.map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: ids)
        DispatchQueue.main.async { result(nil) }
      }
    case "withdraw":
      center.removeDeliveredNotifications(withIdentifiers: call.arguments as? [String] ?? [])
      result(nil)
    case "openSettings":
      let id = Bundle.main.bundleIdentifier ?? ""
      NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")!)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // In front too: the app decides what to post (another chat than the one
  // showing), so macOS shows it.
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
    done(notification.request.content.sound == nil ? [.banner, .list] : [.banner, .list, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                              withCompletionHandler done: @escaping () -> Void) {
    if let chat = response.notification.request.content.userInfo["chat"] as? String {
      DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        self.channel?.invokeMethod("open", arguments: chat)
      }
    }
    done()
  }
}

/// Draws Mermaid diagrams for the transcript, one at a time, in a web view
/// of their own that's never shown (in a window off screen): the app's
/// mermaid.html with its pinned mermaid.min.js, nothing else loaded (any
/// other navigation is refused). Each is drawn at the width asked, then
/// snapshot as a PNG at the screen's scale. One that takes longer than
/// jobTimeout fails, and its web view goes (its process with it): a fresh
/// one draws the rest, so someone else's slow diagram (GitHub's, Jira's)
/// can't hold every later one.
final class Diagrams: NSObject, WKNavigationDelegate {
  /// The page, among the app's Flutter assets.
  static let page = Bundle.main.privateFrameworksURL!
    .appendingPathComponent("App.framework/Resources/flutter_assets/assets/mermaid/mermaid.html")

  /// How long one diagram may take to draw.
  static let jobTimeout: TimeInterval = 10

  private var web: WKWebView?
  private var window: NSWindow?
  private var loaded = false
  private var queue: [(source: String, args: [String: Any], done: FlutterResult)] = []
  private var busy = false
  private var drawing: FlutterResult? // the answer of the job drawing
  private var current = 0 // the job drawing, counted: a late answer of one let go is dropped

  func draw(source: String, args: [String: Any], done: @escaping FlutterResult) {
    queue.append((source, args, done))
    next()
  }

  private func next() {
    guard !busy, !queue.isEmpty else { return }
    guard let web = web ?? start() else { return }
    guard loaded else { return } // didFinish goes on
    busy = true
    current += 1
    let id = current
    let job = queue.removeFirst()
    drawing = job.done
    DispatchQueue.main.asyncAfter(deadline: .now() + Diagrams.jobTimeout) { [weak self] in
      guard let self, self.current == id, let done = self.drawing else { return }
      self.letGo()
      done(["error": "The diagram took too long to draw"])
      self.next()
    }
    let width = min(max(job.args["width"] as? Double ?? 600, 120), 2400)
    web.setFrameSize(NSSize(width: width, height: 400))
    let opts: [String: Any] = [
      "dark": job.args["dark"] as? Bool ?? false,
      "background": job.args["background"] as? String ?? "",
      "foreground": job.args["foreground"] as? String ?? "",
    ]
    web.callAsyncJavaScript("return await show(source, opts)", arguments: ["source": job.source, "opts": opts],
                            in: nil, in: .page) { [weak self, weak web] answer in
      guard let self, let web, self.current == id else { return }
      switch answer {
      case .failure(let error): self.finish(["error": error.localizedDescription])
      case .success(let value):
        let drawn = value as? [String: Any] ?? [:]
        if let error = drawn["error"] as? String { return self.finish(["error": error]) }
        let w = min(drawn["width"] as? Double ?? 0, width)
        let h = min(drawn["height"] as? Double ?? 0, 8000)
        guard w > 0, h > 0 else { return self.finish(["error": "The diagram came out empty"]) }
        web.setFrameSize(NSSize(width: width, height: h))
        // Laid out at the new height before the snapshot.
        DispatchQueue.main.async {
          let config = WKSnapshotConfiguration()
          config.rect = NSRect(x: 0, y: 0, width: w, height: h)
          web.takeSnapshot(with: config) { image, error in
            guard self.current == id else { return }
            guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
            else { return self.finish(["error": error?.localizedDescription ?? "No snapshot", "retry": true]) }
            self.finish(["png": FlutterStandardTypedData(bytes: png), "width": w, "height": h])
          }
        }
      }
    }
  }

  private func finish(_ answer: [String: Any]) {
    guard let done = drawing else { return }
    drawing = nil
    done(answer)
    busy = false
    next()
  }

  private func start() -> WKWebView? {
    guard FileManager.default.fileExists(atPath: Diagrams.page.path) else {
      for job in queue { job.done(["error": "This build has no Mermaid (make mermaid)"]) }
      queue = []
      return nil
    }
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), configuration: WKWebViewConfiguration())
    let window = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 600, height: 400),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = web
    web.navigationDelegate = self
    web.loadFileURL(Diagrams.page, allowingReadAccessTo: Diagrams.page.deletingLastPathComponent())
    self.web = web
    self.window = window
    return web
  }

  func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    decisionHandler(!loaded && action.request.url?.standardizedFileURL == Diagrams.page.standardizedFileURL ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    loaded = true
    next()
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    fail(error)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    fail(error)
  }

  // WebKit's process for the page went away: start afresh on the next one.
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    fail(nil)
  }

  /// Drops the web view, and its process with it (a diagram still
  /// drawing there stops), and any answer still to come from it.
  private func letGo() {
    current += 1
    drawing = nil
    web?.navigationDelegate = nil
    window?.contentView = nil
    web = nil
    window = nil
    loaded = false
    busy = false
  }

  private func fail(_ error: Error?) {
    let pending = (drawing.map { [$0] } ?? []) + queue.map(\.done)
    queue = []
    letGo()
    // Not the diagrams' fault: the app asks for them again (retry).
    for done in pending { done(["error": error?.localizedDescription ?? "The diagram's web view stopped", "retry": true]) }
  }
}
