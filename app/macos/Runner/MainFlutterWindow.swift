import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

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

    super.awakeFromNib()
  }
}
