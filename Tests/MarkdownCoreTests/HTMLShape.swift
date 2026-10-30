import Foundation

/// The structure of an HTML fragment, for comparing two renderers: element
/// names, `href` on `a`, `checked` on `input`, and text with entities decoded
/// and whitespace runs collapsed. Other attributes are dropped (log 010
/// conformance README: compare structure, not attributes).
enum HTMLShape {
    static func tokens(_ html: String) -> [String] {
        var tokens: [String] = []
        var text = ""
        func flushText() {
            let collapsed = decode(text).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !collapsed.isEmpty {
                if let last = tokens.last, last.hasPrefix("text:") {
                    tokens[tokens.count - 1] = last + " " + collapsed
                } else {
                    tokens.append("text:" + collapsed)
                }
            }
            text = ""
        }
        var rest = Substring(html)
        while let open = rest.firstIndex(of: "<") {
            text += rest[..<open]
            guard let close = rest[open...].firstIndex(of: ">") else { break }
            flushText()
            tokens += tag(String(rest[rest.index(after: open) ..< close]))
            rest = rest[rest.index(after: close)...]
        }
        text += rest
        flushText()
        return tokens
    }

    /// `img` becomes the `Image: {alt}` link that `imageFallback .link` draws.
    private static func tag(_ body: String) -> [String] {
        let trimmed = body.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let name = String(trimmed.prefix { !$0.isWhitespace }).lowercased()
        if body.hasPrefix("/") {
            return ["/" + name]
        }
        switch name {
        case "a": return ["a href=" + (attribute("href", in: body) ?? "")]
        case "input": return [attribute("checked", in: body) == nil ? "input" : "input checked"]
        case "img":
            let link = "a href=" + (attribute("src", in: body) ?? "")
            return [link, "text:Image: " + (attribute("alt", in: body) ?? ""), "/a"]
        default: return [name]
        }
    }

    private static func attribute(_ name: String, in body: String) -> String? {
        guard let range = body.range(of: #"\s\#(name)(="[^"]*")?"#, options: .regularExpression) else { return nil }
        let value = body[range].split(separator: "\"", omittingEmptySubsequences: false).dropFirst().first ?? ""
        return decode(String(value))
    }

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let named = ["lt": "<", "gt": ">", "amp": "&", "quot": "\"", "apos": "'", "nbsp": "\u{A0}"]
        return text.replacing(/&(#[xX][0-9A-Fa-f]+|#[0-9]+|[A-Za-z]+);/) { match in
            let entity = String(match.1)
            let hex = entity.lowercased().hasPrefix("#x")
            let code = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10)
            if entity.hasPrefix("#"), let scalar = code.flatMap(Unicode.Scalar.init) {
                return String(Character(scalar))
            }
            return named[entity] ?? String(match.0)
        }
    }
}
