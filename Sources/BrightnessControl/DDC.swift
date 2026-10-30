import CIOAV
import Foundation
import IOKit

/// DDC/CI over the display AV service on Apple silicon, as m1ddc does it.
enum DDC {
    static let luminance: UInt8 = 0x10

    private static let chipAddress: UInt32 = 0x37
    private static let dataAddress: UInt32 = 0x51

    /// The AV services of external displays (DCPAVServiceProxy with Location = External).
    static func externalServices() -> [IOAVService] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var services: [IOAVService] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            guard location == "External", let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry) else {
                continue
            }
            services.append(service)
        }
        return services
    }

    /// Sets a VCP feature. Sent twice, 10 ms apart, as m1ddc does, since some monitors drop the first.
    @discardableResult
    static func write(_ service: IOAVService, vcp: UInt8, value: UInt16) -> Bool {
        var packet: [UInt8] = [0x84, 0x03, vcp, UInt8(value >> 8), UInt8(value & 0xFF), 0]
        packet[5] = checksum(0x6E ^ UInt8(dataAddress), packet[0..<5])
        var ok = false
        for _ in 0..<2 {
            usleep(10_000)
            ok = IOAVServiceWriteI2C(service, chipAddress, dataAddress, &packet, UInt32(packet.count)) == kIOReturnSuccess || ok
        }
        return ok
    }

    /// Reads a VCP feature's current and maximum value, or nil when the monitor doesn't answer.
    static func read(_ service: IOAVService, vcp: UInt8) -> (current: UInt16, max: UInt16)? {
        var request: [UInt8] = [0x82, 0x01, vcp, 0]
        request[3] = checksum(0x6E ^ UInt8(dataAddress), request[0..<3])
        var reply = [UInt8](repeating: 0, count: 11)
        for _ in 0..<2 {
            usleep(10_000)
            guard IOAVServiceWriteI2C(service, chipAddress, dataAddress, &request, UInt32(request.count)) == kIOReturnSuccess else {
                continue
            }
            usleep(50_000)
            guard IOAVServiceReadI2C(service, chipAddress, 0, &reply, UInt32(reply.count)) == kIOReturnSuccess else {
                continue
            }
            // Reply: source 0x6E, length, 0x02, result code, VCP, type, max hi/lo, current hi/lo, checksum.
            guard reply[2] == 0x02, reply[3] == 0x00, reply[4] == vcp,
                  checksum(0x50, reply[0..<10]) == reply[10] else { continue }
            let max = UInt16(reply[6]) << 8 | UInt16(reply[7])
            let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
            return max > 0 ? (current, max) : nil
        }
        return nil
    }

    private static func checksum(_ seed: UInt8, _ bytes: ArraySlice<UInt8>) -> UInt8 {
        bytes.reduce(seed, ^)
    }
}
