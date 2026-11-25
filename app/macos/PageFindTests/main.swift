// A page's find (Runner/PageFind.swift and its script, Runner/PageFind.js;
// ADR 0143), built with it by `make test-window` and run in a WKWebView of
// its own that is never shown, on pages written here: nothing is loaded
// from the network.
import AppKit
import WebKit

var failed = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ what: String, line: Int = #line) {
  guard got != want else { return }
  failed += 1
  print("FAIL line \(line): \(what): got \(got), want \(want)")
}

/// Runs the main run loop until [done] says so, for 20 seconds at most (a
/// loaded CI runner starts WebKit's processes slowly): WebKit answers there.
func wait(_ what: String, until done: () -> Bool) {
  let deadline = Date().addingTimeInterval(20)
  while !done() {
    guard Date() < deadline else {
      print("FAIL: timed out waiting for \(what)")
      exit(1)
    }
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
  }
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "app/macos/Runner/PageFind.js"
guard let script = try? String(contentsOfFile: path, encoding: .utf8) else {
  print("FAIL: no script at \(path)")
  exit(1)
}

_ = NSApplication.shared
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

/// Loads [html] in the web view and waits for it.
final class Loaded: NSObject, WKNavigationDelegate {
  var done = false
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done = true }
}
let loaded = Loaded()
web.navigationDelegate = loaded

func load(_ html: String) {
  loaded.done = false
  web.loadHTMLString("<!doctype html><html><body>\(html)</body></html>", baseURL: nil)
  wait("the page to load") { loaded.done }
}

/// The find's answer to [op] with [query], as the app asks it.
func find(_ query: String, op: String = "find", at: Int = 0) -> (count: Int, at: Int) {
  var answer: Result<[String: Any], Error>?
  let args: [String: Any] = [
    "id": 1, "op": op, "query": query, "at": at, "hit": "rgba(255, 200, 0, 0.4)",
    "now": "rgba(255, 150, 0, 0.8)", "edge": "rgba(0, 0, 0, 1)", "cover": 0,
  ]
  PageFind.run(web, script: script, args: args) { answer = $0 }
  wait("the find's answer") { answer != nil }
  switch answer! {
  case .success(let value): return ((value["count"] as? Int) ?? -1, (value["at"] as? Int) ?? -1)
  case .failure(let error):
    failed += 1
    print("FAIL: \(op) \(query): \(error)")
    return (-1, -1)
  }
}

/// [js] run in the page's own world, as the page's scripts would.
func page(_ js: String) -> Any? {
  var answer: Result<Any, Error>?
  web.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { answer = $0 }
  wait("the page's answer") { answer != nil }
  if case .failure(let error) = answer! {
    failed += 1
    print("FAIL: page script: \(error)")
    return nil
  }
  return try? answer!.get()
}

// Counts matches, case aside, and the current one is the one asked for.
load("<p>Apple apple APPLE</p><p>an apple a day</p>")
expect(find("apple").count, 4, "matches, case aside")
expect(find("apple", at: 2).at, 2, "the current match")
expect(find("apple", at: 9).at, 3, "the current match past the end is the last")
expect(find("pear").count, 0, "no match")
expect(find("").count, 0, "an empty query")
expect(find("a.p").count, 0, "a query's dot is plain text, not a pattern")

// Only the text a user sees: no script, style, form field or hidden text.
load("""
  <p>needle</p>
  <script>var s = 'needle';</script><style>.needle {}</style>
  <textarea>needle</textarea>
  <div hidden>needle</div><div style="display:none">needle</div>
  <div style="visibility:hidden">needle</div>
  """)
expect(find("needle").count, 1, "hidden text skipped")

// A match may cross inline elements, never two blocks.
load("<p>ne<b>ed</b>le</p><p>hay</p><p>stack</p>")
expect(find("needle").count, 1, "a match across inline elements")
expect(find("haystack").count, 0, "a match across two blocks")

// At most 10,000.
load("<p>\(String(repeating: "x ", count: 10_050))</p>")
expect(find("x").count, 10_000, "the cap")

// The page sees no ranges once the find clears: each is emptied first.
load("<p>one two one</p>")
expect(find("one").count, 2, "matches before clearing")
let held = page("""
  const h = CSS.highlights.get('nushi-find-now');
  window.kept = [...CSS.highlights.get('nushi-find'), ...h];
  return window.kept.length;
  """) as? Int
expect(held, 2, "the ranges the page holds")
expect(find("", op: "clear").count, 0, "clear")
expect(page("return window.kept.every((r) => r.collapsed);") as? Bool, true, "every range emptied")

// The find's variables stay in its own world.
expect(page("return typeof window.__nushiFind;") as? String, "undefined", "the page can't see its state")

if failed > 0 {
  print("page find: \(failed) failed")
  exit(1)
}
print("page find: ok")
