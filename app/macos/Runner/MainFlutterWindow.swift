import Cocoa
import FlutterMacOS
import ServiceManagement
import WebKit
import webview_flutter_wkwebview

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

    // Opens an address in the default browser (a preview's Open in browser and
    // its links): the app that opens https, for a file too, so a file a page
    // links is never run by the app its type has, and that app's name. How long ago the user last
    // pressed or typed in a web view (lib/web_views_macos.dart): Flutter never sees
    // those, WebKit takes them. A file preview's web view made cookieless
    // (PreviewCookies). A browser tab's loads as they commit (CommitWatch), and
    // its block on the local network (LocalNetwork). Its ⋯ menu's screenshot
    // and Clear browsing data (BrowserData).
    let browserChannel = FlutterMethodChannel(
      name: "nushi/browser", binaryMessenger: flutterViewController.engine.binaryMessenger)
    browserChannel
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
        if call.method == "watchCommits" {
          // The channel is held here, for the app's life: it tells of commits.
          guard let id = (call.arguments as? NSNumber)?.int64Value, let registry = flutterViewController else {
            return result(FlutterError(code: "refused", message: "No web view", details: nil))
          }
          return CommitWatch.watch(id, registry: registry, channel: browserChannel, result)
        }
        if call.method == "blockLocal" {
          guard let args = call.arguments as? [String: Any], let id = (args["id"] as? NSNumber)?.int64Value,
            let rules = args["rules"] as? String, let registry = flutterViewController
          else { return result(FlutterError(code: "refused", message: "No web view", details: nil)) }
          return LocalNetwork.block(id, rules: rules, registry: registry, result)
        }
        if call.method == "navigation" || call.method == "historyItem" {
          guard let args = call.arguments as? [String: Any], let id = (args["id"] as? NSNumber)?.int64Value,
            let registry = flutterViewController
          else { return result(FlutterError(code: "refused", message: "No web view", details: nil)) }
          if call.method == "navigation" {
            return result(CommitWatch.navigation(id, url: args["url"] as? String ?? "", registry: registry))
          }
          return result(CommitWatch.historyItem(id, by: (args["by"] as? NSNumber)?.intValue ?? 0, registry: registry))
        }
        if call.method == "snapshot" {
          guard let id = (call.arguments as? NSNumber)?.int64Value, let registry = flutterViewController else {
            return result(FlutterError(code: "refused", message: "No web view", details: nil))
          }
          return BrowserData.snapshot(id, registry: registry, result)
        }
        if call.method == "clearData" { return BrowserData.clear(result) }
        if call.method == "find" || call.method == "pageFocused" || call.method == "focusPage" {
          // A page's find (lib/web_find_macos.dart): its script, whether its web
          // view has the keys, and the keys given back to it.
          let id = ((call.arguments as? [String: Any])?["id"] as? NSNumber ?? call.arguments as? NSNumber)?.int64Value
          guard let id, let registry = flutterViewController,
            let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry)
          else { return result(FlutterError(code: "refused", message: "No web view", details: nil)) }
          switch call.method {
          case "find": return PageFind.run(web, args: call.arguments as? [String: Any] ?? [:], result)
          case "pageFocused": return result(PageFind.focused(web))
          default:
            web.window?.makeFirstResponder(web)
            return result(nil)
          }
        }
        if call.method == "browserName" {
          // The name of the app "open" opens with, for a browser tab's Open
          // in button: as Finder shows it, less ".app".
          guard let app = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else {
            return result(nil)
          }
          let name = FileManager.default.displayName(atPath: app.path)
          return result(name.hasSuffix(".app") ? String(name.dropLast(4)) : name)
        }
        guard call.method == "open" else { return result(FlutterMethodNotImplemented) }
        // Only http, https and file, whatever the Dart side passes: every
        // link and page leaving the app comes here (web_views.dart).
        guard let text = call.arguments as? String, let url = URL(string: text),
          ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "")
        else { return result(FlutterError(code: "refused", message: "Not an address to open", details: nil)) }
        guard let browser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else {
          return result(FlutterError(code: "no-browser", message: "No app opens https", details: nil))
        }
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
}

/// A file's preview sends and keeps no cookies (docs/security.md): WebKit
/// takes a `file:` page's frames and requests as first party, so in the one
/// store browser tabs share with previews they'd carry the tabs' logins. A
/// content rule list strips cookies both ways, for that web view only.
enum PreviewCookies {
  private static var list: WKContentRuleList?
  private static let rules = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block-cookies"}}]"#

