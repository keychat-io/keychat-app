import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "keychat",
                                       binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "exportFile" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid argument", details: nil))
          return
        }
        self.handleExportFile(filePath: filePath, result: result, controller: controller)
      } else if call.method == "importFile" {
        self.handleImportFile(result: result, controller: controller)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleExportFile(filePath: String, result: @escaping FlutterResult, controller: UIViewController) {
    FileHelper.exportFile(atPath: filePath, sender: controller) { completed in
      if completed {
        result("File exported successfully")
      } else {
        result(FlutterError(code: "EXPORT_FAILED", message: "File export failed", details: nil))
      }
    }
  }

  private func handleImportFile(result: @escaping FlutterResult, controller: UIViewController) {
    FileHelper.importFile(sender: controller) { filePath in
      result(filePath)
    }
  }
}

// FileHelper.swift
import UIKit

class FileHelper {
  static public func exportFile(atPath filePath: String, sender: UIViewController, completion: @escaping (_ completed: Bool) -> Void) {
    let fileURL = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      completion(false)
      return
    }

    let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
      completion(completed)
    }

    // for iPad
    if let popoverController = activityViewController.popoverPresentationController {
      popoverController.sourceView = sender.view
      popoverController.sourceRect = CGRect(x: sender.view.bounds.midX, y: sender.view.bounds.midY, width: 0, height: 0)
      popoverController.permittedArrowDirections = []
    }

    sender.present(activityViewController, animated: true, completion: nil)
  }

  static public func importFile(sender: UIViewController, callback: @escaping (String) -> Void) {
    let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
    documentPicker.delegate = sender as? UIDocumentPickerDelegate
    objc_setAssociatedObject(sender, &documentPickerCallbackKey, callback, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    sender.present(documentPicker, animated: true, completion: nil)
  }
}

private var documentPickerCallbackKey: Void?

// UIDocumentPickerDelegate
extension UIViewController: UIDocumentPickerDelegate {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if let callback = objc_getAssociatedObject(self, &documentPickerCallbackKey) as? (String) -> Void {
      callback(urls.first?.path ?? "")
    }
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if let callback = objc_getAssociatedObject(self, &documentPickerCallbackKey) as? (String) -> Void {
      callback("")
    }
  }
}