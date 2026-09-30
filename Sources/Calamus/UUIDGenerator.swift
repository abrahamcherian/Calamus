import Foundation
import CryptoKit

/// Generates UUIDs of several versions (RFC 4122 / RFC 9562).
enum UUIDGenerator {
    /// The standard namespaces used by name-based UUIDs (versions 3 and 5).
    enum Namespace: Int, CaseIterable {
        case dns, url, oid, x500

        var label: String {
            switch self {
            case .dns: return "DNS (domain name)"
            case .url: return "URL"
            case .oid: return "OID"
            case .x500: return "X.500 (distinguished name)"
            }
        }

        var bytes: [UInt8] {
            let last: UInt8
            switch self {
            case .dns: last = 0x10
            case .url: last = 0x11
            case .oid: last = 0x12
            case .x500: last = 0x14
            }
            // 6ba7b81X-9dad-11d1-80b4-00c04fd430c8
            return [0x6b, 0xa7, 0xb8, last, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8]
        }
    }

    // MARK: - Formatting

    /// Canonical lowercase text: 8-4-4-4-12.
    static func text(_ bytes: [UInt8]) -> String {
        let hex = bytes.map { String(format: "%02x", $0) }
        return hex[0..<4].joined() + "-" + hex[4..<6].joined() + "-" + hex[6..<8].joined()
            + "-" + hex[8..<10].joined() + "-" + hex[10..<16].joined()
    }

    /// Applies the chosen output style: "lower", "upper", "compact" (no dashes) or "braces".
    static func styled(_ canonical: String, format: String) -> String {
        switch format {
        case "upper": return canonical.uppercased()
        case "compact": return canonical.replacingOccurrences(of: "-", with: "")
        case "braces": return "{" + canonical + "}"
        default: return canonical
        }
    }

    // MARK: - Helpers

    private static func randomBytes(_ count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) }
    }

    private static func setVersionAndVariant(_ bytes: inout [UInt8], version: UInt8) {
        bytes[6] = (bytes[6] & 0x0F) | (version << 4)
        bytes[8] = (bytes[8] & 0x3F) | 0x80
    }

    /// 60-bit count of 100-nanosecond steps since 1582-10-15 (used by versions 1 and 6).
    private static func gregorianTimestamp(_ date: Date) -> UInt64 {
        let gregorianOffset: UInt64 = 122_192_928_000_000_000
        let milliseconds = UInt64(max(0, date.timeIntervalSince1970) * 1000)
        let subMillisecond = UInt64.random(in: 0..<10_000) // spread IDs made in the same millisecond
        return milliseconds * 10_000 + subMillisecond + gregorianOffset
    }

    private static func randomNode() -> [UInt8] {
        var node = randomBytes(6)
        node[0] |= 0x01 // multicast bit: marks a random (not hardware) node id
        return node
    }

    // MARK: - Versions

    static func version1(date: Date = Date()) -> [UInt8] {
        let t = gregorianTimestamp(date)
        let clock = randomBytes(2)
        var b: [UInt8] = [
            UInt8((t >> 24) & 0xFF), UInt8((t >> 16) & 0xFF), UInt8((t >> 8) & 0xFF), UInt8(t & 0xFF), // time_low
            UInt8((t >> 40) & 0xFF), UInt8((t >> 32) & 0xFF),                                          // time_mid
            UInt8((t >> 56) & 0x0F), UInt8((t >> 48) & 0xFF),                                          // time_hi
            clock[0], clock[1]
        ]
        b += randomNode()
        setVersionAndVariant(&b, version: 1)
        return b
    }

    static func version4() -> [UInt8] {
        var b = randomBytes(16)
        setVersionAndVariant(&b, version: 4)
        return b
    }

    static func version6(date: Date = Date()) -> [UInt8] {
        let t = gregorianTimestamp(date)
        let clock = randomBytes(2)
        var b: [UInt8] = [
            UInt8((t >> 52) & 0xFF), UInt8((t >> 44) & 0xFF), UInt8((t >> 36) & 0xFF), UInt8((t >> 28) & 0xFF),
            UInt8((t >> 20) & 0xFF), UInt8((t >> 12) & 0xFF),
            UInt8((t >> 8) & 0x0F), UInt8(t & 0xFF),
            clock[0], clock[1]
        ]
        b += randomNode()
        setVersionAndVariant(&b, version: 6)
        return b
    }

    static func version7(date: Date = Date()) -> [UInt8] {
        let milliseconds = UInt64(max(0, date.timeIntervalSince1970) * 1000)
        var b = randomBytes(16)
        for index in 0..<6 {
            b[index] = UInt8((milliseconds >> UInt64(8 * (5 - index))) & 0xFF) // 48-bit Unix time in ms
        }
        setVersionAndVariant(&b, version: 7)
        return b
    }

    /// Version 8 is for custom layouts; this one is simply 122 random bits with the version 8 marker.
    static func version8() -> [UInt8] {
        var b = randomBytes(16)
        setVersionAndVariant(&b, version: 8)
        return b
    }

    static func version3(namespace: Namespace, name: String) -> [UInt8] {
        let digest = Insecure.MD5.hash(data: Data(namespace.bytes + Array(name.utf8)))
        var b = Array(digest.prefix(16))
        setVersionAndVariant(&b, version: 3)
        return b
    }

    static func version5(namespace: Namespace, name: String) -> [UInt8] {
        let digest = Insecure.SHA1.hash(data: Data(namespace.bytes + Array(name.utf8)))
        var b = Array(digest.prefix(16))
        setVersionAndVariant(&b, version: 5)
        return b
    }

    static let nilUUID = [UInt8](repeating: 0x00, count: 16)
    static let maxUUID = [UInt8](repeating: 0xFF, count: 16)

    // MARK: - Menu ids

    /// Canonical text for the menu ids that need no extra input (versions 1, 4, 6, 7, 8, nil, max).
    static func canonical(forID id: String) -> String? {
        switch id {
        case "uuid.v1": return text(version1())
        case "uuid.v4": return text(version4())
        case "uuid.v6": return text(version6())
        case "uuid.v7": return text(version7())
        case "uuid.v8": return text(version8())
        case "uuid.nil": return text(nilUUID)
        case "uuid.max": return text(maxUUID)
        default: return nil
        }
    }

    /// Generates several canonical UUIDs of one kind at once, for "Generate Multiple". Each call to
    /// `canonical(forID:)` draws fresh randomness/timestamps, so version 1/4/6/7/8 entries come back
    /// distinct; the nil and max UUIDs are constants, so every line is (expectedly) the same value.
    /// The most UUIDs "Generate Multiple" will make in one go.
    static let maxMultipleCount = 500

    static func multiple(forID id: String, count: Int) -> [String] {
        let validIDs: Set<String> = ["uuid.v1", "uuid.v4", "uuid.v6", "uuid.v7", "uuid.v8", "uuid.nil", "uuid.max"]
        guard count > 0, validIDs.contains(id) else { return [] }
        return (0..<count).compactMap { _ in canonical(forID: id) }
    }
}
