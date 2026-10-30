import Foundation

/// macOS's Light, Dark and Auto appearance, read and set through SkyLight's private calls,
/// the ones System Settings uses (no Automation prompt, unlike scripting System Events).
enum SystemAppearance: String, CaseIterable, Identifiable {
    case light, dark, auto

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .auto: "Auto"
        }
    }

    var symbol: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .auto: "circle.lefthalf.filled"
        }
    }

    /// Posted by macOS whenever the appearance changes, from here or System Settings.
    static let changedNotification = Notification.Name("AppleInterfaceThemeChangedNotification")

    static var current: SystemAppearance {
        if SkyLight.getAutomatic?() == true { return .auto }
        return SkyLight.getDark?() == true ? .dark : .light
    }

    static func set(_ appearance: SystemAppearance) {
        switch appearance {
        case .auto:
            SkyLight.setAutomatic?(true)
        case .light, .dark:
            SkyLight.setAutomatic?(false)
            SkyLight.setDark?(appearance == .dark)
        }
    }
}

private enum SkyLight {
    nonisolated(unsafe) private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    static let getDark = function("SLSGetAppearanceThemeLegacy", as: (@convention(c) () -> Bool).self)
    static let setDark = function("SLSSetAppearanceThemeLegacy", as: (@convention(c) (Bool) -> Void).self)
    static let getAutomatic = function("SLSGetAppearanceThemeSwitchesAutomatically", as: (@convention(c) () -> Bool).self)
    static let setAutomatic = function("SLSSetAppearanceThemeSwitchesAutomatically", as: (@convention(c) (Bool) -> Void).self)

    private static func function<T>(_ name: String, as type: T.Type) -> T? {
        dlsym(handle, name).map { unsafeBitCast($0, to: type) }
    }
}
