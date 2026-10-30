import CIOAV
import Foundation

/// Sends brightness to every external monitor off the main thread. Monitors take tens of
/// milliseconds per DDC write and some lock up when flooded, so only the latest value is
/// sent and writes are at least 100 ms apart.
final class BrightnessWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "cz.jandrly.BrightnessControl.ddc", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: Int?
    private var draining = false
    private var services: [IOAVService] = []

    func set(_ percent: Int) {
        lock.lock()
        pending = percent
        let start = !draining
        draining = true
        lock.unlock()
        if start { queue.async { self.drain() } }
    }

    /// Forgets the found monitors, for the next write to look again (after a display change).
    func rescan() {
        queue.async { self.services = [] }
    }

    /// The first monitor's brightness in percent, or nil when no monitor answers.
    func read(_ completion: @escaping @Sendable (Int?) -> Void) {
        queue.async {
            let value = self.currentServices().lazy.compactMap { DDC.read($0, vcp: DDC.luminance) }.first
            completion(value.map { Int((Double($0.current) / Double($0.max) * 100).rounded()) })
        }
    }

    private func drain() {
        while true {
            lock.lock()
            guard let percent = pending else {
                draining = false
                lock.unlock()
                return
            }
            pending = nil
            lock.unlock()

            for service in currentServices() {
                DDC.write(service, vcp: DDC.luminance, value: UInt16(percent))
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func currentServices() -> [IOAVService] {
        if services.isEmpty { services = DDC.externalServices() }
        return services
    }
}
