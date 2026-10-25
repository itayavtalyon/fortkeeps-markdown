/// The GFM switches a host sets once per document (design log 001 › Features).
public struct MarkdownFeatures: Equatable, Sendable {
    public var strikethrough = true
    public var autolink = true
    public var html = true
    public var tables = true
    public var taskLists = true
    public var pasteHtml = true
    public var softBreakAsLine = false

    public init() {}

    /// The value Fortkeeps passes for a memory body.
    public static let fortkeeps: MarkdownFeatures = {
        var features = MarkdownFeatures()
        features.strikethrough = false
        features.autolink = false
        features.html = false
        features.pasteHtml = false
        features.softBreakAsLine = true
        return features
    }()
}

/// How the rendered view presents a title line and an image it does not draw.
public struct MarkdownPresentation: Equatable, Sendable {
    public enum TitleLine: Sendable {
        case inBody
        case hidden
    }

    public enum ImageFallback: Sendable {
        case text
        case link
    }

    public var titleLine = TitleLine.inBody
    public var imageFallback = ImageFallback.text

    public init() {}
}
