import Foundation
@testable import MarkdownCore

/// Parses the `### Color` table of design log 001: `| `token` | dark | light |`.
/// A value is `#RRGGBB` or `rgba(r,g,b,a)`.
enum DesignColorTable {
    struct ParseError: Error, CustomStringConvertible {
        let description: String
    }

    static func load() throws -> [String: ColorToken] {
        let log = try String(contentsOf: RepoPath.url("design-logs/001-markdown-library.md"), encoding: .utf8)
        return try parse(log)
    }

    static func parse(_ log: String) throws -> [String: ColorToken] {
        guard let section = log.components(separatedBy: "\n### Color\n").dropFirst().first else {
            throw ParseError(description: "no ### Color section")
        }
        var rows: [String: ColorToken] = [:]
        for line in section.split(separator: "\n").prefix(while: { !$0.hasPrefix("#") }) {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count == 3, cells[0].hasPrefix("`") else { continue }
            let name = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            rows[name] = try ColorToken(dark: color(cells[1]), light: color(cells[2]))
        }
        return rows
    }

    static func color(_ cell: String) throws -> SRGBColor {
        let value = cell.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
        if value.hasPrefix("#"), value.count == 7, let rgb = UInt32(value.dropFirst(), radix: 16) {
            return SRGBColor(red: UInt8(rgb >> 16), green: UInt8((rgb >> 8) & 0xFF), blue: UInt8(rgb & 0xFF))
        }
        if value.hasPrefix("rgba("), value.hasSuffix(")") {
            let parts = value.dropFirst(5).dropLast().split(separator: ",")
            let rgb = parts.prefix(3).compactMap { UInt8($0) }
            if parts.count == 4, rgb.count == 3, let alpha = Double(parts[3]) {
                return SRGBColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: alpha)
            }
        }
        throw ParseError(description: "bad color cell: \(cell)")
    }
}
