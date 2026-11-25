import Cocoa
import FlutterMacOS
import WebKit
import webview_flutter_wkwebview

/// The `nushi/browser` channel (lib/web_views_macos.dart and the browser's
/// pages): opens an address in the default browser (a preview's Open in
/// browser and its links), the app that opens https, for a file too, so a
/// file a page links is never run by the app its type has, and that app's
/// name. How long ago the user last pressed or typed in a web view: Flutter
/// never sees those, WebKit takes them (the window's press monitor tells
/// this). A file preview's web view made cookieless (PreviewCookies). A
/// browser tab's loads as they commit (CommitWatch), and its block on the
/// local network (LocalNetwork). Its ⋯ menu's screenshot and Clear browsing
/// data (BrowserData). A page's find (PageFind).
final class Browser {
  private weak var registry: FlutterViewController?
  private let channel: FlutterMethodChannel

  /// When a press, its release or a key last went to a web view (an event's
  /// timestamp: seconds since the system started).
  private var pressedAt: TimeInterval?

  /// Whether that was a key (Return, Enter, Space), not the pointer.
  private var pressByKey = false

  /// What every call on a web view answers when it has none: no id, or no
  /// web view of the plugin's by it.
  static let refused = FlutterError(code: "refused", message: "No web view", details: nil)

  init(_ controller: FlutterViewController) {
    registry = controller
    channel = FlutterMethodChannel(name: "nushi/browser", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      self.handle(call, result)
    }
  }

  /// A press, its release or a key ([byKey]) went to a web view at [at].
  func pressed(at: TimeInterval, byKey: Bool) {
    pressedAt = at
    pressByKey = byKey
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "sincePress":
      // A press lets one navigation leave the page, never a second: asking
      // takes it. A browser tab asks for a pointer's only ("pointer"):
      // people type into a page's forms, and a Space or Return there would
      // let the page's script out.
      let at = pressedAt
      pressedAt = nil
      if pressByKey, call.arguments as? String == "pointer" { return result(nil) }
      result(at.map { ProcessInfo.processInfo.systemUptime - $0 })
    case "clearData": BrowserData.clear(result)
    case "browserName":
      // The name of the app "open" opens with, for a browser tab's Open in
      // button: as Finder shows it, less ".app".
      guard let app = Self.browserApp() else { return result(nil) }
      let name = FileManager.default.displayName(atPath: app.path)
      result(name.hasSuffix(".app") ? String(name.dropLast(4)) : name)
    case "open": Self.open(call.arguments, result)
    case "navigation", "historyItem":
      // A web view gone answers nothing, as a navigation nothing waits for.
      guard Self.id(call.arguments) != nil, registry != nil else { return result(Self.refused) }
      let web = webView(call.arguments)
      if call.method == "navigation" {
        return result(web.flatMap { CommitWatch.navigation($0, url: args["url"] as? String ?? "") })
      }
      result(web.flatMap { CommitWatch.historyItem($0, by: (args["by"] as? NSNumber)?.intValue ?? 0) })
    case "noCookies", "watchCommits", "blockLocal", "snapshot", "find", "pageFocused", "focusPage":
      guard let web = webView(call.arguments) else { return result(Self.refused) }
      switch call.method {
      case "noCookies": PreviewCookies.block(web, result)
      case "watchCommits":
        // The channel is held here, for the app's life: it tells of commits.
        CommitWatch.watch(web, id: Self.id(call.arguments)!, channel: channel, result)
      case "blockLocal":
        guard let rules = args["rules"] as? String else { return result(Self.refused) }
        LocalNetwork.block(web, rules: rules, result)
      case "snapshot": BrowserData.snapshot(web, result)
      case "find":
        // A page's find (lib/web_find_macos.dart): its script, whether its web
        // view has the keys, and the keys given back to it.
        guard let script = PageFind.bundled else {
          return result(FlutterError(code: "failed", message: "No find script", details: nil))
        }
        PageFind.run(web, script: script, args: args) { answer in
          switch answer {
          case .success(let value): result(value)
          case .failure(let error): result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          }
        }
      case "pageFocused": result(PageFind.focused(web))
      default:
        web.window?.makeFirstResponder(web)
        result(nil)
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  /// The web view's id in a call's arguments: the id itself, or a map's
  /// "id" (`webViewIdentifier`, lib/web_page_macos.dart).
  private static func id(_ arguments: Any?) -> Int64? {
    ((arguments as? [String: Any])?["id"] as? NSNumber ?? arguments as? NSNumber)?.int64Value
  }

  /// The plugin's web view a call names, if it's still there.
  private func webView(_ arguments: Any?) -> WKWebView? {
    guard let id = Self.id(arguments), let registry else { return nil }
    return FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id, withPluginRegistry: registry)
  }

  /// The app that opens https: the default browser.
  private static func browserApp() -> URL? {
    NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
  }

  /// Opens an address in the default browser. Only http, https and file,
  /// whatever the Dart side passes: every link and page leaving the app
  /// comes here (web_views.dart).
  private static func open(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let text = arguments as? String, let url = URL(string: text),
      ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "")
    else { return result(FlutterError(code: "refused", message: "Not an address to open", details: nil)) }
    guard let browser = browserApp() else {
      return result(FlutterError(code: "no-browser", message: "No app opens https", details: nil))
    }
    NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: NSWorkspace.OpenConfiguration()) { _, error in
      DispatchQueue.main.async {
        result(error.map { FlutterError(code: "failed", message: $0.localizedDescription, details: nil) })
      }
    }
  }
}

