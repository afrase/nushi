import AppKit
import WebKit

/// A page's find (lib/web_find.dart, ADR 0143): a script run in a content world
/// of Nushi's own, so the page's scripts can't see its variables or change the
/// functions it calls, marking the matches with the CSS Custom Highlight API,
/// which leaves the page's DOM, text and selection as they were (WebKit's own
/// find sets the selection, which the page sees). The page can read the
/// highlights' ranges while they're shown; they're emptied as they go. Its colours come as
/// arguments, checked to be rgba() before they go in the style sheet. The
/// script is PageFind.js, a resource of the app's bundle, so a test can run
/// it on a page of its own (`make test-window`); this file needs WebKit only.
enum PageFind {
  /// The script as the app's bundle holds it; nil when it's missing.
  static let bundled: String? = Bundle.main.url(forResource: "PageFind", withExtension: "js")
    .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

  /// Runs [script] in web view [web] with the channel's arguments (less the
  /// web view's id), then gives its count and current match, or the error.
  static func run(
    _ web: WKWebView, script: String, args: [String: Any], _ done: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    var given = args
    given.removeValue(forKey: "id")
    web.callAsyncJavaScript(script, arguments: given, in: nil, in: .defaultClient) { answer in
      done(answer.map { $0 as? [String: Any] ?? ["count": 0, "at": 0] })
    }
  }

  /// Whether the web view, or a view inside it, has the keys.
  static func focused(_ web: WKWebView) -> Bool {
    guard let view = web.window?.firstResponder as? NSView else { return false }
    return view === web || view.isDescendant(of: web)
  }
}
