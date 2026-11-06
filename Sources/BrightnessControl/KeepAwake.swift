import Foundation
import Observation

/// What `caffeinate` holds awake. Both block idle sleep on battery (`-i`) and all automatic
/// system sleep on power (`-s`); `-d` also keeps the display on.
enum AwakeTarget: String, CaseIterable, Identifiable {
    case displayAndMac, mac

    var id: Self { self }

    var title: String {
        switch self {
        case .displayAndMac: "Display & Mac"
        case .mac: "Mac Only"
        }
    }

    var flags: [String] {
        switch self {
        case .displayAndMac: ["-d", "-i", "-s"]
        case .mac: ["-i", "-s"]
        }
    }
}

/// Runs `/usr/bin/caffeinate` while on. `-w` ties it to this app's pid, so quitting or
/// crashing can't leave the Mac held awake. It's never turned back on after a relaunch.
@MainActor @Observable
final class KeepAwake {
    static let hoursRange = 1.0...12.0

    /// Changing it while on restarts `caffeinate`, and with it the duration.
    var target: AwakeTarget {
        didSet {
            guard target != oldValue else { return }
            UserDefaults.standard.set(target.rawValue, forKey: Self.targetKey)
            restartIfOn()
        }
    }

    /// The slider's value, 1–12 in whole hours.
    var hours: Double {
        didSet {
            guard hours != oldValue else { return }
            UserDefaults.standard.set(hours, forKey: Self.hoursKey)
            restartIfOn()
        }
    }

    private(set) var endsAt: Date?

    var isOn: Bool { endsAt != nil }

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private static let targetKey = "keepAwakeTarget"
    @ObservationIgnored private static let hoursKey = "keepAwakeHours"

    init() {
        let defaults = UserDefaults.standard
        target = defaults.string(forKey: Self.targetKey).flatMap(AwakeTarget.init) ?? .displayAndMac
        hours = defaults.object(forKey: Self.hoursKey) as? Double ?? Self.hoursRange.lowerBound
    }

    func setOn(_ on: Bool) {
        stop()
        if on { start() }
    }

    private func restartIfOn() {
        if isOn { setOn(true) }
    }

    private func start() {
        let seconds = Int(hours) * 3600
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = target.flags + ["-t", String(seconds), "-w", String(ProcessInfo.processInfo.processIdentifier)]
        process.terminationHandler = { ended in
            let ended = ObjectIdentifier(ended)
            Task { @MainActor in
                // A restart may have replaced it while this was on its way here.
                if self.process.map(ObjectIdentifier.init) == ended { self.stop() }
            }
        }
        do {
            try process.run()
        } catch {
            NSLog("Keep awake: \(error.localizedDescription)")
            return
        }
        self.process = process
        endsAt = Date.now.addingTimeInterval(TimeInterval(seconds))
    }

    private func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        endsAt = nil
    }
}
