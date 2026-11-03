import cmark_gfm
import Foundation

/// Export as HTML, and the HTML of Copy as Rich Text (design log 001 › Windows
/// and chrome; log 004 Round 6): no scripts, raw HTML shown as source, a local
/// image embedded as data, and every other image a link. Nothing is fetched.
public enum HTMLExport {
    /// One self-contained file. Its content security policy also stops any fetch.
    public static func page(
        markdown: String,
        title: String,
        documentURL: URL?,
        features: MarkdownFeatures,
        readFile: (URL) -> Data?
    ) -> String {
        let body = body(markdown: markdown, documentURL: documentURL, features: features, readFile: readFile)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy"
            content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escaped(title))</title>
        <style>
        \(style)
        </style>
        </head>
        <body>
        \(body)</body>
        </html>

        """
    }

    /// The HTML of the text alone. `readFile` reads a local image's bytes.
    public static func body(
        markdown: String,
        documentURL: URL?,
        features: MarkdownFeatures,
        readFile: (URL) -> Data?
    ) -> String {
        var parsing = features
        // Raw HTML parses as its own nodes, so each can turn into code.
        parsing.html = true
        let parsed = ParsedMarkdown(markdown, features: parsing)
        // A changed type frees the node's literal and destination, so each is set again.
        for node in ParsedMarkdown.nodes(in: parsed.root, ofType: [CMARK_NODE_HTML_BLOCK, CMARK_NODE_HTML_INLINE]) {
            let source = ParsedMarkdown.literal(of: node)
            let code = cmark_node_get_type(node) == CMARK_NODE_HTML_BLOCK ? CMARK_NODE_CODE_BLOCK : CMARK_NODE_CODE
            // Code fits wherever raw HTML of the same kind fits.
            precondition(cmark_node_set_type(node, code) == 1)
            cmark_node_set_literal(node, source)
        }
        for image in ParsedMarkdown.nodes(in: parsed.root, ofType: [CMARK_NODE_IMAGE]) {
            export(image, documentURL: documentURL, readFile: readFile)
        }
        return parsed.html(safe: true)
    }

    private static func export(_ image: ParsedMarkdown.Node, documentURL: URL?, readFile: (URL) -> Data?) {
        // An image always has a destination, empty at least.
        let destination = String(cString: cmark_node_get_url(image)!) // swiftlint:disable:this force_unwrapping
        let local: URL? = if case let .local(url) = ImageRules.classify(destination, documentURL: documentURL) {
            url
        } else {
            nil
        }
        if let local, let data = readFile(local), let type = mediaType(of: data) {
            cmark_node_set_url(image, "data:\(type);base64,\(data.base64EncodedString())")
            return
        }
        let title = String(cString: cmark_node_get_title(image)!) // swiftlint:disable:this force_unwrapping
        // A link fits wherever an image fits (cmark allows a link in a link).
        precondition(cmark_node_set_type(image, CMARK_NODE_LINK) == 1)
        cmark_node_set_url(image, destination)
        cmark_node_set_title(image, title)
        if cmark_node_first_child(image) == nil {
            let text = cmark_node_new(CMARK_NODE_TEXT)
            cmark_node_set_literal(text, destination)
            cmark_node_append_child(image, text)
        }
    }

    /// The image types a page shows, from the bytes; nil for any other.
    static func mediaType(of data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        if bytes.starts(with: Array("GIF8".utf8)) {
            return "image/gif"
        }
        if bytes.starts(with: Array("RIFF".utf8)), bytes.dropFirst(8).elementsEqual("WEBP".utf8) {
            return "image/webp"
        }
        return nil
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let style = """
    body { max-width: 680px; margin: 2em auto; padding: 0 1em; font: 16px/1.5 -apple-system, system-ui, sans-serif; }
    pre, code { font-family: ui-monospace, monospace; }
    pre { overflow-x: auto; }
    img { max-width: 100%; }
    table { border-collapse: collapse; }
    th, td { border: 1px solid #8888; padding: 4px 8px; }
    """
}
