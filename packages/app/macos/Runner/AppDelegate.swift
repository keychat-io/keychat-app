import Cocoa
import FlutterMacOS
import UserNotifications
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Return false so the app stays alive when the window is closed/minimized
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    // Restore minimized or hidden window when user clicks the Dock icon
    for window in sender.windows {
      if window.isMiniaturized {
        window.deminiaturize(self)
      } else if !window.isVisible {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    // Clear all delivered notifications from notification center when app becomes active
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    // Restore minimized window when switching back via Cmd+Tab or other means
    for window in NSApplication.shared.windows {
      if window.isMiniaturized {
        window.deminiaturize(self)
      }
    }
  }

  public override func application(
    _ application: NSApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
  ) -> Bool {

    guard let url = AppLinks.shared.getUniversalLink(userActivity) else {
      return false
    }

    AppLinks.shared.handleLink(link: url.absoluteString)

    return false  // Returning true will stop the propagation to other packages
  }
}
