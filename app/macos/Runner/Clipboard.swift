import AppKit

/// What the composer's ⌘V attaches beside its text (lib/attached_files.dart),
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
}
