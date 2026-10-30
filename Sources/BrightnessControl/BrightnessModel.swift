import AppKit
import Observation
import ServiceManagement

@MainActor @Observable
final class BrightnessModel {
    static let step = 10.0

    /// The slider's value, 0–100 in steps of 10. Setting it sends it to the monitors.
    var brightness: Double {
        didSet {
            guard brightness != oldValue else { return }
            UserDefaults.standard.set(brightness, forKey: Self.brightnessKey)
            if !skipWrite { writer.set(Int(brightness)) }
        }
    }

    private(set) var displayName = DisplayInfo.externalName()
    private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var appearance = SystemAppearance.current

    @ObservationIgnored private let writer = BrightnessWriter()
    @ObservationIgnored private var skipWrite = false
    @ObservationIgnored private static let brightnessKey = "brightness"

    init() {
        let saved = UserDefaults.standard.object(forKey: Self.brightnessKey) as? Double
        brightness = saved ?? 50

        // The monitor's own value wins over the saved one, when it answers DDC reads.
        writer.read { percent in
            guard let percent else { return }
            Task { @MainActor in self.show(percent) }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.displaysChanged() }
        }

        // Keeps the picker in step when Auto flips the theme or System Settings changes it.
        DistributedNotificationCenter.default().addObserver(
            forName: SystemAppearance.changedNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.appearance = SystemAppearance.current }
        }
    }

    func setAppearance(_ appearance: SystemAppearance) {
        SystemAppearance.set(appearance)
        self.appearance = SystemAppearance.current
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login: \(error.localizedDescription)")
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Shows a value read from the monitor without writing it back.
    private func show(_ percent: Int) {
        skipWrite = true
        brightness = min(100, max(0, (Double(percent) / Self.step).rounded() * Self.step))
        skipWrite = false
    }

    private func displaysChanged() {
        displayName = DisplayInfo.externalName()
        writer.rescan()
    }
}

enum DisplayInfo {
    /// The external monitor's name for the header, e.g. "HP Z27xs G3".
    static func externalName() -> String? {
        let external = NSScreen.screens.filter { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            return id.map { CGDisplayIsBuiltin($0) == 0 } ?? false
        }
        switch external.count {
        case 0: return nil
        case 1: return external[0].localizedName
        default: return "\(external.count) displays"
        }
    }
}