/// Content rule lists as WebKit compiles them, the last compiled of each
/// name kept: one asked for again with the same rules goes on at once.
enum RuleLists {
  private static var compiled: [String: (rules: String, list: WKContentRuleList)] = [:]

  /// Hands [then] the list of [rules] named [name], compiled now or kept
  /// from before; when it can't be compiled, answers [result] the error.
  static func compile(
    _ name: String, rules: String, _ result: @escaping FlutterResult, then: @escaping (WKContentRuleList) -> Void
  ) {
    if let kept = compiled[name], kept.rules == rules { return then(kept.list) }
    WKContentRuleListStore.default().compileContentRuleList(forIdentifier: name, encodedContentRuleList: rules) {
      list, error in
      DispatchQueue.main.async {
        guard let list else {
          return result(FlutterError(code: "failed", message: error?.localizedDescription ?? "No rule list", details: nil))
        }
        compiled[name] = (rules, list)
        then(list)
      }
    }
  }
}

/// A file's preview sends and keeps no cookies (docs/security.md): WebKit
/// takes a `file:` page's frames and requests as first party, so in the one
/// store browser tabs share with previews they'd carry the tabs' logins. A
/// content rule list strips cookies both ways, for that web view only.
enum PreviewCookies {
  private static let rules = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block-cookies"}}]"#

  /// Adds the rule list to the plugin's web view, then answers: nil once it
  /// holds, an error when it can't, and the preview then loads nothing.
  static func block(_ web: WKWebView, _ result: @escaping FlutterResult) {
    RuleLists.compile("nushi.preview-no-cookies", rules: rules, result) { list in
      web.configuration.userContentController.add(list)
      result(nil)
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
  private static var key: UInt8 = 0
  private static var wantKey: UInt8 = 0

  /// Puts [rules] on the plugin's web view, then answers: nil once it
  /// holds, an error when it can't, and the tab then loads nothing.
  static func block(_ web: WKWebView, rules: String, _ result: @escaping FlutterResult) {
    objc_setAssociatedObject(web, &wantKey, rules, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    RuleLists.compile("nushi.browser-local-network", rules: rules, result) { list in
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
  }
}

/// What a browser tab's ⋯ menu asks of WebKit (lib/browser_menu.dart): the
/// page in sight as a PNG, and every site's data gone from WebKit's default
/// store, the one browser tabs and file previews share (docs/security.md).
enum BrowserData {
  /// The plugin's web view as it's on screen, the part in sight only, as
  /// PNG data, or an error.
  static func snapshot(_ web: WKWebView, _ result: @escaping FlutterResult) {
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
    _ web: WKWebView, id: Int64, channel: FlutterMethodChannel, _ result: @escaping FlutterResult
  ) {
    guard let inner = web.navigationDelegate else { return result(Browser.refused) }
    if inner is CommitWatch { return result(nil) }
    let watch = CommitWatch(inner: inner) { [weak channel] url in
      channel?.invokeMethod("committed", arguments: ["id": NSNumber(value: id), "url": url?.absoluteString ?? ""])
    }
    // It lives as long as its web view.
    objc_setAssociatedObject(web, &key, watch, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    web.navigationDelegate = watch
    result(nil)
  }

  /// What WebKit said of the main frame's navigation to [url] in [web],
  /// taken: its `WKNavigationType`'s raw value and whether it's a redirect,
  /// or nil when nothing waits for it. Those before it go too.
  static func navigation(_ web: WKWebView, url: String) -> [String: Any]? {
    guard let watch = objc_getAssociatedObject(web, &key) as? CommitWatch,
      let at = watch.deciding.firstIndex(where: { $0.url == url })
    else { return nil }
    let told = watch.deciding[at]
    watch.deciding.removeSubrange(...at)
    var said: [String: Any] = ["type": told.type]
    if let redirect = told.redirect { said["redirect"] = redirect }
    return said
  }

  /// The address of the history item [by] steps from [web]'s page (0 is
  /// the page's own, which a reload loads), or nil when there's none.
  static func historyItem(_ web: WKWebView, by: Int) -> String? {
    web.backForwardList.item(at: by)?.url.absoluteString
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
