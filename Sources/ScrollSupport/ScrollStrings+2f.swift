import Foundation

/// The strings of stage 2f: Settings, the sidebar, export, and large files.
extension ScrollStrings {
    // MARK: Settings (screens §3.17)

    /// The Mac window's title and the iOS ⋯ item (screens §3.20).
    static var settings: String {
        String(localized: "more.settings", defaultValue: "Settings")
    }

    static var lineWidth: String {
        String(localized: "set.lineWidth", defaultValue: "Line width")
    }

    static var narrow: String {
        String(localized: "set.narrow", defaultValue: "Narrow")
    }

    static var medium: String {
        String(localized: "set.medium", defaultValue: "Medium")
    }

    static var wide: String {
        String(localized: "set.wide", defaultValue: "Wide")
    }

    static var showWordCount: String {
        String(localized: "set.wordCount", defaultValue: "Show word count")
    }

    static var foldersTitle: String {
        String(localized: "set.folders", defaultValue: "Folders Fortkeeps Scroll can open")
    }

    static var removeFolder: String {
        String(localized: "set.folders.remove", defaultValue: "Remove")
    }

    static var noFolders: String {
        String(localized: "set.folders.empty", defaultValue: "None yet.")
    }

    /// The button with the cache's size, or the empty state.
    static func clearImageCache(bytes: Int) -> String {
        guard bytes > 0 else { return String(localized: "set.cache.empty", defaultValue: "Image cache is empty") }
        let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        #if os(macOS)
            return String(localized: "set.cache.clear", defaultValue: "Clear Image Cache (\(size))")
        #else
            return String(localized: "set.cache.clear", defaultValue: "Clear image cache (\(size))")
        #endif
    }

    static var imageCacheNote: String {
        String(
            localized: "set.cache.note",
            defaultValue: """
            Images you load are kept on this device for 3 days after you last view them, \
            so they show again without another click. They are never backed up or synced.
            """
        )
    }

    static var imageCacheCleared: String {
        String(localized: "set.cache.cleared", defaultValue: "Image cache cleared.")
    }

    // MARK: Outline and folder sidebar (screens §3.4, §3.5)

    static var outlineTitle: String {
        String(localized: "outline.title", defaultValue: "Outline")
    }

    static var outlineEmpty: String {
        String(localized: "outline.empty", defaultValue: "No headings yet.")
    }

    static var folderEmpty: String {
        String(localized: "sidebar.empty", defaultValue: "No Markdown files in this folder.")
    }

    static var rename: String {
        String(localized: "sidebar.rename", defaultValue: "Rename")
    }

    static var moveToTrash: String {
        String(localized: "sidebar.trash", defaultValue: "Move to Trash")
    }

    static func nameTaken(_ name: String) -> String {
        String(localized: "sidebar.nameTaken", defaultValue: "“\(name)” already exists. Choose another name.")
    }

    // MARK: Export and print (screens §3.16)

    static var exportPDF: String {
        #if os(macOS)
            String(localized: "export.pdf", defaultValue: "Export as PDF…")
        #else
            String(localized: "export.pdf", defaultValue: "Export PDF")
        #endif
    }

    static var exportHTML: String {
        #if os(macOS)
            String(localized: "export.html", defaultValue: "Export as HTML…")
        #else
            String(localized: "export.html", defaultValue: "Export HTML")
        #endif
    }

    static var print: String {
        #if os(macOS)
            String(localized: "print", defaultValue: "Print…")
        #else
            String(localized: "print", defaultValue: "Print")
        #endif
    }

    static var copyRichText: String {
        #if os(macOS)
            String(localized: "copyRich", defaultValue: "Copy as Rich Text")
        #else
            String(localized: "copyRich", defaultValue: "Copy as rich text")
        #endif
    }

    static func exportFailed(_ name: String, _ reason: String) -> String {
        String(localized: "export.failed", defaultValue: "Couldn’t export “\(name)”. \(reason)")
    }

    // MARK: Large files (screens §3.14)

    static func opening(_ name: String) -> String {
        String(localized: "big.opening", defaultValue: "Opening “\(name)”…")
    }
}
