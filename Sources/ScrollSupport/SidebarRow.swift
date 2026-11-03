import Foundation
import MarkdownViews

/// One row of the sidebar (screens §3.4, §3.5); the lists tell rows apart by identity.
@MainActor
final class SidebarRow {
    enum Kind {
        case section(String)
        case heading(Int, MarkdownDocument.OutlineItem)
        case entry(FolderFiles.Entry)
        case empty(String)
    }

    let kind: Kind
    /// A subfolder lists its files when it first opens.
    var children: [SidebarRow]?

    init(_ kind: Kind, _ children: [SidebarRow]? = nil) {
        self.kind = kind
        self.children = children
    }

    var title: String {
        switch kind {
        case let .section(title), let .empty(title): title
        case let .heading(_, item): item.title
        case let .entry(entry): entry.name
        }
    }

    /// The rows under it; a folder not yet opened has none.
    var list: [SidebarRow] {
        children ?? []
    }

    var url: URL? {
        if case let .entry(entry) = kind {
            entry.url
        } else {
            nil
        }
    }

    var isFolder: Bool {
        if case let .entry(entry) = kind {
            entry.isFolder
        } else {
            false
        }
    }

    /// H1–H3 in a list; H4–H6 under the heading before them.
    static func outline(_ items: [MarkdownDocument.OutlineItem]) -> [SidebarRow] {
        var rows: [SidebarRow] = []
        for (index, item) in items.enumerated() {
            let row = SidebarRow(.heading(index, item))
            if item.level > 3, let parent = rows.last {
                parent.children = parent.list + [row]
            } else {
                rows.append(row)
            }
        }
        return rows.isEmpty ? [SidebarRow(.empty(ScrollStrings.outlineEmpty))] : rows
    }

    /// The Markdown files and subfolders, or the empty line.
    static func rows(in folder: URL) -> [SidebarRow] {
        let rows = FolderFiles.entries(in: folder).map { SidebarRow(.entry($0)) }
        return rows.isEmpty ? [SidebarRow(.empty(ScrollStrings.folderEmpty))] : rows
    }

    /// A file's place, the same with or without a trailing slash or /private.
    static func key(_ url: URL?) -> [String] {
        url?.resolvingSymlinksInPath().pathComponents ?? []
    }
}

/// The lists tell rows apart by identity.
extension SidebarRow: Hashable {
    nonisolated static func == (lhs: SidebarRow, rhs: SidebarRow) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
