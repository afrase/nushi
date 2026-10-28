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
    // macOS keeps the window's size and place across launches.
    self.setFrameAutosaveName("Nushi")

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

    // Opens an address in the default browser (a preview's Open in browser and
    // its links): the app that opens https, for a file too, so a file a page
    // links is never run by the app its type has.
    FlutterMethodChannel(name: "nushi/browser", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
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

    super.awakeFromNib()
  }
}

/// Draws Mermaid diagrams for the transcript, one at a time, in a web view
/// of their own that's never shown (in a window off screen): the app's
/// mermaid.html with its pinned mermaid.min.js, nothing else loaded (any
/// other navigation is refused). Each is drawn at the width asked, then
/// snapshot as a PNG at the screen's scale.
final class Diagrams: NSObject, WKNavigationDelegate {
  /// The page, among the app's Flutter assets.
  static let page = Bundle.main.privateFrameworksURL!
    .appendingPathComponent("App.framework/Resources/flutter_assets/assets/mermaid/mermaid.html")

  private var web: WKWebView?
  private var window: NSWindow?
  private var loaded = false
  private var queue: [(source: String, args: [String: Any], done: FlutterResult)] = []
  private var busy = false

  func draw(source: String, args: [String: Any], done: @escaping FlutterResult) {
    queue.append((source, args, done))
    next()
  }

  private func next() {
    guard !busy, !queue.isEmpty else { return }
    guard let web = web ?? start() else { return }
    guard loaded else { return } // didFinish goes on
    busy = true
    let job = queue.removeFirst()
    let width = min(max(job.args["width"] as? Double ?? 600, 120), 2400)
    web.setFrameSize(NSSize(width: width, height: 400))
    let opts: [String: Any] = [
      "dark": job.args["dark"] as? Bool ?? false,
      "background": job.args["background"] as? String ?? "",
      "foreground": job.args["foreground"] as? String ?? "",
    ]
    web.callAsyncJavaScript("return await show(source, opts)", arguments: ["source": job.source, "opts": opts],
                            in: nil, in: .page) { [weak self] answer in
      guard let self else { return }
      switch answer {
      case .failure(let error): self.finish(job.done, ["error": error.localizedDescription])
      case .success(let value):
        let drawn = value as? [String: Any] ?? [:]
        if let error = drawn["error"] as? String { return self.finish(job.done, ["error": error]) }
        let w = min(drawn["width"] as? Double ?? 0, width)
        let h = min(drawn["height"] as? Double ?? 0, 8000)
        guard w > 0, h > 0 else { return self.finish(job.done, ["error": "The diagram came out empty"]) }
        web.setFrameSize(NSSize(width: width, height: h))
        // Laid out at the new height before the snapshot.
        DispatchQueue.main.async {
          let config = WKSnapshotConfiguration()
          config.rect = NSRect(x: 0, y: 0, width: w, height: h)
          web.takeSnapshot(with: config) { image, error in
            guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
            else { return self.finish(job.done, ["error": error?.localizedDescription ?? "No snapshot"]) }
            self.finish(job.done, ["png": FlutterStandardTypedData(bytes: png), "width": w, "height": h])
          }
        }
      }
    }
  }

  private func finish(_ done: FlutterResult, _ answer: [String: Any]) {
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

  private func fail(_ error: Error?) {
    let pending = queue
    queue = []
    web = nil
    window = nil
    loaded = false
    busy = false
    for job in pending { job.done(["error": error?.localizedDescription ?? "The diagram's web view stopped"]) }
  }
}
