import Foundation

/// What following a link does (design log 001 › Links).
public enum LinkTarget: Equatable, Sendable {
    /// http or https: the default browser.
    case browser(URL)
    /// mailto: the default mail app.
    case mail(URL)
    /// A Markdown file inside the document's folder: a tab in this app.
    case siblingFile(URL)
    /// A heading of this document, by GFM slug.
    case fragment(String)
    case none
}

public enum LinkRules {
    /// The accepted file extensions, compared without case.
    public static let acceptedExtensions: Set = ["md", "markdown", "txt", "mdown", "mkd"]

    public static func classify(_ destination: String, documentURL: URL?) -> LinkTarget {
        if destination.hasPrefix("#") {
            return .fragment(String(destination.dropFirst()).removingPercentEncoding ?? String(destination.dropFirst()))
        }
        if let scheme = URLScheme.of(destination) {
            guard let url = URL(string: destination) else { return .none }
            switch scheme {
            case "http", "https": return url.host() == nil ? .none : .browser(url)
            case "mailto": return .mail(url)
            default: return .none
            }
        }
        let path = String(destination.prefix { $0 != "?" && $0 != "#" })
        guard let file = FolderPath.resolve(path, in: documentURL),
              acceptedExtensions.contains(file.pathExtension.lowercased())
        else { return .none }
        return .siblingFile(file)
    }
}

/// GitHub's heading anchors.
public enum GFMSlug {
    /// Lowercased; letters, numbers, marks, `_`, and `-` kept; each space a `-`;
    /// anything else dropped.
    public static func slug(_ text: String) -> String {
        String(String.UnicodeScalarView(text.lowercased().unicodeScalars.compactMap { scalar in
            if scalar == " " {
                return "-"
            }
            let kept = scalar.properties.isAlphabetic || scalar.properties.numericType != nil
                || scalar.properties.generalCategory == .nonspacingMark || scalar == "_" || scalar == "-"
            return kept ? scalar : nil
        }))
    }

    /// The slugs of headings in order. As github-slugger does, a slug that
    /// is taken gets the first free `-1`, `-2`, and so on.
    public static func slugs(_ texts: [String]) -> [String] {
        var taken: Set<String> = []
        return texts.map { text in
            let base = slug(text)
            var candidate = base
            var count = 0
            while taken.contains(candidate) {
                count += 1
                candidate = "\(base)-\(count)"
            }
            taken.insert(candidate)
            return candidate
        }
    }
}
