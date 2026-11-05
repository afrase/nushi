// What ⌘V attaches (Runner/Clipboard.swift), built with it by
// `make test-window` and run on a pasteboard of its own, never the user's.
import AppKit

var failed = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ what: String, line: Int = #line) {
  guard got != want else { return }
  failed += 1
  print("FAIL line \(line): \(what): got \(got), want \(want)")
}

let board = NSPasteboard(name: NSPasteboard.Name("nushi-clipboard-test-\(ProcessInfo.processInfo.processIdentifier)"))

/// [board] holding [items] only.
func holding(_ items: [NSPasteboardWriting]) {
  board.clearContents()
  board.writeObjects(items)
}

// Finder's copy: the files' paths.
holding([NSURL(fileURLWithPath: "/etc/hosts"), NSURL(fileURLWithPath: "/tmp/a b.txt")])
expect(Clipboard.files(board), ["/etc/hosts", "/tmp/a b.txt"], "file URLs")

// Safari's Copy Link: a web URL is no file, even when its path is one.
holding([NSURL(string: "https://example.com/etc/hosts")!])
expect(Clipboard.files(board), [], "a web link")
holding([NSURL(string: "https://example.com/etc/hosts")!, NSURL(fileURLWithPath: "/etc/hosts")])
expect(Clipboard.files(board), ["/etc/hosts"], "a web link and a file")

// Text only.
holding(["/etc/hosts" as NSString])
expect(Clipboard.files(board), [], "text")

board.releaseGlobally()
if failed > 0 {
  print("\(failed) failed")
  exit(1)
}
print("clipboard: ok")
