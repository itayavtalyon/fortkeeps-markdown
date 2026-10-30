import Foundation
import MarkdownCore

/// One format command with its shortcut and name (design log 001 › Format
/// commands). The format bar and the shortcuts both perform these, so a
/// button and its shortcut give the same text.
enum FormatAction: CaseIterable, Equatable {
    case bold, italic, link, code, quote, checkbox, heading1, heading2, heading3, body, bulletedList

    // swiftlint:disable:next cyclomatic_complexity - one case per command
    func command(clipboard: String?) -> FormatCommand {
        switch self {
        case .bold: .bold
        case .italic: .italic
        case .link: .link(clipboard: clipboard)
        case .code: .code
        case .quote: .quote
        case .checkbox: .checkbox
        case .heading1: .heading(1)
        case .heading2: .heading(2)
        case .heading3: .heading(3)
        case .body: .body
        case .bulletedList: .bulletedList
        }
    }

    var shortcut: FormatShortcut {
        switch self {
        case .bold: FormatShortcut(key: "b", modifiers: .command)
        case .italic: FormatShortcut(key: "i", modifiers: .command)
        case .link: FormatShortcut(key: "k", modifiers: .command)
        case .code: FormatShortcut(key: "c", modifiers: [.command, .shift])
        case .quote: FormatShortcut(key: "'", modifiers: .command)
        case .checkbox: FormatShortcut(key: "\r", modifiers: .command)
        case .heading1: FormatShortcut(key: "1", modifiers: [.command, .option])
        case .heading2: FormatShortcut(key: "2", modifiers: [.command, .option])
        case .heading3: FormatShortcut(key: "3", modifiers: [.command, .option])
        case .body: FormatShortcut(key: "0", modifiers: [.command, .option])
        case .bulletedList: FormatShortcut(key: "8", modifiers: [.command, .shift])
        }
    }

    static func matching(key: String, modifiers: FormatShortcut.Modifiers) -> FormatAction? {
        allCases.first { $0.shortcut == FormatShortcut(key: key.lowercased(), modifiers: modifiers) }
    }

    var title: String {
        switch self {
        case .bold: String(localized: "fmt.bold", defaultValue: "Bold", bundle: resourceBundle)
        case .italic: String(localized: "fmt.italic", defaultValue: "Italic", bundle: resourceBundle)
        case .link: String(localized: "fmt.link", defaultValue: "Link", bundle: resourceBundle)
        case .code: String(localized: "fmt.code", defaultValue: "Code", bundle: resourceBundle)
        case .quote: String(localized: "fmt.quote", defaultValue: "Quote", bundle: resourceBundle)
        case .checkbox: String(localized: "fmt.checkbox", defaultValue: "Checkbox", bundle: resourceBundle)
        case .heading1: String(localized: "fmt.h1", defaultValue: "Heading 1", bundle: resourceBundle)
        case .heading2: String(localized: "fmt.h2", defaultValue: "Heading 2", bundle: resourceBundle)
        case .heading3: String(localized: "fmt.h3", defaultValue: "Heading 3", bundle: resourceBundle)
        case .body: String(localized: "fmt.body", defaultValue: "Body", bundle: resourceBundle)
        case .bulletedList:
            #if os(macOS)
                String(localized: "fmt.list", defaultValue: "Bulleted List", bundle: resourceBundle)
            #else
                String(localized: "fmt.list", defaultValue: "Bulleted list", bundle: resourceBundle)
            #endif
        }
    }

    var symbol: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .link: "link"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .quote: "text.quote"
        case .checkbox: "checkmark.square"
        case .heading1, .heading2, .heading3, .body: "textformat.size"
        case .bulletedList: "list.bullet"
        }
    }
}

/// The format bar buttons, in order. Heading holds a menu of levels.
enum FormatBarButton: CaseIterable {
    case bold, italic, heading, bulletedList, checkbox, link, code, quote

    var actions: [FormatAction] {
        switch self {
        case .bold: [.bold]
        case .italic: [.italic]
        case .heading: [.heading1, .heading2, .heading3, .body]
        case .bulletedList: [.bulletedList]
        case .checkbox: [.checkbox]
        case .link: [.link]
        case .code: [.code]
        case .quote: [.quote]
        }
    }

    var title: String {
        self == .heading ? String(localized: "fmt.heading", defaultValue: "Heading", bundle: resourceBundle)
            : actions[0].title
    }

    static var barTitle: String {
        String(localized: "fmt.bar", defaultValue: "Format", bundle: resourceBundle)
    }
}

/// A key with its modifiers.
struct FormatShortcut: Equatable {
    struct Modifiers: OptionSet {
        let rawValue: Int

        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
    }

    /// The key without Shift or Option applied.
    let key: String
    let modifiers: Modifiers
}
