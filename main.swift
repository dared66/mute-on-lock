import CoreAudio
import CoreGraphics
import Foundation

private let appName = "Mute on Lock"
private let defaultIdleMinutes = 15.0
private let allowedIdleMinutes = 0.1...10_080.0
private let lockNotification = Notification.Name("com.apple.screenIsLocked")
private let configNotification = Notification.Name("local.mute-on-lock.configChanged")
private let configURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Mute on lock/config.json")

private struct Configuration: Codable {
    var idleMinutes = defaultIdleMinutes
}

private func readConfiguration() -> Configuration {
    guard let data = try? Data(contentsOf: configURL),
          let value = try? JSONDecoder().decode(Configuration.self, from: data),
          value.idleMinutes.isFinite,
          allowedIdleMinutes.contains(value.idleMinutes) else {
        return Configuration()
    }
    return value
}

private func writeConfiguration(idleMinutes: Double) throws {
    try FileManager.default.createDirectory(
        at: configURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    let data = try JSONEncoder().encode(Configuration(idleMinutes: idleMinutes))
    try data.write(to: configURL, options: [.atomic])
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
}

private func idleSeconds() -> Double {
    CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: CGEventType(rawValue: UInt32.max)!
    )
}

private struct IdlePolicy {
    var muted = false
    var previousIdle = 0.0

    mutating func tick(idle: Double, threshold: Double, action: () -> Bool) {
        guard idle.isFinite, idle >= 0, threshold.isFinite, threshold > 0 else { return }
        if idle < previousIdle || idle < threshold { muted = false }
        previousIdle = idle
        if idle >= threshold && !muted { muted = action() }
    }
}

private func defaultOutputDevice() -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var device = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
    )
    return status == noErr && device != kAudioObjectUnknown ? device : nil
}

private func setMute(on device: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: element
    )
    guard AudioObjectHasProperty(device, &address) else { return false }
    var settable: DarwinBoolean = false
    guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
          settable.boolValue else { return false }
    var value: UInt32 = 1
    return AudioObjectSetPropertyData(
        device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
    ) == noErr
}

@discardableResult
private func mute() -> Bool {
    guard let device = defaultOutputDevice() else {
        NSLog("%@: no default audio output", appName)
        return false
    }

    let muted = setMute(on: device, element: kAudioObjectPropertyElementMain)
        || (setMute(on: device, element: 1) && setMute(on: device, element: 2))
    NSLog(muted ? "%@: audio muted" : "%@: output does not expose a writable mute control", appName)
    return muted
}

private func printUsage() {
    print("""
    Usage:
      mute-on-lock                         Run the background service
      mute-on-lock --set-idle-minutes N    Set inactivity timeout (0.1–10080)
      mute-on-lock --status                Show settings and current inactivity
      mute-on-lock --self-test             Test policy and mute the current output
    """)
}

if CommandLine.arguments.count > 1 {
    switch CommandLine.arguments[1] {
    case "--set-idle-minutes":
        guard CommandLine.arguments.count == 3,
              let minutes = Double(CommandLine.arguments[2]),
              minutes.isFinite,
              allowedIdleMinutes.contains(minutes) else {
            fputs("Provide a number from 0.1 through 10080 minutes.\n", stderr)
            exit(2)
        }
        do {
            try writeConfiguration(idleMinutes: minutes)
            DistributedNotificationCenter.default().postNotificationName(
                configNotification, object: nil, userInfo: nil, deliverImmediately: true
            )
            print("Idle timeout: \(minutes) minutes. Applied immediately.")
            exit(0)
        } catch {
            fputs("Could not save configuration: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    case "--status":
        let config = readConfiguration()
        print("Idle timeout: \(config.idleMinutes) minutes")
        print("Current inactivity: \(String(format: "%.1f", idleSeconds())) seconds")
        print("Configuration: \(configURL.path)")
        exit(0)
    case "--self-test":
        var policy = IdlePolicy()
        var calls = 0
        func attempt() -> Bool { calls += 1; return true }
        policy.tick(idle: 899, threshold: 900, action: attempt)
        precondition(calls == 0)
        policy.tick(idle: 900, threshold: 900, action: attempt)
        policy.tick(idle: 905, threshold: 900, action: attempt)
        precondition(calls == 1)
        policy.tick(idle: 0, threshold: 900, action: attempt)
        policy.tick(idle: 900, threshold: 900, action: attempt)
        precondition(calls == 2)
        var retry = IdlePolicy()
        retry.tick(idle: 900, threshold: 900) { false }
        retry.tick(idle: 905, threshold: 900, action: attempt)
        precondition(calls == 3)
        print("PASS: idle policy")
        let passed = mute()
        print(passed ? "PASS: macOS confirmed output mute" : "FAIL: output mute was not confirmed")
        exit(passed ? 0 : 1)
    case "--help", "-h":
        printUsage()
        exit(0)
    default:
        printUsage()
        exit(2)
    }
}

private let center = DistributedNotificationCenter.default()
private var configuration = readConfiguration()
private let lockToken = center.addObserver(forName: lockNotification, object: nil, queue: .main) { _ in
    mute()
}
private let configToken = center.addObserver(forName: configNotification, object: nil, queue: .main) { _ in
    configuration = readConfiguration()
    NSLog("%@: idle timeout changed to %.2f minutes", appName, configuration.idleMinutes)
}
private var policy = IdlePolicy()
private func checkIdle() {
    policy.tick(idle: idleSeconds(), threshold: configuration.idleMinutes * 60, action: mute)
}
private let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in checkIdle() }
timer.tolerance = 0.5
checkIdle()
NSLog("%@: listening for screen locks; idle timeout %.2f minutes", appName, configuration.idleMinutes)
RunLoop.main.run()
withExtendedLifetime((lockToken, configToken, timer)) {}
