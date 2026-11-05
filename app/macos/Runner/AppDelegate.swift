import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// The `nushi/clipboard` channel (Clipboard.swift), once the window's
  /// engine is up: the main window is made from the nib before launching
  /// ends.
  override func awakeFromNib() {
    super.awakeFromNib()
    NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { [weak self] _ in
      guard let controller = self?.mainFlutterWindow?.contentViewController as? FlutterViewController else { return }
      FlutterMethodChannel(name: "nushi/clipboard", binaryMessenger: controller.engine.binaryMessenger)
        .setMethodCallHandler { call, result in
          switch call.method {
          case "files": result(Clipboard.files())
          case "image": result(Clipboard.image().map(FlutterStandardTypedData.init(bytes:)))
          default: result(FlutterMethodNotImplemented)
          }
        }
    }
  }
}
