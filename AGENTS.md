# BrightnessControl

Jan's menu bar app for his external monitor's brightness: a slider from 0 to 100 in steps of 10, sent over DDC/CI.

- SwiftPM, macOS 27+, Apple silicon. `Sources/CIOAV` declares IOKit's private `IOAVService*` calls, the same ones m1ddc uses. The app doesn't need the m1ddc binary.
- `BrightnessWriter` sends only the latest value, waiting at least 100 ms between writes. Monitors lock up if every drag step reaches them.
- Jan's HP Z27xs G3 doesn't answer DDC reads (it returns a null message, `6e 80 be`), so the slider starts from the last value it sent, saved in UserDefaults.
- The Light / Dark / Auto control sets the system appearance through SkyLight's private `SLSSetAppearanceTheme*` calls, looked up with dlsym. These are what System Settings uses, so there's no Automation prompt. It stays in step through `AppleInterfaceThemeChangedNotification`.
- `./scripts/build.sh` builds `build/BrightnessControl.app` and signs it with the Developer ID (hardened runtime). It then notarizes with the `swgl-notary` keychain profile, staples, and installs to /Applications. `NOTARIZE=0` and `INSTALL=0` skip those steps.
- `./scripts/release.sh` publishes the notarized zip as the GitHub release `v<CFBundleShortVersionString>`. Raise the version and `CFBundleVersion` in `Resources/Info.plist` and commit before running it. Public repo: github.com/jdrly/BrightnessControl. The README follows the unslop rules.
- The icon is an Icon Composer document (`Resources/AppIcon.icon`), compiled by actool.
