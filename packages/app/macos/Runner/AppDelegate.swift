import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // dummy_method_to_enforce_bundling()
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    if let window = NSApplication.shared.windows.first {
        window.backgroundColor = NSColor.white
        window.setContentSize(NSMakeSize(830, 730)) 
        let screenFrame = window.screen?.frame ?? NSRect.zero 
        let centerX = (screenFrame.width - window.frame.width) / 2 
        let centerY = (screenFrame.height - window.frame.height) / 2
        window.setFrameOrigin(NSPoint(x: centerX, y: centerY)) 
    }
  }
}
