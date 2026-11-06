import AppKit
import SwiftUI

@main
struct BrightnessControlApp: App {
    @State private var model = BrightnessModel()
    @State private var keepAwake = KeepAwake()

    var body: some Scene {
        MenuBarExtra {
            BrightnessPanel(model: model, keepAwake: keepAwake)
        } label: {
            Image(nsImage: keepAwake.isOn ? MenuBarIcon.awakeImage : MenuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The display's brightness, keep awake, then launch at login and quit, straight on the menu bar panel's glass.
struct BrightnessPanel: View {
    @Bindable var model: BrightnessModel
    @Bindable var keepAwake: KeepAwake

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            display
            appearancePicker
            Divider()
            keepAwakeSection
            Divider()
            HStack {
                loginToggle
                Spacer()
                quitButton
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var display: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display").font(.headline)
                    Text(model.displayName ?? "No external display")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(model.brightness)) %")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: model.brightness))
                    .animation(.snappy, value: model.brightness)
            }

            Slider(value: $model.brightness, in: 0...100, step: BrightnessModel.step) {
                Text("Brightness")
            } minimumValueLabel: {
                Image(systemName: "sun.min")
            } maximumValueLabel: {
                Image(systemName: "sun.max.fill")
            } tick: { value in
                SliderTick(value)
            }
            .labelsHidden()
            .disabled(model.displayName == nil)
        }
    }

    private var appearancePicker: some View {
        Picker("Appearance", selection: Binding(
            get: { model.appearance },
            set: { model.setAppearance($0) }
        )) {
            ForEach(SystemAppearance.allCases) { appearance in
                Label(appearance.title, systemImage: appearance.symbol).tag(appearance)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .buttonSizing(.flexible)
    }

    private var keepAwakeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Awake").font(.headline)
                    Text(keepAwakeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Keep Awake", isOn: Binding(
                    get: { keepAwake.isOn },
                    set: { keepAwake.setOn($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            Picker("Stay awake", selection: $keepAwake.target) {
                ForEach(AwakeTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .buttonSizing(.flexible)

            Slider(value: $keepAwake.hours, in: KeepAwake.hoursRange, step: 1) {
                Text("Duration")
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("1 h")
            } maximumValueLabel: {
                Text("12 h")
            } tick: { value in
                SliderTick(value)
            }
            .labelsHidden()
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var keepAwakeStatus: String {
        guard let endsAt = keepAwake.endsAt else { return "Off" }
        return "\(Int(keepAwake.hours)) h, until \(endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private var loginToggle: some View {
        Toggle("Open at Login", isOn: Binding(
            get: { model.launchesAtLogin },
            set: { model.setLaunchesAtLogin($0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Image(systemName: "power")
                .font(.body.weight(.semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .keyboardShortcut("q")
        .help("Quit BrightnessControl")
    }
}

/// The menu bar glyph: a disc with eight rays, drawn as a template image. The disc is half lit,
/// and fully lit while keep awake is on.
enum MenuBarIcon {
    static let image = make(fullyLit: false)
    static let awakeImage = make(fullyLit: true)

    private static func make(fullyLit: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            NSColor.black.set()

            let disc = NSBezierPath(ovalIn: NSRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
            disc.lineWidth = 1.5
            disc.stroke()
            let lit = NSBezierPath()
            lit.appendArc(withCenter: center, radius: 4, startAngle: 90, endAngle: fullyLit ? 450 : 270, clockwise: false)
            lit.close()
            lit.fill()

            let rays = NSBezierPath()
            rays.lineWidth = 1.5
            rays.lineCapStyle = .round
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                rays.move(to: NSPoint(x: center.x + 6.5 * cos(angle), y: center.y + 6.5 * sin(angle)))
                rays.line(to: NSPoint(x: center.x + 8 * cos(angle), y: center.y + 8 * sin(angle)))
            }
            rays.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = fullyLit ? "Brightness, keeping Mac awake" : "Brightness"
        return image
    }
}