  /// Adds the rule list to the plugin's web view [id] (`webViewIdentifier`,
  /// lib/web_page_macos.dart), then answers: nil once it holds, an error when it
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

/// A browser tab's block on this Mac and the local network (docs/security.md):
/// a content rule list, made by lib/browser_local.dart, that blocks every load
/// of a local address unless the page on top is local, or a site let through.
/// One list at a time per web view: a new one (the sites changed) takes the
/// old one's place once it's compiled, so there's never a moment without.
/// Only the rules asked for last are put on: older ones that finish
/// compiling after them (the sites changed twice quickly) are dropped, so a
/// site taken off stays off.
enum LocalNetwork {
  private static var compiled: (rules: String, list: WKContentRuleList)?
  private static var key: UInt8 = 0
  private static var wantKey: UInt8 = 0

  /// Puts [rules] on the plugin's web view [id], then answers: nil once it
  /// holds, an error when it can't, and the tab then loads nothing.
  static func block(_ id: Int64, rules: String, registry: FlutterPluginRegistry, _ result: @escaping FlutterResult) {
    guard let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry) else {
      return result(FlutterError(code: "refused", message: "No such web view", details: nil))
    }
    objc_setAssociatedObject(web, &wantKey, rules, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    func install(_ list: WKContentRuleList) {
      let content = web.configuration.userContentController
      let old = objc_getAssociatedObject(web, &key) as? WKContentRuleList
      // Rules asked for since answer for themselves; these go on only while
      // the web view has none, so it's never without one.
      if objc_getAssociatedObject(web, &wantKey) as? String != rules, old != nil { return result(nil) }
      if old !== list {
        content.add(list)
        if let old { content.remove(old) }
        objc_setAssociatedObject(web, &key, list, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
      result(nil)
    }
    if let compiled, compiled.rules == rules { return install(compiled.list) }
    WKContentRuleListStore.default().compileContentRuleList(
      forIdentifier: "nushi.browser-local-network", encodedContentRuleList: rules
    ) { list, error in
      DispatchQueue.main.async {
        guard let list else {
          return result(FlutterError(code: "failed", message: error?.localizedDescription ?? "No rule list", details: nil))
        }
        compiled = (rules, list)
        install(list)
      }
    }
  }
}

/// What a browser tab's ⋯ menu asks of WebKit (lib/browser_menu.dart): the
/// page in sight as a PNG, and every site's data gone from WebKit's default
/// store, the one browser tabs and file previews share (docs/security.md).
enum BrowserData {
  /// The plugin's web view [id] as it's on screen, the part in sight only,
  /// as PNG data, or an error.
  static func snapshot(_ id: Int64, registry: FlutterPluginRegistry, _ result: @escaping FlutterResult) {
    guard let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry) else {
      return result(FlutterError(code: "refused", message: "No such web view", details: nil))
    }
    web.takeSnapshot(with: nil) { image, error in
      guard let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
      else {
        return result(FlutterError(code: "failed", message: error?.localizedDescription ?? "No picture", details: nil))
      }
      result(FlutterStandardTypedData(bytes: png))
    }
  }

  /// Removes every kind of website data (cookies, local storage, IndexedDB,
  /// caches, service workers) of every site from the default store, then
  /// answers nil.
  static func clear(_ result: @escaping FlutterResult) {
    WKWebsiteDataStore.default().removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
    ) { result(nil) }
  }
}

/// A browser tab's loads as they commit (lib/browser_address.dart's
/// PageAddress): the plugin passes on WebKit's URL, which is a navigation's
/// from its start, before anything of it loads, and no commit. This stands in
/// front of the plugin's navigation delegate, passes it everything, and tells
/// the app ("committed") where each main-frame load committed. It also keeps
/// what the plugin doesn't pass on of each main frame's navigation it
/// decides, its kind and whether it's a redirect, for the app to ask
/// ("navigation") as it decides: its block on the local network
/// (lib/browser_navigation.dart's NavigationSource) needs both.
final class CommitWatch: NSObject, WKNavigationDelegate {
  private static var key: UInt8 = 0
  // WebKit says a navigation is a server's redirect only privately (seen in a
  // probe app, 2026-11-06). Without it the app is told nothing of it, and
  // judges the navigation by the stricter of the page on screen and the load
  // it may redirect.
  private static let isRedirect = NSSelectorFromString("_isRedirect")
  // Strong: a web view holds its delegate weakly. WebKit reads which of a
  // delegate's methods it has as it's set, and this one has the plugin's.
  private let inner: WKNavigationDelegate
  private let committed: (URL?) -> Void
  // The main frame's navigations waiting on the app, oldest first.
  private var deciding: [(url: String, type: Int, redirect: Bool?)] = []

