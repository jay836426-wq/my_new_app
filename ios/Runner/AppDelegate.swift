import Flutter
import UIKit
import UserNotifications
import AVFoundation
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var focusAlarm: TrakOnFocusAlarmBridge?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TrakOnFocusAlarm") {
      focusAlarm = TrakOnFocusAlarmBridge(messenger: registrar.messenger())
    }
  }
}


#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct TrakOnAlarmMetadata: AlarmMetadata {
  var mode: String
}
#endif

/// Uses an alert-only fixed schedule. No countdown Live Activity is advertised.
/// The Flutter deadline remains the single source of countdown/pause timing.
@MainActor
private final class TrakOnFocusAlarmBridge {
  private let channel: FlutterMethodChannel
  private let alarmID = UUID(uuidString: "F7DF3B2E-C706-43EB-9B85-02222DC5836A")!
  private var player: AVAudioPlayer?
  private var foregroundWork: DispatchWorkItem?
  private var backgroundObserver: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.gettrakon.trakon/focus_alarm", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in
        guard let self else { result(FlutterError(code: "unavailable", message: "Alarm service unavailable", details: nil)); return }
        do {
          switch call.method {
          case "requestAuthorization":
            #if canImport(AlarmKit)
            if #available(iOS 26.0, *) {
              let authorization = try await AlarmManager.shared.requestAuthorization()
              result(authorization == .authorized)
            } else { result(false) }
            #else
            result(false)
            #endif
          case "schedule":
            guard let args = call.arguments as? [String: Any],
                  let seconds = args["deadline"] as? Double else {
              result(FlutterError(code: "arguments", message: "Missing timer deadline", details: nil)); return
            }
            result(try await self.schedule(
              deadline: Date(timeIntervalSince1970: seconds),
              title: args["title"] as? String ?? "Focus complete",
              body: args["body"] as? String ?? "",
              mode: args["mode"] as? String ?? "Focus"))
          case "cancel": try self.cancel(); result(nil)
          case "stopSound": self.stopSound(); result(nil)
          default: result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "alarm", message: error.localizedDescription, details: nil))
        }
      }
    }
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.stopSound() }
      }
  }

  private func schedule(deadline: Date, title: String, body: String, mode: String) async throws -> [String: String] {
    try cancel()
    guard deadline > Date() else { throw NSError(domain: "TrakOn", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "The timer deadline has already passed."]) }
    try installSounds()
    let filename = mode == "Break" ? "trakon_break.wav" : "trakon_focus.wav"
    var warning = "On this iPhone, background alerts use a notification sound and follow silent mode and Focus settings."
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      if AlarmManager.shared.authorizationState == .authorized {
        do {
          let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
          let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: body.isEmpty ? title : "\(title): \(body)"), stopButton: stop)
          let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
            metadata: TrakOnAlarmMetadata(mode: mode), tintColor: mode == "Break" ? Color.cyan : Color.green)
          let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(deadline), attributes: attributes,
            stopIntent: nil, secondaryIntent: nil, sound: .named(filename))
          _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
          return ["backend": "alarm"]
        } catch {
          warning = "The system alarm could not be scheduled. Using a notification sound instead."
        }
      } else {
        warning = "Alarm access is off. Using a notification sound; enable Alarms for TrakOn in iPhone Settings for a ringing alarm."
      }
    }
    #endif
    let work = DispatchWorkItem { [weak self] in
      Task { @MainActor in
        guard UIApplication.shared.applicationState == .active else { return }
        try? self?.play(filename: filename)
      }
    }
    foregroundWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSinceNow), execute: work)
    return ["backend": "notification", "warning": warning]
  }

  private func cancel() throws {
    foregroundWork?.cancel(); foregroundWork = nil
    stopSound()
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *), AlarmManager.shared.authorizationState == .authorized {
      if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
        do { try AlarmManager.shared.stop(id: alarmID) }
        catch { try AlarmManager.shared.cancel(id: alarmID) }
        if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
          try AlarmManager.shared.cancel(id: alarmID)
        }
      }
    }
    #endif
  }
  private func stopSound() {
    player?.stop(); player = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  private func play(filename: String) throws {
    guard player?.isPlaying != true else { return }
    let url = try soundsDirectory().appendingPathComponent(filename)
    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
    try AVAudioSession.sharedInstance().setActive(true)
    player = try AVAudioPlayer(contentsOf: url)
    player?.numberOfLoops = -1
    player?.volume = 0.65
    player?.prepareToPlay(); player?.play()
  }
  private func soundsDirectory() throws -> URL {
    let folder = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sounds", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }
  private func installSounds() throws {
    let folder = try soundsDirectory()
    for (filename, tones) in [
      ("trakon_focus.wav", [659.25, 783.99, 987.77, 783.99]),
      ("trakon_break.wav", [880.0, 698.46, 587.33, 698.46])
    ] {
      let url = folder.appendingPathComponent(filename)
      if FileManager.default.fileExists(atPath: url.path) { continue }
      let rate = 22050
      let count = rate * 4
      var samples = Data(capacity: count * 2)
      for i in 0..<count {
        let t = Double(i) / Double(rate)
        let position = t.truncatingRemainder(dividingBy: 0.5)
        let tone = tones[min(Int(t / 0.5) % tones.count, tones.count - 1)]
        let envelope = position < 0.34 ? min(1, position / 0.015) * min(1, (0.34 - position) / 0.08) : 0
        let sample = Int16(sin(2 * Double.pi * tone * t) * envelope * 15000)
        var little = sample.littleEndian
        withUnsafeBytes(of: &little) { samples.append(contentsOf: $0) }
      }
      var wave = Data()
      func ascii(_ text: String) { wave.append(text.data(using: .ascii)!) }
      func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wave.append(contentsOf: $0) } }
      func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wave.append(contentsOf: $0) } }
      ascii("RIFF"); u32(UInt32(36 + samples.count)); ascii("WAVEfmt ")
      u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
      ascii("data"); u32(UInt32(samples.count)); wave.append(samples)
      try wave.write(to: url, options: .atomic)
      try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }
  }
}
