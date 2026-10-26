import Cocoa
import FlutterMacOS
import ServiceManagement

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

    // Start at login (ADR 0036): the launch agent in the bundle, which opens
    // the daemon's helper app. Answers its status after each call.
    if #available(macOS 13.0, *) {
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
    }

    super.awakeFromNib()
  }
}
