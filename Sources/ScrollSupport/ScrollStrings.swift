import Foundation

/// The app strings, from the app's string catalog. Every string here is
/// DRAFT until Story Weaver finalizes it (WAIT-3); the keys are those of
/// screens §3.
enum ScrollStrings {
    static var emptyLine: String {
        String(localized: "empty.line", defaultValue: "Open a Markdown file, or create one.")
    }

    static var open: String {
        String(localized: "empty.open", defaultValue: "Open…")
    }

    /// The create command (log 002, Round 3).
    static var newFile: String {
        String(localized: "empty.new", defaultValue: "New File")
    }

    static var recent: String {
        String(localized: "recent.header", defaultValue: "Recent")
    }

    static var notFound: String {
        String(localized: "recent.missing", defaultValue: "Not found")
    }

    static var removeRecent: String {
        String(localized: "recent.remove", defaultValue: "Remove from Recent")
    }

    /// The refusal alert title (design log 001 › Files).
    static func cannotOpen(_ name: String) -> String {
        #if os(macOS)
            String(localized: "refuse.title", defaultValue: "Can’t Open “\(name)”")
        #else
            String(localized: "refuse.title", defaultValue: "Can’t open “\(name)”")
        #endif
    }

    static var wrongExtension: String {
        String(localized: "refuse.extension", defaultValue: "Open a .md, .markdown, or .txt file.")
    }

    static var notUTF8: String {
        String(localized: "refuse.utf8", defaultValue: "This file is not UTF-8, so it was not opened.")
    }

    static var ok: String {
        String(localized: "alert.ok", defaultValue: "OK")
    }

    // MARK: document window (screens §3.2, §3.3, §3.12, §3.13, §3.21)

    static func accessBar(_ folder: String) -> String {
        String(
            localized: "access.bar",
            defaultValue: "Allow access to “\(folder)” to show its images and open linked files."
        )
    }

    static var allowAccess: String {
        String(localized: "access.button", defaultValue: "Allow Access…")
    }

    static var dismiss: String {
        String(localized: "access.dismiss", defaultValue: "Dismiss")
    }

    static func deleted(_ name: String) -> String {
        String(localized: "gone.deleted", defaultValue: "“\(name)” was deleted. Your text is still here.")
    }

    static var saveAs: String {
        String(localized: "gone.saveAs", defaultValue: "Save As…")
    }

    static var close: String {
        String(localized: "gone.close", defaultValue: "Close")
    }

    static var closeConfirm: String {
        String(localized: "gone.confirm", defaultValue: "Close without saving? The text will be lost.")
    }

    static var cancel: String {
        String(localized: "alert.cancel", defaultValue: "Cancel")
    }

    static var readOnly: String {
        String(localized: "ro.strip", defaultValue: "You can read this file but not change it.")
    }

    static var duplicate: String {
        String(localized: "ro.duplicate", defaultValue: "Duplicate")
    }

    static func saveFailed(_ name: String) -> String {
        String(
            localized: "save.failed",
            defaultValue: "Couldn’t save “\(name)”. Fortkeeps Scroll will keep trying."
        )
    }

    static func notInFolder(_ name: String) -> String {
        String(localized: "link.missing", defaultValue: "“\(name)” isn’t in this folder.")
    }

    static var saved: String {
        String(localized: "status.saved", defaultValue: "Saved")
    }

    static var saving: String {
        String(localized: "status.saving", defaultValue: "Saving…")
    }

    static var locked: String {
        String(localized: "lock.on", defaultValue: "Locked")
    }

    static func words(_ count: Int) -> String {
        String(localized: "status.words", defaultValue: "\(count) words")
    }

    static var lock: String {
        String(localized: "toolbar.lock", defaultValue: "Lock")
    }

    static var unlock: String {
        String(localized: "lock.unlock", defaultValue: "Unlock")
    }
}
