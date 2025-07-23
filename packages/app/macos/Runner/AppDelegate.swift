import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // dummy_method_to_enforce_bundling()
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let window = NSApplication.shared.windows.first {
        window.backgroundColor = NSColor.white
        window.setContentSize(NSMakeSize(830, 730)) 
        window.center();
        window.delegate = self
    }
  }
  
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
        for window in NSApplication.shared.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
    return true
  }

  public override func application(_ application: NSApplication,
                                 continue userActivity: NSUserActivity,
                                 restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {

  guard let url = AppLinks.shared.getUniversalLink(userActivity) else {
    return false
  }
  
  AppLinks.shared.handleLink(link: url.absoluteString)
  
  return false // Returning true will stop the propagation to other packages
}
}

extension AppDelegate: NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil) 
    return false 
  }
}
