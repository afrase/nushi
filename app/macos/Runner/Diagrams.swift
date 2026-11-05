import Cocoa
import FlutterMacOS
import WebKit

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

  /// A diagram to draw, and everyone waiting for it.
  private final class Job {
    let source: String
    let args: [String: Any]
    var dones: [FlutterResult]

    init(source: String, args: [String: Any], done: @escaping FlutterResult) {
      self.source = source
      self.args = args
      dones = [done]
    }

    /// Whether it draws the same picture as [source] with [args].
    func same(_ source: String, _ args: [String: Any]) -> Bool {
      source == self.source && args["dark"] as? Bool == self.args["dark"] as? Bool
        && args["background"] as? String == self.args["background"] as? String
        && args["foreground"] as? String == self.args["foreground"] as? String
        && args["width"] as? Double == self.args["width"] as? Double
    }

    func answer(_ value: Any) { for done in dones { done(value) } }
  }

  private var web: WKWebView?
  private var window: NSWindow?
  private var loaded = false
  private var queue: [Job] = []
  private var busy = false
  private var drawing: Job? // the job drawing
  private var current = 0 // the job drawing, counted: a late answer of one let go is dropped

  /// Queues a diagram, or joins the job already drawing or waiting for the
  /// same one: the app asks again for one it gave up waiting on (its
  /// diagramWait, the queue included), and a copy would only be drawn
  /// again before the rest.
  func draw(source: String, args: [String: Any], done: @escaping FlutterResult) {
    if let job = ([drawing].compactMap { $0 } + queue).first(where: { $0.same(source, args) }) {
      job.dones.append(done)
      return
    }
    queue.append(Job(source: source, args: args, done: done))
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
    drawing = job
    DispatchQueue.main.asyncAfter(deadline: .now() + Diagrams.jobTimeout) { [weak self] in
      guard let self, self.current == id, let job = self.drawing else { return }
      self.letGo()
      job.answer(["error": "The diagram took too long to draw"])
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
    guard let job = drawing else { return }
    drawing = nil
    job.answer(answer)
    busy = false
    next()
  }

  private func start() -> WKWebView? {
    guard FileManager.default.fileExists(atPath: Diagrams.page.path) else {
      for job in queue { job.answer(["error": "This build has no Mermaid (make mermaid)"]) }
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
    let pending = [drawing].compactMap { $0 } + queue
    queue = []
    letGo()
    // Not the diagrams' fault: the app asks for them again (retry).
    for job in pending { job.answer(["error": error?.localizedDescription ?? "The diagram's web view stopped", "retry": true]) }
  }
}