  private init(inner: WKNavigationDelegate, committed: @escaping (URL?) -> Void) {
    self.inner = inner
    self.committed = committed
  }

  /// Puts a watch in front of the plugin's web view [id]'s navigation
  /// delegate (set by then), then answers: nil once it holds, an error when
  /// it can't, and the tab then loads nothing.
  static func watch(
    _ id: Int64, registry: FlutterPluginRegistry, channel: FlutterMethodChannel, _ result: @escaping FlutterResult
  ) {
    guard let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry),
      let inner = web.navigationDelegate
    else { return result(FlutterError(code: "refused", message: "No such web view", details: nil)) }
    if inner is CommitWatch { return result(nil) }
    let watch = CommitWatch(inner: inner) { [weak channel] url in
      channel?.invokeMethod("committed", arguments: ["id": NSNumber(value: id), "url": url?.absoluteString ?? ""])
    }
    // It lives as long as its web view.
    objc_setAssociatedObject(web, &key, watch, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    web.navigationDelegate = watch
    result(nil)
  }

  /// What WebKit said of the main frame's navigation to [url] in web view
  /// [id], taken: its `WKNavigationType`'s raw value and whether it's a
  /// redirect, or nil when nothing waits for it. Those before it go too.
  static func navigation(_ id: Int64, url: String, registry: FlutterPluginRegistry) -> [String: Any]? {
    guard let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry),
      let watch = objc_getAssociatedObject(web, &key) as? CommitWatch,
      let at = watch.deciding.firstIndex(where: { $0.url == url })
    else { return nil }
    let told = watch.deciding[at]
    watch.deciding.removeSubrange(...at)
    var said: [String: Any] = ["type": told.type]
    if let redirect = told.redirect { said["redirect"] = redirect }
    return said
  }

  /// The address of the history item [by] steps from web view [id]'s page
  /// (0 is the page's own, which a reload loads), or nil when there's none.
  static func historyItem(_ id: Int64, by: Int, registry: FlutterPluginRegistry) -> String? {
    FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry)?
      .backForwardList.item(at: by)?.url.absoluteString
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    // The plugin's decision asks the app, which asks here: kept first.
    if action.targetFrame?.isMainFrame == true, let url = action.request.url?.absoluteString {
      let redirect = action.responds(to: Self.isRedirect) ? action.value(forKey: "_isRedirect") as? Bool : nil
      deciding.append((url, action.navigationType.rawValue, redirect))
      if deciding.count > 16 { deciding.removeFirst() }
    }
    // The plugin has it; were it ever not to, nothing loads.
    if inner.webView?(webView, decidePolicyFor: action, decisionHandler: decisionHandler) == nil {
      decisionHandler(.cancel)
    }
  }

  override func responds(to aSelector: Selector!) -> Bool {
    super.responds(to: aSelector) || inner.responds(to: aSelector)
  }

  override func forwardingTarget(for aSelector: Selector!) -> Any? {
    inner.responds(to: aSelector) ? inner : nil
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    inner.webView?(webView, didCommit: navigation)
    committed(webView.url)
  }
}

