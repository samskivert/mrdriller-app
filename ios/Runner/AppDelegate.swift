import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets scheduled reminders show their banner/sound while the app is in the foreground too,
    // and routes notification taps through the plugin.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Required so the plugin can still reach the rest of the app's registered plugins when a
    // notification-related callback runs on its own isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerCloudStore(engineBridge)

    // Reports which way the interface is rotated, so that in landscape the app can tell which side
    // of the screen the camera housing (notch/Dynamic Island) is on. iOS reports equal safe-area
    // insets on both sides, and Flutter only exposes cutout positions on Android. Answers
    // "interfaceOrientation" when asked, and pushes "interfaceOrientationChanged" after the device
    // rotates -- including a 180° turn from one landscape to the other, which doesn't change the
    // screen's size or insets, so Flutter has no reason to notice it. See
    // lib/services/screen_cutout.dart.
    let channel = FlutterMethodChannel(
      name: "mrdriller/display",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "interfaceOrientation" {
        result(AppDelegate.interfaceOrientation())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(
      forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
    ) { _ in
      // The interface follows the device around a moment after this fires (if it rotates at all),
      // so report once it's likely done, and again once it certainly is.
      for delay in [0.3, 0.8] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          channel.invokeMethod(
            "interfaceOrientationChanged", arguments: AppDelegate.interfaceOrientation())
        }
      }
    }
  }

  // Exposes the iCloud key-value store, where a copy of the app's state is kept so that it outlives
  // the app being deleted and syncs between the user's devices. Answers "getAll" (every string in
  // the store) and "set" (a key and a string value), and pushes "changed" when another device
  // changes the store. See lib/services/cloud_store.dart.
  private func registerCloudStore(_ engineBridge: FlutterImplicitEngineBridge) {
    let store = NSUbiquitousKeyValueStore.default
    let channel = FlutterMethodChannel(
      name: "mrdriller/cloud",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAll":
        result(store.dictionaryRepresentation.compactMapValues { $0 as? String })
      case "set":
        guard let args = call.arguments as? [String: String], let key = args["key"] else {
          result(FlutterError(code: "bad-args", message: "set needs a key", details: nil))
          return
        }
        store.set(args["value"], forKey: key)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store,
      queue: .main
    ) { _ in
      channel.invokeMethod("changed", arguments: nil)
    }
    // Picks up anything changed elsewhere since the app last ran.
    store.synchronize()
  }

  private static func interfaceOrientation() -> String? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let orientation: UIInterfaceOrientation?
    if #available(iOS 16.0, *) {
      orientation = scene?.effectiveGeometry.interfaceOrientation
    } else {
      orientation = scene?.interfaceOrientation
    }
    switch orientation {
    case .landscapeLeft: return "landscapeLeft"
    case .landscapeRight: return "landscapeRight"
    case .portrait: return "portrait"
    case .portraitUpsideDown: return "portraitUpsideDown"
    default: return nil
    }
  }
}
