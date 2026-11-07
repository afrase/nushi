import AppKit

/// What the composer's ⌘V attaches beside its text (lib/clipboard_files_macos.dart),
/// read from a pasteboard on the `nushi/clipboard` channel (AppDelegate).
/// AppKit only, so `make test-window` builds it without Flutter.
enum Clipboard {
  /// The paths of the files on [pasteboard] (Finder's copy). Only file URLs:
  /// a web link (Safari's Copy Link) is an NSURL too, and its path is no file
  /// of the Mac's.
  static func files(_ pasteboard: NSPasteboard = .general) -> [String] {
    let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ?? []
    return urls.compactMap { ($0 as? URL)?.path }
  }

  /// The picture on [pasteboard] as PNG (a screenshot, Copy Image), or nil.
  /// None when it holds text too: then what was copied is text, and the
  /// picture beside it is that text drawn (Numbers' and Excel's cells carry
  /// a PDF of themselves), which ⌘V pastes as text.
  static func image(_ pasteboard: NSPasteboard = .general) -> Data? {
    guard pasteboard.availableType(from: [.string]) == nil,
          let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
          let tiff = image.tiffRepresentation
    else { return nil }
    return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
  }
}
