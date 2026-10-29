/// Literal IP address checks for the image host blocklist.
enum IPAddress {
    /// The blocked IPv4 ranges as (network, prefix length).
    private static let blockedIPv4: [(UInt32, Int)] = [
        (0x0000_0000, 8), (0x0A00_0000, 8), (0x6440_0000, 10), (0x7F00_0000, 8), (0xA9FE_0000, 16),
        (0xAC10_0000, 12), (0xC0A8_0000, 16), (0xC612_0000, 15), (0xE000_0000, 4), (0xF000_0000, 4)
    ]

    /// A host whose dot-separated parts are all numbers (decimal, octal, or
    /// `0x` hex, as inet_aton reads them) is an IPv4 literal. It is blocked
    /// unless it is canonical dotted decimal outside every blocked range. Any
    /// other host is a name and is not blocked here.
    static func isBlockedIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard (1 ... 4).contains(parts.count), parts.allSatisfy(isNumber) else { return false }
        // Canonical: four decimal parts, each printed back as its own value.
        let octets = parts.compactMap { UInt8($0) }
        guard octets.count == 4, zip(parts, octets).allSatisfy({ $0 == String($1) }) else { return true }
        return isBlocked(octets.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
    }

    private static func isBlocked(_ address: UInt32) -> Bool {
        blockedIPv4.contains { network, length in address >> (32 - length) == network >> (32 - length) }
    }

    /// A `0x` hex part (inet_aton reads a bare `0x` as zero) or a part of
    /// digits. An empty part counts, so a malformed literal is blocked.
    private static func isNumber(_ part: Substring) -> Bool {
        if part.lowercased().hasPrefix("0x") {
            return part.dropFirst(2).allSatisfy(\.isHexDigit)
        }
        return part.allSatisfy(\.isNumber)
    }

    /// An IPv6 literal is blocked when it is `::`, `::1`, in fc00::/7 or
    /// fe80::/10, maps a blocked IPv4 address, or cannot be read.
    static func isBlockedIPv6(_ host: String) -> Bool {
        guard let bytes = ipv6Bytes(host) else { return true }
        if bytes.allSatisfy({ $0 == 0 }) || bytes == [UInt8](repeating: 0, count: 15) + [1] {
            return true
        }
        if bytes[0] & 0xFE == 0xFC || (bytes[0] == 0xFE && bytes[1] & 0xC0 == 0x80) {
            return true
        }
        if bytes[0 ..< 10].allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
            return isBlocked(bytes[12...].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        }
        return false
    }

    /// The 16 bytes of an IPv6 literal, with `::` and a trailing dotted IPv4.
    private static func ipv6Bytes(_ host: String) -> [UInt8]? {
        let halves = host.components(separatedBy: "::")
        guard halves.count <= 2, let head = groups(halves[0]) else { return nil }
        let tail = halves.count == 2 ? groups(halves[1]) : []
        guard let tail else { return nil }
        let missing = 8 - head.count - tail.count
        guard halves.count == 2 ? missing >= 1 : missing == 0 else { return nil }
        let all = head + [UInt16](repeating: 0, count: missing) + tail
        return all.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
    }

    private static func groups(_ text: String) -> [UInt16]? {
        guard !text.isEmpty else { return [] }
        var result: [UInt16] = []
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        for (index, part) in parts.enumerated() {
            if index == parts.count - 1, part.contains(".") {
                let octets = part.split(separator: ".", omittingEmptySubsequences: false).compactMap { UInt8($0) }
                guard octets.count == 4 else { return nil }
                result += [UInt16(octets[0]) << 8 | UInt16(octets[1]), UInt16(octets[2]) << 8 | UInt16(octets[3])]
            } else {
                guard (1 ... 4).contains(part.count), let value = UInt16(part, radix: 16) else { return nil }
                result.append(value)
            }
        }
        return result
    }
}
