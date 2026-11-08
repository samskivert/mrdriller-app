import AVFoundation
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
    MicRecorder.register(engineBridge.applicationRegistrar.messenger())

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

// Records the microphone for calibrating a drum pad (see lib/services/mic_recorder_native.dart):
// raw (measurement mode, so no gain control, noise suppression or echo cancellation, which would
// take out or smear the sounds being timed), and with every buffer's sample position and host time
// (mach_absolute_time, in nanoseconds: the clock CoreMIDI stamps MIDI with), so the app knows
// exactly when each sample was recorded. Answers "open" (asking for permission the first time;
// returns the sample rate) and "close" on mrdriller/mic, and streams buffers on mrdriller/mic/samples
// as {frame, hostNs, samples (float32)}.
final class MicRecorder: NSObject, FlutterStreamHandler {
  private static var shared: MicRecorder?
  private let engine = AVAudioEngine()
  private var sink: FlutterEventSink?
  private var running = false
  private let nanosPerTick: Double = {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    return Double(timebase.numer) / Double(timebase.denom)
  }()

  static func register(_ messenger: FlutterBinaryMessenger) {
    let recorder = MicRecorder()
    shared = recorder
    FlutterMethodChannel(name: "mrdriller/mic", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "open": recorder.open(result)
        case "close":
          recorder.close()
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "mrdriller/mic/samples", binaryMessenger: messenger)
      .setStreamHandler(recorder)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func open(_ result: @escaping FlutterResult) {
    AVAudioSession.sharedInstance().requestRecordPermission { granted in
      DispatchQueue.main.async {
        guard granted else {
          result(
            FlutterError(
              code: "denied",
              message:
                "Microphone access is turned off for this app. Turn it on in Settings, under Privacy & Security, Microphone.",
              details: nil))
          return
        }
        do {
          try self.start()
          result(["sampleRate": self.engine.inputNode.outputFormat(forBus: 0).sampleRate])
        } catch {
          self.close()
          result(
            FlutterError(
              code: "failed", message: "Couldn't record the microphone: \(error.localizedDescription)",
              details: nil))
        }
      }
    }
  }

  private func start() throws {
    if running { return }
    // Playing on through the speaker, not the earpiece (where play-and-record otherwise sends it),
    // and alongside other audio, as the metronome's own session does (see
    // lib/services/sound_engine.dart).
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord, mode: .measurement,
      options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
    try session.setActive(true)
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
      self?.send(buffer, at: time)
    }
    engine.prepare()
    try engine.start()
    running = true
  }

  // (On the audio thread.)
  private func send(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
    guard let channel = buffer.floatChannelData?[0], time.isSampleTimeValid, time.isHostTimeValid
    else { return }
    let data = Data(bytes: channel, count: Int(buffer.frameLength) * MemoryLayout<Float>.size)
    let event: [String: Any] = [
      "frame": Int(time.sampleTime),
      "hostNs": Int((Double(time.hostTime) * nanosPerTick).rounded()),
      "samples": FlutterStandardTypedData(float32: data),
    ]
    DispatchQueue.main.async { self.sink?(event) }
  }

  private func close() {
    if running {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
      running = false
    }
    // Back to the metronome's own session (see lib/services/sound_engine.dart).
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
  }
}
