import Cocoa
import FlutterMacOS
import UserNotifications

/// The Mac's notifications (macOS shows them; nothing leaves the Mac) and
/// the Dock badge. Permission is asked on the first notification, not at
/// launch. A click on one tells the app which chat to open.
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
  static let shared = Alerts()
  var channel: FlutterMethodChannel?

  override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
  }

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "badge":
      let label = call.arguments as? String ?? ""
      NSApp.dockTile.badgeLabel = label.isEmpty ? nil : label
      result(nil)
    case "status":
      center.getNotificationSettings { settings in
        let status: String = switch settings.authorizationStatus {
        case .authorized, .provisional: "authorized"
        case .denied: "denied"
        default: "notDetermined"
        }
        DispatchQueue.main.async { result(status) }
      }
    case "post":
      guard let args = call.arguments as? [String: Any], let id = args["id"] as? String,
        let chat = args["chat"] as? String
      else { return result(FlutterError(code: "refused", message: "No notification", details: nil)) }
      let content = UNMutableNotificationContent()
      content.title = args["title"] as? String ?? "Nushi"
      content.body = args["body"] as? String ?? ""
      content.userInfo = ["chat": chat]
      content.threadIdentifier = chat
      if args["sound"] as? Bool == true { content.sound = .default }
      center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        guard granted else {
          return DispatchQueue.main.async { result(error.map { FlutterError(code: "denied", message: $0.localizedDescription, details: nil) } ?? "denied") }
        }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
          DispatchQueue.main.async {
            result(error.map { FlutterError(code: "failed", message: $0.localizedDescription, details: nil) } ?? "posted")
          }
        }
      }
    case "clear":
      let chat = call.arguments as? String ?? ""
      center.getDeliveredNotifications { delivered in
        let ids = delivered.filter { $0.request.content.userInfo["chat"] as? String == chat }.map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: ids)
        DispatchQueue.main.async { result(nil) }
      }
    case "withdraw":
      center.removeDeliveredNotifications(withIdentifiers: call.arguments as? [String] ?? [])
      result(nil)
    case "openSettings":
      let id = Bundle.main.bundleIdentifier ?? ""
      NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")!)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // In front too: the app decides what to post (another chat than the one
  // showing), so macOS shows it.
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
    done(notification.request.content.sound == nil ? [.banner, .list] : [.banner, .list, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                              withCompletionHandler done: @escaping () -> Void) {
    if let chat = response.notification.request.content.userInfo["chat"] as? String {
      DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        self.channel?.invokeMethod("open", arguments: chat)
      }
    }
    done()
  }
}
