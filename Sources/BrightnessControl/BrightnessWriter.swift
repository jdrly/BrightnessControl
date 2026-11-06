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
            // Reads once per monitor: a lazy compactMap reads twice and crashes when a monitor
            // answers only the first time, which the HP Z27xs G3 sometimes does.
            for service in self.currentServices() {
                if let value = DDC.read(service, vcp: DDC.luminance) {
                    completion(Int((Double(value.current) / Double(value.max) * 100).rounded()))
                    return
                }
            }
            completion(nil)
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
