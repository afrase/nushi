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

// A picture: as PNG. A 2 by 2 bitmap, as TIFF (a screenshot's or Copy
// Image's), and a PDF (Numbers' cells carry one beside their text).
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let tiff = bitmap.tiffRepresentation!
let pdf = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 10)).dataWithPDF(inside: NSRect(x: 0, y: 0, width: 20, height: 10))

/// [board] holding [types] with their data only.
func holdingData(_ types: [(NSPasteboard.PasteboardType, Data)]) {
  board.clearContents()
  board.declareTypes(types.map(\.0), owner: nil)
  for (type, data) in types { board.setData(data, forType: type) }
}

let text = Data("A1\tB1".utf8)
holdingData([(.string, text)])
expect(Clipboard.image(board) == nil, true, "text, no picture")
holdingData([(.tiff, tiff)])
expect(Clipboard.image(board).flatMap(NSBitmapImageRep.init(data:))?.pixelsWide, 2, "a picture")
holdingData([(.pdf, pdf)])
expect(Clipboard.image(board) != nil, true, "a PDF alone")
holdingData([(.string, text), (.rtf, text), (.pdf, pdf)])
expect(Clipboard.image(board) == nil, true, "cells: text with a PDF of it")
holdingData([(.string, text), (.tiff, tiff)])
expect(Clipboard.image(board) == nil, true, "text with a picture")

board.releaseGlobally()
if failed > 0 {
  print("\(failed) failed")
  exit(1)
}
print("clipboard: ok")
