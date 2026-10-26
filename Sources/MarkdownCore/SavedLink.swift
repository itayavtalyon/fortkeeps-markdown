import Foundation

/// The saved-link card rule of log 010 (D21-01 to D21-04), as its reference
/// generator `saved_link` states it.
enum SavedLink {
    /// The characters Python's `str.strip(ASCII_WS)` removes.
    private static let asciiWhitespace = CharacterSet(charactersIn: " \t\n\r\u{0B}\u{0C}")

    static func parse(_ body: String) -> FortkeepsCard.Link? {
        let rawLines = body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let firstIndex = rawLines.firstIndex(where: { !$0.trimmingCharacters(in: asciiWhitespace).isEmpty })
        else { return nil }
        let nonempty = rawLines.map { $0.trimmingCharacters(in: asciiWhitespace) }.filter { !$0.isEmpty }
        let last = nonempty[nonempty.count - 1]
        let before = nonempty.dropLast()
        let plainBefore = before.count <= 3 && !before.contains(where: isBlocky) && !before
            .contains { lineURL($0) != nil }
        if let url = lineURL(last), plainBefore {
            let (host, path) = hostAndPath(url)
            guard let first = before.first else {
                return FortkeepsCard.Link(form: .capture, url: url, title: host, excerpt: path)
            }
            let title = first.replacing(/^#\s+/, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return FortkeepsCard.Link(
                form: .capture,
                url: url,
                title: title.isEmpty ? host : title,
                excerpt: before.count >= 2 ? before.last : path
            )
        }
        let markdownLink = nonempty[0]
            .wholeMatch(of: /\[([^\]]+)\]\((https?:\/\/[^\s)]+)(?:\s+"[^"]*")?\)/.ignoresCase())
        guard let url = markdownLink.map({ String($0.2) }) ?? lineURL(nonempty[0]) else { return nil }
        let (host, path) = hostAndPath(url)
        let rest = rawLines[(firstIndex + 1)...].joined(separator: "\n").trimmingCharacters(in: asciiWhitespace)
        let excerpt = rest.isEmpty ? path : FortkeepsCard.visibleText(
            MarkdownDocument(text: rest, features: .fortkeeps, presentation: MarkdownPresentation())
        )
        return FortkeepsCard.Link(
            form: .leading,
            url: url,
            title: markdownLink.map { String($0.1) } ?? host,
            excerpt: excerpt?.isEmpty == false ? excerpt : path
        )
    }

    /// The URL of a line that is only `<url>` or a bare http(s) URL with a host.
    private static func lineURL(_ line: String) -> String? {
        let url: String
        if let match = line.wholeMatch(of: /<(https?:\/\/[^>\s]+)>/.ignoresCase()) {
            url = String(match.1)
        } else if line.wholeMatch(of: /https?:\/\/\S+/.ignoresCase()) != nil {
            url = line
        } else {
            return nil
        }
        return url.prefixMatch(of: /https?:\/\/[^\/?#:@]+/.ignoresCase()) == nil ? nil : url
    }

    /// The lowercased host without `www.`, and the path when it is more than `/`.
    private static func hostAndPath(_ url: String) -> (host: String, path: String?) {
        guard let match = url.prefixMatch(
            of: /https?:\/\/(?:[^\/?#@]*@)?([^\/?#:]+)(?::\d+)?([^?#]*)/.ignoresCase()
        ) else { return (url, nil) }
        let host = match.1.lowercased()
        let path = String(match.2)
        return (host.hasPrefix("www.") ? String(host.dropFirst(4)) : host, ["", "/"].contains(path) ? nil : path)
    }

    private static func isBlocky(_ line: String) -> Bool {
        line.prefixMatch(of: /[-*+]\s|\d{1,9}[.)]\s|>|\||```|~~~|#{2,6}\s/) != nil
    }
}
