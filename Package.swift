// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrightnessControl",
    platforms: [.macOS("27.0")],
    targets: [
        // IOKit's private IOAVService calls (the ones m1ddc uses) for DDC/CI over I2C.
        .target(
            name: "CIOAV",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
        ),
        .executableTarget(
            name: "BrightnessControl",
            dependencies: ["CIOAV"]
        ),
    ]
)