/// A page's find (lib/web_find.dart, ADR 0143): a script run in a content world
/// of Nushi's own, so the page's scripts can't see its variables or change the
/// functions it calls, marking the matches with the CSS Custom Highlight API,
/// which leaves the page's DOM, text and selection as they were (WebKit's own
/// find sets the selection, which the page sees). The page can read the
/// highlights' ranges while they're shown; they're emptied as they go. Its colours come as
/// arguments, checked to be rgba() before they go in the style sheet.
enum PageFind {
  /// The body of an async function of `op` ("find", "show" or "clear"),
  /// `query`, `at`, `hit`, `now`, `edge` and `cover` (the bar's height):
  /// the matches' count and the current one's number.
  static let script = #"""
    const S = (window.__nushiFind ??= { ranges: [], sheet: null, style: null });
    const reg = (window.CSS && CSS.highlights && window.Highlight) ? CSS.highlights : null;
    const color = (c) => (typeof c === 'string' && /^rgba\([0-9., ]+\)$/.test(c)) ? c : 'transparent';
    const top = typeof cover === 'number' ? cover : 0;
    function clear() {
      // Emptied first: once the page has read the registry WebKit keeps its
      // own view of it, which a delete from this world doesn't reach.
      for (const r of S.ranges) r.collapse(true);
      if (reg) { reg.delete('nushi-find'); reg.delete('nushi-find-now'); }
      if (S.sheet) {
        document.adoptedStyleSheets = document.adoptedStyleSheets.filter((s) => s !== S.sheet);
        S.sheet = null;
      }
      if (S.style) { S.style.remove(); S.style = null; }
      S.ranges = [];
    }
    function show(i) {
      const r = S.ranges[i];
      if (!r) return;
      // The current one in its own colour only, as the transcript draws it.
      if (reg) {
        reg.set('nushi-find', new Highlight(...S.ranges.filter((_, k) => k !== i)));
        reg.set('nushi-find-now', new Highlight(r));
      }
      const el = r.startContainer.parentElement;
      let box = r.getBoundingClientRect();
      const out = () => box.top < top || box.bottom > innerHeight || box.left < 0 || box.right > innerWidth;
      if (!out()) return;
      // Its own scrolling boxes first, then the page, the match a third down.
      if (el) el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      box = r.getBoundingClientRect();
      if (!out()) return;
      const dx = box.left < 0 || box.right > innerWidth ? box.left - innerWidth / 3 : 0;
      window.scrollBy(dx, box.top - Math.max(top, innerHeight * 0.3));
    }
    if (op === 'clear') { clear(); return { count: 0, at: 0 }; }
    if (op === 'show') { show(at); return { count: S.ranges.length, at }; }
    clear();
    if (typeof query !== 'string' || query === '') return { count: 0, at: 0 };
    const root = document.body || document.documentElement;
    if (!root) return { count: 0, at: 0 };
    const skip = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'TEXTAREA', 'SELECT', 'OPTION', 'TITLE']);
    const blocks = new Map();
    function blockOf(el) {
      let e = el;
      while (e && e !== root) {
        let inline = blocks.get(e);
        if (inline === undefined) {
          inline = getComputedStyle(e).display.startsWith('inline');
          blocks.set(e, inline);
        }
        if (!inline) return e;
        e = e.parentElement;
      }
      return root;
    }
    const nodes = [], starts = [];
    let text = '', last = null;
    const walk = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    for (let n = walk.nextNode(); n; n = walk.nextNode()) {
      const p = n.parentElement;
      if (!n.data || !p || skip.has(p.tagName) || p.closest('[hidden]')) continue;
      if (p.getClientRects().length === 0 || getComputedStyle(p).visibility !== 'visible') continue;
      const block = blockOf(p);
      // Text in two blocks never runs together into one match.
      if (block !== last && text) text += '\n';
      last = block;
      nodes.push(n);
      starts.push(text.length);
      text += n.data;
    }
    function locate(pos, end) {
      let lo = 0, hi = starts.length - 1;
      while (lo < hi) {
        const mid = (lo + hi + 1) >> 1;
        if (end ? starts[mid] < pos : starts[mid] <= pos) lo = mid; else hi = mid - 1;
      }
      return [nodes[lo], Math.min(pos - starts[lo], nodes[lo].data.length)];
    }
    const re = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'giu');
    for (const m of text.matchAll(re)) {
      if (S.ranges.length >= 10000) break;
      const r = document.createRange();
      const [a, ao] = locate(m.index, false);
      const [b, bo] = locate(m.index + m[0].length, true);
      r.setStart(a, ao);
      r.setEnd(b, bo);
      S.ranges.push(r);
    }
    if (reg && S.ranges.length) {
      const css = `::highlight(nushi-find) { background-color: ${color(hit)}; }
        ::highlight(nushi-find-now) { background-color: ${color(now)}; text-decoration: underline 2px ${color(edge)}; }`;
      try {
        S.sheet = new CSSStyleSheet();
        S.sheet.replaceSync(css);
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, S.sheet];
      } catch (e) {
        S.sheet = null;
        S.style = document.createElement('style');
        S.style.textContent = css;
        (document.head || document.documentElement).appendChild(S.style);
      }
    }
    const i = Math.min(Math.max(at, 0), Math.max(S.ranges.length - 1, 0));
    show(i);
    return { count: S.ranges.length, at: i };
    """#

  /// Runs the script with the channel's arguments (less the web view's id),
  /// then answers its count and current match, or an error.
  static func run(_ web: WKWebView, args: [String: Any], _ result: @escaping FlutterResult) {
    var given = args
    given.removeValue(forKey: "id")
    web.callAsyncJavaScript(script, arguments: given, in: nil, in: .defaultClient) { answer in
      switch answer {
      case .success(let value): result(value as? [String: Any] ?? ["count": 0, "at": 0])
      case .failure(let error):
        result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// Whether the web view, or a view inside it, has the keys.
  static func focused(_ web: WKWebView) -> Bool {
    guard let view = web.window?.firstResponder as? NSView else { return false }
    return view === web || view.isDescendant(of: web)
  }
}
